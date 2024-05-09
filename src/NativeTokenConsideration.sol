// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Consideration, Disbursement, PayableParties, InsufficientBalance} from "./TypesAndConstants.sol";

contract NativeTokenConsideration {
    using Address for address payable;

    function _disburseFunds(PayableParties memory parties, Consideration memory c) internal {
        if (address(this).balance < c.total) {
            revert InsufficientBalance(address(this).balance, c.total);
        }

        Disbursement[] memory tP = c.thirdParty;
        for (uint256 i = 0; i < tP.length; ++i) {
            payable(tP[i].to).sendValue(tP[i].amount);
        }
        _sendEntireBalance(parties.seller);
    }

    function _cancel(PayableParties memory parties) internal virtual {
        _sendEntireBalance(parties.buyer);
    }

    function _sendEntireBalance(address payable to) private {
        to.sendValue(address(this).balance);
    }

    function _postExecutionInvariantsMet() internal view returns (bool) {
        return address(this).balance == 0;
    }
}
