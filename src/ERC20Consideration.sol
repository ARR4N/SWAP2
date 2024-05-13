// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Consideration, Disbursement, Parties} from "./TypesAndConstants.sol";

contract ERC20Consideration {
    using SafeERC20 for IERC20;

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
