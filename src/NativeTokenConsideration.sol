// SPDX-License-Identifier: UNLICENSED
// Copyright 2024 Divergence Tech Ltd.
pragma solidity 0.8.25;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Consideration, Disbursement, PayableParties, InsufficientBalance} from "./TypesAndConstants.sol";

/**
 * @dev Disburses funds denominated in the chain's native token.
 */
contract NativeTokenConsideration {
    using Address for address payable;

    /**
     * @notice Disburses funds denominated in the chain's native token.
     * @dev If the contract's balance is greater than `c.total`, the excess is sent to `parties.seller`.
     * @param parties Funds are sent from `parties.buyer` to all third-parties, the fee recipient, and `parties.seller`.
     * @param c Breakdown of fund disbursement. See `Consideration` documentation for details.
     * @param feeRecipient Recipient of `fee`.
     * @param fee Amount to send to `feeRecipient` from `parties.buyer`, in addition to all `c.thirdParty`
     * disbursements.
     */
    function _disburseFunds(
        PayableParties memory parties,
        Consideration memory c,
        address payable feeRecipient,
        uint256 fee
    ) internal {
        if (address(this).balance < c.total) {
            revert InsufficientBalance(address(this).balance, c.total);
        }

        feeRecipient.sendValue(fee);

        Disbursement[] memory tP = c.thirdParty;
        for (uint256 i = 0; i < tP.length; ++i) {
            payable(tP[i].to).sendValue(tP[i].amount);
        }

        // MUST remain as the last step to guarantee that _postExecutionInvariantsMet() returns true. This means that
        // the only actor capable of griefing the invariants is the seller (by returning some of these funds), which
        // would only act to harm themselves.
        _sendEntireBalance(parties.seller);
    }

    /// @notice Sends the contract's entire balance to `parties.buyer`.
    function _cancel(PayableParties memory parties) internal virtual {
        // MUST remain as the last step for the same reason as _disburseFunds().
        _sendEntireBalance(parties.buyer);
    }

    /**
     * @dev Sends the entirety of the contract's balance to the specified address. As this is called as the final step
     * in all paths, the post-execution invariant of a zero balance is ensured.
     */
    function _sendEntireBalance(address payable to) private {
        to.sendValue(address(this).balance);
    }

    /// @dev Returns whether the contract's remaining balance is zero.
    function _postExecutionInvariantsMet() internal view returns (bool) {
        return address(this).balance == 0;
    }
}
