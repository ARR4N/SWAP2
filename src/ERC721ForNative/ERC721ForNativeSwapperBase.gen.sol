// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
/**
 * GENERATED CODE - DO NOT EDIT
 */

import {ERC721ForNativeSwap} from "./ERC721ForNativeSwap.sol";

import {ConstructorArtifacts} from "../ConstructorArtifacts.sol";
import {ET, Message} from "../ET.sol";
import {UnsupportedAction, Disbursement, ISwapperEvents, FILL, CANCEL} from "../TypesAndConstants.sol";

/// @dev Base contract for a ERC721ForNativeSwapper implementation.
abstract contract ERC721ForNativeSwapperBase is ConstructorArtifacts, ET, ISwapperEvents {
    constructor(ERC721ForNativeSwap memory swap) contractAlwaysRevertsEmpty {
        Message action = ET._phoneHome();
        if (action == FILL) {
            _fill(swap);
        } else if (action == CANCEL) {
            _cancel(swap);
        } else {
            revert UnsupportedAction(action);
        }

        assert(_postExecutionInvariantsMet(swap));
    }

    function _fill(ERC721ForNativeSwap memory) internal virtual;
    function _cancel(ERC721ForNativeSwap memory) internal virtual;

    /**
     * @dev Called at the end of the constructor, which reverts if this function returns false.
     * @return Whether all post-execution invariants hold.
     */
    function _postExecutionInvariantsMet(ERC721ForNativeSwap memory) internal virtual returns (bool);
}
