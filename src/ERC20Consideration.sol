// SPDX-License-Identifier: UNLICENSED
// Copyright 2024 Divergence Tech Ltd.
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Consideration, Disbursement, Parties} from "./TypesAndConstants.sol";

/**
 * @dev Disburses funds denominated in ERC20.
 */
contract ERC20Consideration {
    using SafeERC20 for IERC20;

    /**
     * @notice Disburses funds denominated in ERC20.
     * @param parties Funds are sent from `parties.buyer` to all third-parties, the fee recipient, and `parties.seller`.
     * @param c Breakdown of fund disbursement. See `Consideration` documentation for details.
     * @param currency ERC20 contract in which `Consideration` is denominated.
     * @param feeRecipient Recipient of `fee`.
     * @param fee Amount to send to `feeRecipient` from `parties.buyer`, in addition to all `c.thirdParty`
     * disbursements.
     */
    function _disburseFunds(
        Parties memory parties,
        Consideration memory c,
        IERC20 currency,
        address feeRecipient,
        uint256 fee
    ) internal {
        uint256 remaining = c.total;

        currency.safeTransferFrom(parties.buyer, feeRecipient, fee);
        remaining -= fee;

        Disbursement[] memory tP = c.thirdParty;
        for (uint256 i = 0; i < tP.length; ++i) {
            currency.safeTransferFrom(parties.buyer, tP[i].to, tP[i].amount);
            remaining -= tP[i].amount;
        }

        currency.safeTransferFrom(parties.buyer, parties.seller, remaining);
    }
}
