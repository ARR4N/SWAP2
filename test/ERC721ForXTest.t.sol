// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {SwapperTest, SwapperTestLib} from "./SwapperTest.t.sol";

import {ERC721Token} from "../src/ERC721SwapperLib.sol";
import {OnlyBuyerCanCancel, Disbursement, Parties} from "../src/TypesAndConstants.sol";
import {ETDeployer} from "../src/ET.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

abstract contract ERC721ForXTest is SwapperTest {
    using SwapperTestLib for TestCase;

    struct ERC721TestCase {
        TestCase common;
        uint256 tokenId;
    }

    function _swapper(ERC721TestCase memory) internal view virtual returns (address);

    function _fill(ERC721TestCase memory) internal virtual;

    function _cancel(ERC721TestCase memory) internal virtual;

    function _replay(ERC721TestCase memory, address replayer) internal virtual;

    function _beforeExecute(ERC721TestCase memory t) internal returns (address) {
        TestCase memory test = t.common;
        uint256 tokenId = t.tokenId;

        token.mint(test.seller(), tokenId);

        address swapper = _swapper(t);
        vm.label(swapper, "swapper");

        vm.assume(test.seller() != swapper && test.buyer() != swapper && test.caller != swapper);

        _approveSwapper(test, tokenId, swapper);
        vm.assume(_balance(swapper) == 0);
        _beforeExecute(test, swapper);

        return swapper;
    }

    function _testFill(ERC721TestCase memory t, bytes memory err) internal {
        address swapper = _beforeExecute(t);

        TestCase memory test = t.common;
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
        assertEq(_balance(swapper), passes ? 0 : _swapperPrePay(test), "swapper balance");
        assertEq(_balance(address(factory)), 0, "factory balance remains zero");

        assertEq(swapper.code.length, passes ? 3 : 0, "deployed swapper bytecode length");
        _afterExecute(test, swapper, passes);
    }

    function testHappyPath(ERC721TestCase memory t)
        public
        assumeValidTest(t.common)
        assumeValidPayments(t.common)
        assumeSufficientPayment(t.common)
        assumeApproving(t.common)
    {
        _testFill(t, "");
    }

    function testNotApproved(ERC721TestCase memory t)
        public
        assumeValidTest(t.common)
        assumeValidPayments(t.common)
        assumeSufficientPayment(t.common)
    {
        vm.assume(t.common.approval() == Approval.None);

        address swapper = _swapper(t);
        bytes memory err = abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, swapper, t.tokenId);
        _testFill(t, err);
    }

    function testInsufficientBalance(ERC721TestCase memory t)
        public
        assumeValidTest(t.common)
        assumeValidPayments(t.common)
        assumeApproving(t.common)
        assumeInsufficientPayment(t.common)
    {
        _testFill(t, _insufficientBalanceError(t.common));
    }

    function testReplayProtection(ERC721TestCase memory t, address replayer)
        public
        assumeValidTest(t.common)
        assumeValidPayments(t.common)
        assumeSufficientPayment(t.common)
        assumeApproving(t.common)
    {
        _testFill(t, "");

        TestCase memory test = t.common;

        vm.startPrank(test.buyer());
        token.transferFrom(test.buyer(), test.seller(), t.tokenId);
        vm.stopPrank();

        vm.expectRevert(ETDeployer.Create2EmptyRevert.selector);
        _replay(t, replayer);
        assertEq(token.ownerOf(t.tokenId), test.seller());
    }

    function testCancel(ERC721TestCase memory t, address vandal) public assumeValidTest(t.common) {
        address swapper = _beforeExecute(t);

        TestCase memory test = t.common;
        vm.assume(vandal != test.seller() && vandal != test.buyer());

        vm.label(swapper, "swapper");
        _beforeExecute(test, swapper);

        {
            vm.expectRevert(abi.encodeWithSelector(OnlyBuyerCanCancel.selector));
            _cancelAs(t, vandal);
        }

        {
            uint256 expectedBuyerBalance = _balance(test.buyer()) + _balance(swapper);

            vm.expectEmit(true, true, true, true, address(factory));
            emit Cancelled(_swapper(t));
            _cancelAs(t, test.buyer());

            assertEq(_balance(swapper), 0, "swapper balance zero after cancel");
            assertEq(_balance(test.buyer()), expectedBuyerBalance, "buyer balance after cancel");
        }

        {
            vm.expectRevert(abi.encodeWithSelector(ETDeployer.Create2EmptyRevert.selector));
            _replay(t, vandal);
        }

        assertEq(token.ownerOf(t.tokenId), test.seller());
    }

    function _cancelAs(ERC721TestCase memory t, address caller) internal {
        vm.startPrank(caller);
        _cancel(t);
        vm.stopPrank();
    }

    function testGas() public {
        Disbursement[5] memory thirdParty;
        uint128 total = 1 ether;

        _testFill(
            ERC721TestCase({
                common: TestCase({
                    parties: Parties({buyer: makeAddr("buyer"), seller: makeAddr("seller")}),
                    _thirdParty: thirdParty,
                    _numThirdParty: 0,
                    _totalConsideration: total,
                    _approval: uint8(Approval.Approve),
                    caller: makeAddr("buyer"),
                    salt: 0,
                    native: NativePayments({pre: 0, call: total, post: 0}),
                    erc20: ERC20Payments({buyerBalance: total, swapperAllowance: total})
                }),
                tokenId: 0
            }),
            ""
        );
    }
}
