// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SwapperBase} from "../src/SwapperBase.sol";
import {Parties, PayableParties} from "../src/TypesAndConstants.sol";

contract TypesTest is Test, SwapperBase {
    function testAsNonPayableParties(PayableParties memory pay) public {
        Parties memory nonPay = SwapperBase._asNonPayableParties(pay);

        assertEq(pay.seller, nonPay.seller, "seller");
        assertEq(pay.buyer, nonPay.buyer, "buyer");
        assertEq(keccak256(abi.encode(pay)), keccak256(abi.encode(nonPay)), "struct hash");

        bool pointersMatch;
        assembly ("memory-safe") {
            pointersMatch := eq(pay, nonPay)
        }
        assertTrue(pointersMatch, "pointers match");
    }
}
