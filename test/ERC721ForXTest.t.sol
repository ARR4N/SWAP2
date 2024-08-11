// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, Vm} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {SwapperTestBase, SwapperTestLib} from "./SwapperTestBase.t.sol";

import {Disbursement} from "../src/ConsiderationLib.sol";
import {Create2} from "../src/Create2.sol";
import {
    OnlyPartyCanCancel,
    ExcessPlatformFee,
    SwapExpired,
    Parties,
    SwapStatus,
    swapStatus
} from "../src/TypesAndConstants.sol";
import {Escrow} from "../src/Escrow.sol";
import {ETDeployer} from "../src/ET.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/// @dev Contract that returns all funds sent to it, used for tests of griefing.
contract FundsReflector {
    receive() external payable {
        (bool ok,) = msg.sender.call{value: msg.value}("");
        assert(ok);
    }
}

/// @dev Contract that reverts when receiving funds, used for tests of griefing.
contract FundsRejector {
    bool private _allowReceive;

    function allowReceive(bool a) external {
        _allowReceive = a;
    }

    receive() external payable {
        assert(_allowReceive);
    }
}

/// @dev Contract that propagates arbitrary calls, used for tests of reentrancy.
contract FallbackCaller {
    address private _callOnFallback;
    bytes private _data;

    function setFallbackCall(address callOnFallback, bytes memory data) public {
        _callOnFallback = callOnFallback;
        _data = data;
    }

    receive() external payable {
        _call(_callOnFallback, _data);
    }

    fallback() external {
        _call(_callOnFallback, _data);
    }

    struct Outcome {
        bool success;
        bytes returnData;
    }

    Outcome[] public calls;

    function _call(address a, bytes memory data) private {
        (bool success, bytes memory ret) = a.call(data);
        calls.push(Outcome({success: success, returnData: ret}));
    }
}

/**
 * @notice Implements concrete tests of swapping a single ERC721, agnostic to type of payment.
 * @dev Inherit from both this contract and either NativeTokenTest or ERC20Test for a complete, non-abstract test
 * contract.
 */
