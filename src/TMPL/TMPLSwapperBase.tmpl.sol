// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
/**
 * GENERATED CODE - DO NOT EDIT
 */

import {TMPLSwap} from "./TMPLSwap.sol";

import {ConstructorArtifacts} from "../ConstructorArtifacts.sol";
import {ET, Message} from "../ET.sol";
import {
    UnsupportedAction,
    Parties,
    PayableParties,
    Consideration,
    ISwapperEvents,
    FILL,
    CANCEL
} from "../TypesAndConstants.sol";

/// @dev Base contract for a TMPLSwapper implementation.
abstract contract TMPLSwapperBase is ConstructorArtifacts, ET, ISwapperEvents {
    constructor(TMPLSwap memory swap) contractAlwaysRevertsEmpty {
        Message action = ET._phoneHome();
        if (action == FILL) {
            _beforeFill(swap.consideration);
            _fill(swap);
        } else if (action == CANCEL) {
            _cancel(swap.parties);
        } else {
            revert UnsupportedAction(action);
        }

        assert(_postExecutionInvariantsMet(swap));
    }

    function _beforeFill(Consideration memory) internal view virtual {}
    function _fill(TMPLSwap memory) internal virtual;

    function _cancel(Parties memory) internal virtual {}
    function _cancel(PayableParties memory) internal virtual {}

    /**
     * @dev Called at the end of the constructor, which reverts if this function returns false.
     * @return Whether all post-execution invariants hold.
     */
    function _postExecutionInvariantsMet(TMPLSwap memory) internal virtual returns (bool);
}
