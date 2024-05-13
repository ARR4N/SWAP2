// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
/**
 * GENERATED CODE - DO NOT EDIT
 */

import {TMPLSwap} from "./TMPLSwap.sol";

import {ConstructorArtifacts} from "../ConstructorArtifacts.sol";
import {ERC721SwapperLib} from "../ERC721SwapperLib.sol";
import {ET, Message} from "../ET.sol";
import {SwapperBase} from "../SwapperBase.sol";
import {
    Action,
    ActionMessageLib,
    UnsupportedAction,
    FILL,
    CANCEL,
    ExcessPlatformFee,
    Disbursement
} from "../TypesAndConstants.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev Base contract for a TMPLSwapper implementation.
abstract contract TMPLSwapperBase is ConstructorArtifacts, ET, SwapperBase {
    using ActionMessageLib for Message;

    constructor(TMPLSwap memory swap) contractAlwaysRevertsEmpty {
        Message message = ET._phoneHome();
        Action action = message.action();

        if (action == FILL) {
            ERC721SwapperLib._transfer(swap.offer, _asNonPayableParties(swap.parties));

            (address payable feeRecipient, uint16 basisPoints) = message.feeConfig();
            uint256 fee = Math.mulDiv(swap.consideration.total, basisPoints, 10_000);
            if (fee > swap.consideration.maxPlatformFee) {
                revert ExcessPlatformFee(fee, swap.consideration.maxPlatformFee);
            }

            _disburseFunds(swap, feeRecipient, fee);
        } else if (action == CANCEL) {
            _cancel(swap.parties);
        } else {
            revert UnsupportedAction(action);
        }

        assert(_postExecutionInvariantsMet(swap));
    }

    function _disburseFunds(TMPLSwap memory, address payable, uint256) internal virtual;

    /**
     * @dev Called at the end of the constructor, which reverts if this function returns false.
     * @return Whether all post-execution invariants hold.
     */
    function _postExecutionInvariantsMet(TMPLSwap memory) internal virtual returns (bool);
}