abstract contract ERC721ForXTest is SwapperTestBase {
    using SwapperTestLib for TestCase;

    /// @dev Couples a base test case with a single ERC721 token ID for swapping.
    struct ERC721TestCase {
        SwapperTestBase.TestCase base;
        uint256 tokenId;
    }

    /// @dev Returns the predicted address of a swapper for executing the swap defined by the test case.
    function _swapper(ERC721TestCase memory) internal view virtual returns (address);

    function _propose(ERC721TestCase memory) internal virtual returns (bytes32 salt, address swapper);

    function _encodedSwapAndSalt(ERC721TestCase memory, bytes32) internal view virtual returns (bytes memory);

    function _fillSelector() internal pure virtual returns (bytes4);

    function _cancelSelector() internal pure virtual returns (bytes4);

    function _callDataToFill(ERC721TestCase memory t) internal view returns (bytes memory) {
        return abi.encodePacked(_fillSelector(), _encodedSwapAndSalt(t, t.base.salt));
    }

    function _callDataToCancel(ERC721TestCase memory t) internal view returns (bytes memory) {
        return abi.encodePacked(_cancelSelector(), _encodedSwapAndSalt(t, t.base.salt));
    }

    /// @dev Fills the swap defined by the test case.
    function _fill(ERC721TestCase memory) internal virtual;

    /// @dev Cancels the swap defined by the test case.
    function _cancel(ERC721TestCase memory) internal virtual;

    /// @dev Attempts to fill the swap again, first performing all necessary deal()ing, then executing as `replayer`.
    function _replay(ERC721TestCase memory, address replayer) internal virtual;

    /**
     * @notice Tests _fill()ing of the swap defined by the test case.
     * @dev See external test*() functions for concrete usage.
     * @param t Test case from which a swap is defined.
     * @param err If non-empty, expects that a call to _fill(t) reverts with this error. If empty, expects success and a
     * corresponding transfer of the token from `seller` to `buyer`.
     * @return Swapper address.
     */
    function _testFill(ERC721TestCase memory t, bytes memory err) internal returns (address) {
        address swapper = _beforeExecute(t);

        TestCase memory test = t.base;
        uint256 tokenId = t.tokenId;

        bool passes = err.length == 0;

        if (passes) {
            vm.expectEmit(true, true, true, true, address(token));
            emit Transfer(test.seller(), test.buyer(), tokenId);
            vm.expectEmit(true, true, true, true, address(factory));
            emit Filled(swapper);
        } else {
            vm.expectRevert(err);
        }

        vm.startPrank(test.caller);
        _fill(t);
        vm.stopPrank();

        assertEq(token.ownerOf(tokenId), passes ? test.buyer() : test.seller(), "token owner");

        assertEq(_balance(test.seller()), passes ? _expectedSellerBalanceAfterFill(test) : 0, "seller balance");
        assertEq(_balance(test.platformFeeRecipient), passes ? test.platformFee() : 0, "platform-fee recipient");
        assertEq(_balance(swapper), passes ? 0 : _swapperPrePay(test), "swapper balance");
        assertEq(_balance(address(factory)), 0, "factory balance remains zero");

        Disbursement[] memory tP = t.base.consideration().thirdParty;
        for (uint256 i = 0; i < tP.length; ++i) {
            assertEq(_balance(tP[i].to), passes ? tP[i].amount : 0, "third-party");
        }

        assertEq(swapper.code.length, passes ? 3 : 0, "deployed swapper bytecode length");
        assertEq(swapStatus(swapper), passes ? SwapStatus.Filled : SwapStatus.Pending, "swap status");
        _afterExecute(test, swapper, passes);

        return swapper;
    }

    function _expectedSellerBalanceAfterFill(TestCase memory t) internal view returns (uint256) {
        return t.totalForSeller() + _expectedExcessSellerBalanceAfterFill(t);
    }

    /// @dev Common setup shared by tests of both fill() and cancel().
    function _beforeExecute(ERC721TestCase memory t) private returns (address) {
        TestCase memory test = t.base;
        uint256 tokenId = t.tokenId;

        token.mint(test.seller(), tokenId);

        address swapper = _swapper(t);
        vm.label(swapper, "swapper");
        assertEq(swapStatus(swapper), SwapStatus.Pending, "pending status before account creation");

        vm.assume(
            test.seller() != swapper && test.buyer() != swapper && test.caller != swapper
                && test.platformFeeRecipient != swapper
        );

        _approveSwapper(test, tokenId, swapper);
        vm.assume(_balance(swapper) == 0);
        _beforeExecute(test, swapper);

        // In native-token tests _beforeExecute(test, swapper) will create the account by sending a "test transaction"
        // prepayment. This changes the EXTCODEHASH from 0x00 to keccak256(""), therefore we perform this test despite
        // having already done it a few lines above.
        assertEq(swapStatus(swapper), SwapStatus.Pending, "pending status before executing swap");

        _setPlatformFee(t.base);

        vm.warp(t.base.warpToTimestamp);

        return swapper;
    }

    function testHappyPath(ERC721TestCase memory t)
        public
        assumeValidTest(
            t.base,
            Assumptions({sufficientPayment: true, validPlatformFee: true, approving: true, expired: false})
        )
        returns (address swapper)
    {
        return _testFill(t, "");
    }

    function testExpired(ERC721TestCase memory t)
        external
        assumeValidTest(
            t.base,
            Assumptions({sufficientPayment: true, validPlatformFee: true, approving: true, expired: true})
        )
    {
        bytes memory err = abi.encodeWithSelector(SwapExpired.selector, t.base.notValidAfter);
        _testFill(t, err);
    }

    function testNotApproved(ERC721TestCase memory t)
        external
        assumeValidTest(
            t.base,
            Assumptions({sufficientPayment: true, validPlatformFee: true, approving: false, expired: false})
        )
    {
        address swapper = _swapper(t);
        bytes memory err = abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, swapper, t.tokenId);
        _testFill(t, err);
    }

    function testInsufficientBalance(ERC721TestCase memory t)
        external
        assumeValidTest(
            t.base,
            Assumptions({sufficientPayment: false, validPlatformFee: true, approving: true, expired: false})
        )
    {
        _testFill(t, _insufficientBalanceError(t.base));
    }

    function testExcessPlatformFee(ERC721TestCase memory t)
        external
        assumeValidTest(
            t.base,
            Assumptions({sufficientPayment: true, validPlatformFee: false, approving: true, expired: false})
        )
    {
        bytes memory err = abi.encodeWithSelector(
            ExcessPlatformFee.selector, t.base.platformFee(), t.base.consideration().maxPlatformFee
        );
        _testFill(t, err);
    }

    function testReplayProtection(ERC721TestCase memory t, address replayer) external {
        address swapper = testHappyPath(t);

        TestCase memory test = t.base;

        vm.startPrank(test.buyer());
        token.transferFrom(test.buyer(), test.seller(), t.tokenId);
        vm.stopPrank();

        vm.expectRevert(Create2.Create2EmptyRevert.selector);
        _replay(t, replayer);
        assertEq(token.ownerOf(t.tokenId), test.seller());

        assertEq(swapStatus(swapper), SwapStatus.Filled, "status after replay attempt");
    }

    function testPropose(ERC721TestCase memory t)
        external
        assumeValidTest(
            t.base,
            Assumptions({sufficientPayment: true, validPlatformFee: true, approving: true, expired: false})
        )
    {
        vm.recordLogs();
        (bytes32 salt, address swapper) = _propose(t);

        {
            Vm.Log[] memory logs = vm.getRecordedLogs();
            assertEq(logs.length, 1, "# logged events");
            assertEq(logs[0].topics[1], bytes32(abi.encode(swapper)), "logged and returned swapper addresses match");
            assertEq(logs[0].topics[2], bytes32(abi.encode(t.base.seller())), "seller logged");
            assertEq(logs[0].topics[3], bytes32(abi.encode(t.base.buyer())), "buyer logged");
            assertEq(logs[0].data, _encodedSwapAndSalt(t, salt), "logged data is abi-encoded swap and salt");
        }

        {
            assertEq(swapStatus(swapper), SwapStatus.Pending, "initial pending status of proposed swapper");

            t.base.salt = salt;
            _beforeExecute(t);

            vm.expectEmit(true, true, true, true, address(factory));
            emit Filled(swapper);
            vm.startPrank(t.base.caller);
            _fill(t);
            vm.stopPrank();

            assertEq(swapStatus(swapper), SwapStatus.Filled, "proposed swapper filled");
        }
    }

    function testCancel(ERC721TestCase memory t, address vandal, bool asSeller, Assumptions memory assume)
        external
        assumeValidTest(t.base, assume) // the ability to cancel MUST be independent of any Assumptions
    {
        address swapper = _beforeExecute(t);

        TestCase memory test = t.base;
        vm.assume(vandal != test.seller() && vandal != test.buyer());

        vm.label(swapper, "swapper");
        _beforeExecute(test, swapper);

        {
            vm.expectRevert(abi.encodeWithSelector(OnlyPartyCanCancel.selector));
            _cancelAs(t, vandal);
            _afterExecute(test, swapper, false);
            assertEq(swapStatus(swapper), SwapStatus.Pending, "swap pending after vandal attempt to cancel");
        }

        {
            uint256 expectedBuyerBalance = _balance(test.buyer()) + _balance(swapper);

            if (!_isERC20Test() && _balance(swapper) > 0) {
                vm.expectEmit(true, true, true, true, address(factory.escrow()));
                emit Deposit(test.buyer(), _balance(swapper));
            }
            vm.expectEmit(true, true, true, true, address(factory));
            emit Cancelled(_swapper(t));
            _cancelAs(t, asSeller ? test.seller() : test.buyer());

            if (factory.escrow().balance(test.buyer()) > 0) {
                factory.escrow().withdraw(test.buyer());
            }

            assertEq(_balance(swapper), 0, "swapper balance zero after cancel");
            assertEq(_balance(test.buyer()), expectedBuyerBalance, "buyer balance after cancel");

            _afterExecute(test, swapper, true);
            assertEq(swapStatus(swapper), SwapStatus.Cancelled, "status after cancellation");
        }

        {
            vm.expectRevert(abi.encodeWithSelector(Create2.Create2EmptyRevert.selector));
            _replay(t, vandal);
            _afterExecute(test, swapper, true);
            assertEq(swapStatus(swapper), SwapStatus.Cancelled, "status after replay attempt");
        }

        assertEq(token.ownerOf(t.tokenId), test.seller());
    }

    function _cancelAs(ERC721TestCase memory t, address caller) private {
        vm.startPrank(caller);
        _cancel(t);
        vm.stopPrank();
    }

    function testNonReentrant(ERC721TestCase memory t)
        external
        assumeValidTest(
            t.base,
            Assumptions({sufficientPayment: true, validPlatformFee: true, approving: true, expired: false})
        )
    {
        token.setPostTransferCall(address(factory), _callDataToFill(t));

        // The most precise way to detect a redeployment is to see that CREATE2 reverts without any return data.
        // Inspection of the trace with `forge test -vvvv` is necessary to see the [CreationCollision] error.
        _testFill(t, abi.encodeWithSelector(Create2.Create2EmptyRevert.selector));
    }

    function testNonReentrantBuyerCancelBetweenReceiptAndPayment(ERC721TestCase memory t)
        external
        assumeValidTest(
            t.base,
            Assumptions({sufficientPayment: true, validPlatformFee: true, approving: true, expired: false})
        )
    {
        vm.skip(_isERC20Test());
        vm.assume(t.base._numThirdParty > 0);
        vm.assume(t.base._thirdParty[0].amount > 0);

        // If a buyer and a third party were to collude on a native-token sale, the buyer could call cancel() before the
        // seller receives their funds.

        FallbackCaller buyer = new FallbackCaller();
        FallbackCaller colluder = new FallbackCaller();
        colluder.setFallbackCall(address(buyer), "");

        t.base.parties.buyer = address(buyer);
        t.base._thirdParty[0].to = address(colluder);
        buyer.setFallbackCall(address(factory), _callDataToCancel(t));

        // Steps will now be:
        // 1. Token(s) transferred to buyer
        // 2. Colluder receives funds
        // 3. Colluder calls buyer
        // 4. Buyer attempts to cancel
        // 5. Cancellation fails; note that FallbackCaller catches and records the revert so the fill() succeeds
        _testFill(t, "");

        // Prove that the scenario actually played out as expected.
        (bool success, bytes memory returnData) = buyer.calls(0);
        assertFalse(success, "buyer's attempt to cancel");
        assertEq(
            returnData,
            abi.encodeWithSelector(Create2.Create2EmptyRevert.selector), // see rationale in `testNonReentrant()`
            "reason for buyer's failed cancellation"
        );
    }

    function testGriefNativeTokenInvariantOnFill(ERC721TestCase memory t, uint8 vandalIndex)
        external
        assumeValidTest(
            t.base,
            Assumptions({sufficientPayment: true, validPlatformFee: true, approving: true, expired: false})
        )
    {
        vm.skip(_isERC20Test());
        // Native-token consideration has a post-execution invariant of a zero balance, which could open us up to a
        // reentrancy griefing attack if funds are sent during the swap. We demonstrate that this isn't possible by
        // having one of the third parties return the value they receive, which ends up in the seller's balance.

        vm.assume(t.base._numThirdParty > 0);

        Disbursement memory vandal = t.base._thirdParty[vandalIndex % t.base._numThirdParty];
        vm.assume(vandal.amount > 0);
        vandal.to = address(new FundsReflector{salt: keccak256(abi.encode(t))}());
        vm.label(vandal.to, "vandal");

        _beforeExecute(t);
        vm.startPrank(t.base.caller);
        _fill(t);
        vm.stopPrank();

        assertEq(_balance(vandal.to), 0, "vandal attempted griefing attack");
        assertEq(
            _balance(t.base.seller()),
            _expectedSellerBalanceAfterFill(t.base) + vandal.amount,
            "seller receives excess amount sent to contract"
        );
    }

    function testGriefNativeTokenInvariantOnCancel(ERC721TestCase memory t)
        external
        assumeValidTest(
            t.base,
            Assumptions({sufficientPayment: true, validPlatformFee: true, approving: true, expired: false})
        )
    {
        vm.skip(_isERC20Test());

        // If the buyer sends any funds back during cancellation, the post-execution invariant of zero balance will be
        // broken.
        t.base.parties.buyer = address(new FundsReflector());
        address swapper = _beforeExecute(t);

        vm.expectEmit(true, true, true, true, address(factory));
        emit Cancelled(swapper);
        _cancelAs(t, t.base.seller());
    }

    /**
     * @dev The generated `<T>ForERC20Deployer` contracts have payable `fill()` functions because of simple identifier
     * replacement. Being payable is unnecessary and could (but doesn't) risk accidental locking of funds. There are two
     * options: (1) remove the modifier at the expense of a more complex templating system; or (2) prove that funds can't
     * be locked (i.e. this test) because they're forwarded to a non-payable constructor. While the test adds some degree
     * of complication, the alternative is reduced simplicity of production code.
     */
    function testERC20FillNotPayable(ERC721TestCase memory t, uint256 value)
        external
        assumeValidTest(
            t.base,
            Assumptions({sufficientPayment: true, validPlatformFee: true, approving: true, expired: false})
        )
    {
        vm.skip(!_isERC20Test());
        vm.assume(value > 0);

        _beforeExecute(t);

        // Making the identical call with zero and non-zero values demonstrates the cause of the expected revert.
        uint256[2] memory values = [0, value];

        for (uint256 i = 0; i < values.length; ++i) {
            uint256 snap = vm.snapshot();

            vm.deal(t.base.caller, values[i]);

            if (values[i] > 0) {
                vm.expectRevert(Create2.Create2EmptyRevert.selector); // constructor reverts
            }
            vm.prank(t.base.caller);
            (bool revertsAsExpected,) = address(factory).call{value: values[i]}(_callDataToFill(t));

            // See: https://book.getfoundry.sh/cheatcodes/expect-revert#:~:text=Gotcha%3A%20Usage%20with%20low%2Dlevel%20calls
            // Permalink: https://github.com/foundry-rs/book/blob/6667a3703f67c01fbd38ae9cbb14bb409f3b532f/src/cheatcodes/expect-revert.md#:~:text=Gotcha%3A%20Usage%20with%20low%2Dlevel%20calls
            assertTrue(revertsAsExpected);
            assertEq(swapStatus(_swapper(t)), values[i] == 0 ? SwapStatus.Filled : SwapStatus.Pending, "swap status");

            vm.revertTo(snap);
        }
    }

    function testNativeCancelEscrow(ERC721TestCase memory t, uint256 refund, bytes32 buyerSalt)
        external
        assumeValidTest(
            t.base,
            Assumptions({sufficientPayment: true, validPlatformFee: true, approving: true, expired: false})
        )
    {
        vm.skip(_isERC20Test());
        vm.assume(refund > 0);
        TestCase memory test = t.base;

        FundsRejector buyer = new FundsRejector{salt: buyerSalt}();
        test.parties.buyer = address(buyer);
        vm.assume(test.buyer().balance == 0);

        vm.deal(_swapper(t), refund);

        Escrow escrow = factory.escrow();
        vm.assume(address(escrow).balance == 0);

        {
            // Without escrow, cancel() would now fail, griefing the seller.
            buyer.allowReceive(false);

            vm.expectEmit(true, true, true, true, address(escrow));
            emit Deposit(test.buyer(), refund);
            vm.expectEmit(true, true, true, true, address(factory));
            emit Cancelled(_swapper(t));
            _cancelAs(t, test.seller());

            assertEq(swapStatus(_swapper(t)), SwapStatus.Cancelled, "swapper status cancelled");
            assertEq(escrow.balance(test.buyer()), refund, "escrow contract receives refund");
        }

        {
            buyer.allowReceive(true);

            vm.expectEmit(true, true, true, true, address(escrow));
            emit Withdrawal(test.buyer(), refund);
            vm.prank(test.buyer());
            escrow.withdraw();

            assertEq(test.buyer().balance, refund, "buyer ultimately receives refund");
            assertEq(escrow.balance(test.buyer()), 0);
        }

        vm.expectRevert(abi.encodeWithSelector(Escrow.ZeroBalance.selector, address(buyer)));
        escrow.withdraw(test.buyer());
    }

    function testChainIdCoupling(ERC721TestCase memory t, uint64 chainId0, uint64 chainId1)
        external
        // While the specific assumptions are irrelevant, general assumptions about `t` must be made for it to be valid
        // otherwise we'll get out-of-bounds errors.
        assumeValidTest(
            t.base,
            Assumptions({sufficientPayment: true, validPlatformFee: true, approving: true, expired: false})
        )
    {
        vm.chainId(chainId0);
        address swapperOnChain0 = _swapper(t);

        vm.chainId(chainId1);
        address swapperOnChain1 = _swapper(t);

        emit log_named_uint("chain ID 0", chainId0);
        emit log_named_uint("chain ID 1", chainId1);
        emit log_named_address("swapper on chain 0", swapperOnChain0);
        emit log_named_address("swapper on chain 1", swapperOnChain1);
        assertEq(
            chainId0 == chainId1,
            swapperOnChain0 == swapperOnChain1,
            "different chain IDs <=> different swapper addresses"
        );
    }

    function testGas() external {
        Disbursement[5] memory thirdParty;
        uint128 total = 1 ether;

        address seller = makeAddr("seller");
        address fees = makeAddr("feeRecipient");

        _testFill(
            ERC721TestCase({
                base: TestCase({
                    parties: Parties({buyer: makeAddr("buyer"), seller: seller}),
                    _thirdParty: thirdParty,
                    _numThirdParty: 0,
                    _totalConsideration: total,
                    _maxPlatformFee: total,
                    platformFeeBasisPoints: 250,
                    platformFeeRecipient: payable(fees),
                    _approval: uint8(Approval.Approve),
                    warpToTimestamp: block.timestamp,
                    notValidAfter: block.timestamp,
                    caller: makeAddr("buyer"),
                    salt: keccak256("pepper"),
                    native: NativePayments({prePay: 0, callValue: total, postPay: 0}),
                    erc20: ERC20Payments({buyerBalance: total, swapperAllowance: total})
                }),
                tokenId: 0
            }),
            ""
        );

        assertEq(_balance(seller), 0.975 ether, "explicit seller balance");
        assertEq(_balance(fees), 0.025 ether, "explicit fee-recipient balance");
    }
}
