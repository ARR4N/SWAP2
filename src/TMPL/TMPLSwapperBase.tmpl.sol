// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
/**
 * GENERATED CODE - DO NOT EDIT
 */

import {TMPLSwap} from "./TMPLSwap.sol";

import {ERC721SwapperLib} from "../ERC721SwapperLib.sol";
import {ET, Message} from "../ET.sol";
import {SwapperBase} from "../SwapperBase.sol";
import {
    Action,
    ActionMessageLib,
    UnsupportedAction,
    FILL,
    CANCEL,
    FILLED_ARTIFACT,
    CANCELLED_ARTIFACT,
    ExcessPlatformFee,
    Disbursement
} from "../TypesAndConstants.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev Base contract for a TMPLSwapper implementation.
abstract contract TMPLSwapperBase is ET, SwapperBase {
    using ActionMessageLib for Message;

    constructor(TMPLSwap memory swap) {
        Message message = ET._phoneHome();
        Action action = message.action();

        uint256 codeToDeploy = 0xFE; // INVALID

        if (action == FILL) {
            codeToDeploy = FILLED_ARTIFACT;

            ERC721SwapperLib._transfer(swap.offer, _asNonPayableParties(swap.parties));

            (address payable feeRecipient, uint16 basisPoints) = message.feeConfig();
            uint256 fee = Math.mulDiv(swap.consideration.total, basisPoints, 10_000);
            if (fee > swap.consideration.maxPlatformFee) {
                revert ExcessPlatformFee(fee, swap.consideration.maxPlatformFee);
            }

            _disburseFunds(swap, feeRecipient, fee);
        } else if (action == CANCEL) {
            codeToDeploy = CANCELLED_ARTIFACT;
            _cancel(swap.parties);
        } else {
            revert UnsupportedAction(action);
        }

        assert(_postExecutionInvariantsMet(swap));

        assembly ("memory-safe") {
            mstore(0, codeToDeploy)
            return(29, 3)
        }
    }

    function _disburseFunds(TMPLSwap memory, address payable, uint256) internal virtual;

    /**
     * @dev Called at the end of the constructor, which reverts if this function returns false.
     * @return Whether all post-execution invariants hold.
     */
    function _postExecutionInvariantsMet(TMPLSwap memory) internal virtual returns (bool);
}
