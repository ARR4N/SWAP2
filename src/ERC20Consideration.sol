// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Consideration, Disbursement, Parties} from "./TypesAndConstants.sol";

contract ERC20Consideration {
    function _disburseFunds(Parties memory parties, Consideration memory c, IERC20 currency) internal {
        uint256 remaining = c.total;

        Disbursement[] memory tP = c.thirdParty;
        for (uint256 i = 0; i < tP.length; ++i) {
            currency.transferFrom(parties.buyer, tP[i].to, tP[i].amount);
            remaining -= tP[i].amount;
        }

        currency.transferFrom(parties.buyer, parties.seller, remaining);
    }
}
