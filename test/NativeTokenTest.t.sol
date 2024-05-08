// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SwapperTestBase, SwapperTestLib} from "./SwapperTestBase.t.sol";
import {InsufficientBalance, Consideration, Parties, PayableParties} from "../src/TypesAndConstants.sol";

abstract contract NativeTokenTest is SwapperTestBase {
    using SwapperTestLib for TestCase;

    function _balance(address a) internal view override returns (uint256) {
        return a.balance;
    }

    function _deal(address a, uint256 newBalance) internal override {
        vm.deal(a, newBalance);
    }

    function _beforeExecute(TestCase memory t, address swapper) internal override {
        _deal(swapper, t.native.prePay);
        _deal(t.caller, t.native.callValue);
    }

    function _afterExecute(TestCase memory t, address swapper, bool executed) internal override inVMSnapshot {
        vm.deal(t.buyer(), t.native.postPay);
        vm.prank(t.buyer());
        (bool success,) = swapper.call{value: t.native.postPay}("");
        assertEq(success, !executed, "funds can only be sent to the swapper before execution");
    }

    function _expectedSellerBalanceAfterFill(TestCase memory t) internal pure override returns (uint256) {
        NativePayments memory pay = t.native;
        return uint256(pay.prePay) + uint256(pay.callValue) - t.totalForThirdParties();
    }

    function _swapperPrePay(TestCase memory t) internal pure override returns (uint256) {
        return t.native.prePay;
    }

    function _paymentsValid(TestCase memory t) internal pure override returns (bool) {
        // The seller only executes the transaction if all funds are pre-paid.
        return t.caller != t.seller() || t.native.callValue == 0;
    }

    function _totalPaying(TestCase memory t) internal pure override returns (uint256) {
        return uint256(t.native.prePay) + uint256(t.native.callValue);
    }

    function _insufficientBalanceError(TestCase memory t) internal pure override returns (bytes memory) {
        return abi.encodeWithSelector(InsufficientBalance.selector, _totalPaying(t), t.total());
    }

    function _asPayableParties(Parties memory nonPay) internal pure returns (PayableParties memory pay) {
        assembly ("memory-safe") {
            pay := nonPay
        }
    }
}
