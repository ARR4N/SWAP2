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
import {UnsupportedAction, FILL, CANCEL} from "../TypesAndConstants.sol";

/// @dev Base contract for a TMPLSwapper implementation.
abstract contract TMPLSwapperBase is ConstructorArtifacts, ET, SwapperBase {
    constructor(TMPLSwap memory swap) contractAlwaysRevertsEmpty {
        Message action = ET._phoneHome();
        if (action == FILL) {
            _beforeFill(swap.consideration);
            ERC721SwapperLib._transfer(swap.offer, _asNonPayableParties(swap.parties));
            _disburseFunds(swap);
        } else if (action == CANCEL) {
            _cancel(swap.parties);
        } else {
            revert UnsupportedAction(action);
        }

        assert(_postExecutionInvariantsMet(swap));
    }

    function _disburseFunds(TMPLSwap memory) internal virtual;

    /**
     * @dev Called at the end of the constructor, which reverts if this function returns false.
     * @return Whether all post-execution invariants hold.
     */
    function _postExecutionInvariantsMet(TMPLSwap memory) internal virtual returns (bool);
}
