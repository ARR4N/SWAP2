// SPDX-License-Identifier: UNLICENSED
// Copyright 2024 Divergence Tech Ltd.
pragma solidity ^0.8.24;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Parties, PayableParties, InsufficientBalance} from "./TypesAndConstants.sol";

/// @dev Part of `Consideration` sent to a party other than the `seller` and the platform-fee recipient.
struct Disbursement {
    address to;
    uint256 amount;
}

/**
 * @dev Fungible payment, denoted in native token. While the `buyer` of the `[Payable]Parties` is responsible for
 * payment of `total`, the `seller` will only receive the difference between `total` and the sum of `thirdParty` +
 * platform-fee amounts.
 * @dev As all fields in a <T>Swap struct are immutable (otherwise the swapper address changes), the platform fee is
 * denoted as an upper bound to allow it to be modified in favour of the `seller`.
 */
struct Consideration {
    Disbursement[] thirdParty;
    uint256 maxPlatformFee;
    uint256 total;
}

/// @dev Identical to `Consideration` except for the addition of the `currency` field.
struct ERC20Consideration {
    Disbursement[] thirdParty;
    uint256 maxPlatformFee;
    uint256 total;
    IERC20 currency;
}

/**
 * @notice Disburses `Consideration`, denominated in either native token or ERC20.
 * @dev There MUST NOT be any interactions (in the CEI sense) between calls to `_disburse()` and
 * `_postExecutionInvariantsMet() as this would open native-token swaps to griefing by breaking the invariant.
 */
library ConsiderationLib {
    using Address for address payable;
    using SafeERC20 for IERC20;

    /**
     * @notice Disburses funds denominated in the chain's native token.
     * @dev If the contract's balance is greater than `c.total`, the excess is sent to `parties.seller`.
     * @param parties Funds are sent from `parties.buyer` to all third-parties, the fee recipient, and `parties.seller`.
     * @param c Breakdown of fund disbursement. See `Consideration` documentation for details.
     * @param feeRecipient Recipient of `fee`.
     * @param fee Amount to send to `feeRecipient` from `parties.buyer`, in addition to all `c.thirdParty`
     * disbursements.
     */
    function _disburse(PayableParties memory parties, Consideration memory c, address payable feeRecipient, uint256 fee)
        internal
    {
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
    function _cancel(PayableParties memory parties, Consideration memory) internal {
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
    function _postExecutionInvariantsMet(PayableParties memory, Consideration memory) internal view returns (bool) {
        return address(this).balance == 0;
    }

    /**
     * @notice Disburses funds denominated in ERC20.
     * @param parties Funds are sent from `parties.buyer` to all third-parties, the fee recipient, and `parties.seller`.
     * @param c Breakdown of fund disbursement. See `ERC20Consideration` documentation for details.
     * @param feeRecipient Recipient of `fee`.
     * @param fee Amount to send to `feeRecipient` from `parties.buyer`, in addition to all `c.thirdParty`
     * disbursements.
     */
    function _disburse(Parties memory parties, ERC20Consideration memory c, address feeRecipient, uint256 fee)
        internal
    {
        uint256 remaining = c.total;

        c.currency.safeTransferFrom(parties.buyer, feeRecipient, fee);
        remaining -= fee;

        Disbursement[] memory tP = c.thirdParty;
        for (uint256 i = 0; i < tP.length; ++i) {
            c.currency.safeTransferFrom(parties.buyer, tP[i].to, tP[i].amount);
            remaining -= tP[i].amount;
        }

        c.currency.safeTransferFrom(parties.buyer, parties.seller, remaining);
    }

    /// @dev Noop because no explicit cancellation required for ERC20 consideration.
    function _cancel(Parties memory, ERC20Consideration memory) internal pure {}

    /// @dev Always returns true as there are no ERC20 invariants.
    function _postExecutionInvariantsMet(Parties memory, ERC20Consideration memory) internal pure returns (bool) {
        return true;
    }
}
