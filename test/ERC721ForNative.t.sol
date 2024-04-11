// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {NativeTokenConsiderationTest} from "./NativeTokenConsideration.t.sol";
import {SwapperTest, SwapperTestLib} from "./SwapperTest.t.sol";

import {ERC721Token} from "../src/ERC721SwapperLib.sol";
import {ERC721ForNativeSwap as Swap} from "../src/ERC721ForNative/ERC721ForNativeSwap.sol";
import {InsufficientBalance, Disbursement} from "../src/TypesAndConstants.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract ERC721ForNativeTest is NativeTokenConsiderationTest {
    using SwapperTestLib for CommonTestCase;

    struct TestCase {
        CommonTestCase common;
        uint256 tokenId;
        Payments payments;
    }

    function _testFill(TestCase memory t, bytes memory err) internal {
        CommonTestCase memory test = t.common;
        uint256 tokenId = t.tokenId;
        Payments memory pay = t.payments;

        token.mint(test.seller(), tokenId);

        Swap memory swap = _asSwap(t);
        address swapper = factory.swapper(swap, test.salt);
        vm.label(swapper, "swapper");

        {
            vm.assume(test.seller() != swapper && test.buyer() != swapper && test.caller != swapper);

            vm.assume(swapper.balance == 0);
            vm.deal(swapper, pay.prepaySwapper);
            _approveSwapper(test, tokenId, swapper);
        }

        bool passes = err.length == 0;

        {
            if (passes) {
                vm.expectEmit(true, true, true, true, address(token));
                emit Transfer(test.seller(), test.buyer(), tokenId);
                vm.expectEmit(true, true, true, true, swapper);
                emit Filled();
            } else {
                vm.expectRevert(err);
            }

            vm.deal(test.caller, pay.callValue);
            vm.prank(test.caller);
            factory.fill{value: pay.callValue}(swap, test.salt);
        }

        {
            assertEq(token.ownerOf(tokenId), passes ? test.buyer() : test.seller(), "token owner");

            assertEq(
                test.seller().balance,
                passes ? uint256(pay.prepaySwapper) + uint256(pay.callValue) - test.totalForThirdParties() : 0,
                "seller balance"
            );
            assertEq(test.caller.balance, passes ? 0 : pay.callValue, "caller balance");
            assertEq(swapper.balance, passes ? 0 : pay.prepaySwapper, "swapper balance");
            assertEq(address(factory).balance, 0, "factory balance remains zero");
        }

        {
            assertEq(swapper.code.length, passes ? 3 : 0, "deployed swapper bytecode length");
            _testExtraDeposits(test, pay, swapper, !passes);
        }
    }

    function testHappyPath(TestCase memory t)
        public
        assumeValidTest(t.common)
        assumeValidPayments(t.common, t.payments)
        assumeSufficientPayment(t.common, t.payments)
        assumeApproving(t.common)
    {
        _testFill(t, "");
    }

    function testNotApproved(TestCase memory t)
        public
        assumeValidTest(t.common)
        assumeValidPayments(t.common, t.payments)
        assumeSufficientPayment(t.common, t.payments)
    {
        vm.assume(t.common.approval() == Approval.None);

        address swapper = factory.swapper(_asSwap(t), t.common.salt);
        bytes memory err = abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, swapper, t.tokenId);
        _testFill(t, err);
    }

    function testInsufficientBalance(TestCase memory t)
        public
        assumeValidTest(t.common)
        assumeValidPayments(t.common, t.payments)
        assumeApproving(t.common)
    {
        uint256 paying = uint256(t.payments.prepaySwapper) + uint256(t.payments.callValue);
        vm.assume(paying < t.common.total());

        bytes memory err = abi.encodeWithSelector(InsufficientBalance.selector, paying, t.common.total());
        _testFill(t, err);
    }

    function testReplayProtection(TestCase memory t, address replayer)
        public
        assumeValidTest(t.common)
        assumeValidPayments(t.common, t.payments)
        assumeSufficientPayment(t.common, t.payments)
        assumeApproving(t.common)
    {
        _testFill(t, "");

        CommonTestCase memory test = t.common;

        vm.startPrank(test.buyer());
        token.transferFrom(test.buyer(), test.seller(), t.tokenId);
        vm.stopPrank();

        vm.deal(replayer, test.total());
        vm.startPrank(replayer);
        vm.expectRevert(new bytes(0));
        factory.fill{value: test.total()}(_asSwap(t), test.salt);
        vm.stopPrank();
    }

    function _asSwap(TestCase memory t) internal view returns (Swap memory) {
        return Swap({
            parties: _asPayableParties(t.common.parties),
            consideration: t.common.consideration,
            token: ERC721Token({addr: token, id: t.tokenId})
        });
    }
}
