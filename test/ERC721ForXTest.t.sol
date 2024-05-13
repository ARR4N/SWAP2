// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {SwapperTestBase, SwapperTestLib} from "./SwapperTestBase.t.sol";

import {ERC721Token} from "../src/ERC721SwapperLib.sol";
import {OnlyBuyerCanCancel, ExcessPlatformFee, Disbursement, Parties} from "../src/TypesAndConstants.sol";
import {ETDeployer} from "../src/ET.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

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
     */
    function _testFill(ERC721TestCase memory t, bytes memory err) internal {
        address swapper = _beforeExecute(t);

        TestCase memory test = t.base;
        uint256 tokenId = t.tokenId;
        _setPlatformFee(test);

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

        assertEq(
            _balance(test.seller()),
            passes ? test.totalForSeller() + _expectedExcessSellerBalanceAfterFill(test) : 0,
            "seller balance"
        );
        assertEq(_balance(test.platformFeeRecipient), passes ? test.platformFee() : 0);
        assertEq(_balance(swapper), passes ? 0 : _swapperPrePay(test), "swapper balance");
        assertEq(_balance(address(factory)), 0, "factory balance remains zero");

        Disbursement[] memory tP = t.base.consideration().thirdParty;
        for (uint256 i = 0; i < tP.length; ++i) {
            assertEq(_balance(tP[i].to), passes ? tP[i].amount : 0);
        }

        assertEq(swapper.code.length, passes ? 3 : 0, "deployed swapper bytecode length");
        _afterExecute(test, swapper, passes);
    }

    /// @dev Common setup shared by tests of both fill() and cancel().
    function _beforeExecute(ERC721TestCase memory t) private returns (address) {
        TestCase memory test = t.base;
        uint256 tokenId = t.tokenId;

        token.mint(test.seller(), tokenId);

        address swapper = _swapper(t);
        vm.label(swapper, "swapper");

        vm.assume(
            test.seller() != swapper && test.buyer() != swapper && test.caller != swapper
                && test.platformFeeRecipient != swapper
        );

        _approveSwapper(test, tokenId, swapper);
        vm.assume(_balance(swapper) == 0);
        _beforeExecute(test, swapper);

        return swapper;
    }

    function testHappyPath(ERC721TestCase memory t)
        public
        assumeValidTest(t.base)
        assumePaymentsValid(t.base)
        assumeSufficientPayment(t.base)
        assumeValidPlatformFee(t.base)
        assumeApproving(t.base)
    {
        _testFill(t, "");
    }

    function testNotApproved(ERC721TestCase memory t)
        external
        assumeValidTest(t.base)
        assumePaymentsValid(t.base)
        assumeSufficientPayment(t.base)
        assumeValidPlatformFee(t.base)
        assumeNotApproving(t.base) // <----- NB
    {
        address swapper = _swapper(t);
        bytes memory err = abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, swapper, t.tokenId);
        _testFill(t, err);
    }

    function testInsufficientBalance(ERC721TestCase memory t)
        external
        assumeValidTest(t.base)
        assumePaymentsValid(t.base)
        assumeInsufficientPayment(t.base) // <----- NB
        assumeValidPlatformFee(t.base)
        assumeApproving(t.base)
    {
        _testFill(t, _insufficientBalanceError(t.base));
    }

    function testExcessPlatformFee(ERC721TestCase memory t)
        external
        assumeValidTest(t.base)
        assumePaymentsValid(t.base)
        assumeSufficientPayment(t.base)
        assumeExcessPlatformFee(t.base) // <----- NB
        assumeApproving(t.base)
    {
        bytes memory err = abi.encodeWithSelector(
            ExcessPlatformFee.selector, t.base.platformFee(), t.base.consideration().maxPlatformFee
        );
        _testFill(t, err);
    }

    function testReplayProtection(ERC721TestCase memory t, address replayer) external {
        testHappyPath(t);

        TestCase memory test = t.base;

        vm.startPrank(test.buyer());
        token.transferFrom(test.buyer(), test.seller(), t.tokenId);
        vm.stopPrank();

        vm.expectRevert(ETDeployer.Create2EmptyRevert.selector);
        _replay(t, replayer);
        assertEq(token.ownerOf(t.tokenId), test.seller());
    }

    function testCancel(ERC721TestCase memory t, address vandal) external assumeValidTest(t.base) {
        address swapper = _beforeExecute(t);

        TestCase memory test = t.base;
        vm.assume(vandal != test.seller() && vandal != test.buyer());

        vm.label(swapper, "swapper");
        _beforeExecute(test, swapper);

        {
            vm.expectRevert(abi.encodeWithSelector(OnlyBuyerCanCancel.selector));
            _cancelAs(t, vandal);
            _afterExecute(test, swapper, false);
        }

        {
            uint256 expectedBuyerBalance = _balance(test.buyer()) + _balance(swapper);

            vm.expectEmit(true, true, true, true, address(factory));
            emit Cancelled(_swapper(t));
            _cancelAs(t, test.buyer());

            assertEq(_balance(swapper), 0, "swapper balance zero after cancel");
            assertEq(_balance(test.buyer()), expectedBuyerBalance, "buyer balance after cancel");

            _afterExecute(test, swapper, true);
        }

        {
            vm.expectRevert(abi.encodeWithSelector(ETDeployer.Create2EmptyRevert.selector));
            _replay(t, vandal);
            _afterExecute(test, swapper, true);
        }

        assertEq(token.ownerOf(t.tokenId), test.seller());
    }

    function _cancelAs(ERC721TestCase memory t, address caller) private {
        vm.startPrank(caller);
        _cancel(t);
        vm.stopPrank();
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
