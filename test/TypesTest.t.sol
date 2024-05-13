// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Message} from "../src/ET.sol";
import {Action, ActionMessageLib, Parties, PayableParties} from "../src/TypesAndConstants.sol";
import {SwapperBase} from "../src/SwapperBase.sol";

contract TypesTest is Test, SwapperBase {
    using ActionMessageLib for Action;
    using ActionMessageLib for Message;

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

    function testFeeConfigRoundTrip(Action action, address payable feeRecipient, uint16 basisPoints) public {
        Message m = action.withFeeConfig(feeRecipient, basisPoints);

        assertTrue(m.action() == action, "action");

        (address payable gotRecipient, uint16 gotBasisPoints) = m.feeConfig();
        assertEq(feeRecipient, gotRecipient);
        assertEq(basisPoints, gotBasisPoints);
    }
}
