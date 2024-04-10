// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SwapperTest, SwapperTestLib} from "./SwapperTest.t.sol";
import {Parties, PayableParties} from "../src/TypesAndConstants.sol";

contract NativeTokenConsiderationTest is SwapperTest {
    using SwapperTestLib for CommonTestCase;

    struct Payments {
        uint128 prepaySwapper;
        uint128 callValue;
        uint128 postpaySwapper;
    }

    modifier assumeValidPayments(CommonTestCase memory t, Payments memory p) {
        vm.assume(t.seller() != t.caller || p.prepaySwapper == 0);
        _;
    }

    modifier assumeSufficientPayment(CommonTestCase memory t, Payments memory p) {
        vm.assume(uint256(p.prepaySwapper) + uint256(p.callValue) >= t.consideration.total);
        _;
    }

    function _asPayableParties(Parties memory nonPay) internal pure returns (PayableParties memory pay) {
        assembly ("memory-safe") {
            pay := nonPay
        }
    }

    function _testExtraDeposits(CommonTestCase memory t, Payments memory p, address swapper, bool allowed)
        internal
        inVMSnapshot
    {
        vm.deal(t.buyer(), p.postpaySwapper);
        vm.prank(t.buyer());
        (bool success,) = swapper.call{value: p.postpaySwapper}("");
        assertEq(success, allowed, "funds can only be sent to the address before execution");
    }
}
