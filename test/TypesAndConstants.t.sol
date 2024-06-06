// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {IEscrow} from "../src/Escrow.sol";
import {Message} from "../src/ET.sol";
import {Action, ActionMessageLib, FILL, CANCEL, Parties, PayableParties} from "../src/TypesAndConstants.sol";
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

    function testDistinctActions() public {
        assertFalse(FILL == CANCEL);
    }

    function testFeeConfigRoundTrip(address payable feeRecipient, uint16 basisPoints) public {
        Message m = ActionMessageLib.fillWithFeeConfig(feeRecipient, basisPoints);

        assertTrue(m.action() == FILL, "FILL action");

        (address payable gotRecipient, uint16 gotBasisPoints) = m.feeConfig();
        assertEq(feeRecipient, gotRecipient, "recipient address recovered");
        assertEq(basisPoints, gotBasisPoints, "basis points recovered");
    }

    function testEscrowRoundTrip(address escrow) public {
        Message m = ActionMessageLib.cancelWithEscrow(IEscrow(escrow));

        assertTrue(m.action() == CANCEL, "CANCEL action");
        address gotEscrow = address(m.escrow());
        assertEq(escrow, gotEscrow, "escrow address recovered");
    }
}
