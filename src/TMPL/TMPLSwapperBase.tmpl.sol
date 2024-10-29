// SPDX-License-Identifier: MIT
// Copyright 2024 Divergence Tech Ltd.
pragma solidity 0.8.25;
/**
 * GENERATED CODE - DO NOT EDIT
 */

import {TMPLSwap} from "./TMPLSwap.sol";

import {ERC721TransferLib} from "../ERC721TransferLib.sol";
import {IETHome, Message} from "../ET.sol";
import {ConsiderationLib} from "../ConsiderationLib.sol";
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
    SwapExpired,
    currentChainId
} from "../TypesAndConstants.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev Base contract for a TMPLSwapper implementation.
contract TMPLSwapperBase is SwapperBase {
    using ActionMessageLib for Message;
    using ConsiderationLib for *;

    constructor(TMPLSwap memory swap, uint256 currentChainId_) {
        // The TMPLSwapperDeployer always uses its current chain ID, so this is an invariant, and hence the use of
        // assert. Inclusion of the `currentChainId_` argument is purely to couple the CREATE2 address of this contract
        // to the specific chain.
        assert(currentChainId() == currentChainId_);

        Message message = IETHome(msg.sender).etMessage();
        Action action = message.action();

        bytes3 codeToDeploy;

        if (action == FILL) {
            // Expiry of a TMPLSwap and cancellation thereof are effectively the same thing, so we only perform this
            // check in the FILL branch.
            uint256 validUntil = swap.validUntilTime;
            if (validUntil != 0 && block.timestamp > swap.validUntilTime) {
                revert SwapExpired(swap.validUntilTime);
            }

            codeToDeploy = FILLED_ARTIFACT;

            ERC721TransferLib._transfer(swap.offer, _asNonPayableParties(swap.parties));

            (address payable feeRecipient, uint16 basisPoints) = message.feeConfig();
            uint256 fee = Math.mulDiv(swap.consideration.total, basisPoints, 10_000);
            if (fee > swap.consideration.maxPlatformFee) {
                revert ExcessPlatformFee(fee, swap.consideration.maxPlatformFee);
            }

            // MUST remain as the last step before checking post-execution invariants. See ConsiderationLib
            // documentation for rationale.
            swap.consideration._disburse(swap.parties, feeRecipient, fee);
        } else if (action == CANCEL) {
            codeToDeploy = CANCELLED_ARTIFACT;
            // MUST remain as the last step for the same reason as _disburseFunds().
            swap.consideration._cancel(swap.parties, message.escrow());
        } else {
            revert UnsupportedAction(action);
        }

        assert(swap.consideration._postExecutionInvariantsMet(swap.parties));

        assembly ("memory-safe") {
            mstore(0, codeToDeploy)
            return(0, 3)
        }
    }
}
