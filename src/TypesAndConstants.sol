// SPDX-License-Identifier: UNLICENSED
// Copyright 2024 Divergence Tech Ltd.
pragma solidity ^0.8.24;

import {Message} from "./ET.sol";

/**
 * =======
 *
 * Actions
 *
 * =======
 */

/**
 * @dev Denotes an action that a swapper contract must perform.
 * @dev Swapper contracts "phone home" to their deployer, receiving a single-word `Message`. An `Action` is analogous
 * to a function selector in said `Message`, with the remaining bytes being analogous to call data.
 */
type Action is bytes4;

/// @dev Indicates that the user requested that the swap be performed.
Action constant FILL = Action.wrap(bytes4(keccak256("FILL")));

/// @dev Indicates that the user requested that the swap be cancelled.
Action constant CANCEL = Action.wrap(bytes4(keccak256("CANCEL")));

/// @dev A precomputed `Message` with the cancellation `Action` as it has no arguments.
Message constant CANCEL_MSG = Message.wrap(bytes32(Action.unwrap(CANCEL)));

/// @dev Converts between `Action` and `Message` types.
library ActionMessageLib {
    /// @dev Appends the `FILL` action with platform-fee configuration. See `SwapperDeployerBase` re params.
    function fillWithFeeConfig(address feeRecipient, uint16 basisPoints) internal pure returns (Message) {
        return Message.wrap(bytes32(abi.encodePacked(FILL, feeRecipient, basisPoints)));
    }

    /// @dev Extracts the `Action` from the `Message`, assuming that it is the prefix.
    function action(Message m) internal pure returns (Action) {
        return Action.wrap(bytes4(Message.unwrap(m)));
    }

    /// @dev Inverse of fillWithFeeConfig().
    function feeConfig(Message m) internal pure returns (address payable feeRecipient, uint16 basisPoints) {
        uint256 u = uint256(Message.unwrap(m));
        feeRecipient = payable(address(bytes20(bytes28(uint224(u)))));
        basisPoints = uint16(bytes2(bytes8(uint64(u))));
    }
}

/**
 * @dev Equality check for two Actions, used globally as ==.
 */
function _eq(Action a, Action b) pure returns (bool) {
    return Action.unwrap(a) == Action.unwrap(b);
}

using {_eq as ==} for Action global;

/**
 * ===========================
 *
 * Deployed contract artifacts
 *
 * To minimise gas, swapper contracts deploy minimal footprints of only 3 bytes (600 gas). Although single-byte
 * artifacts are possible, cleanly reverting contracts are desirable (see below). As such, all artifacts are equivalent
 * to `revert(0,0)` but differ in their approach so their codehashes can be used as a record of the `Action` taken.
 *
 * One use case of native-token consideration is to allow for prepayment of consideration into the predicted swapper
 * address. Reverting contracts avoid accidental locking of funds should there be (a) a race condition between buyer
 * prepayment and seller cancellation; or (b) buyer's accidentally reusing a swapper address from a previous trade.
 *
 * ===========================
 */

/// @dev Contract code to deploy when the fill() function is called; simply `revert(0,0)`.
bytes3 constant FILLED_ARTIFACT = 0x5f5ffd; // PUSH0 PUSH0 REVERT

/// @dev Codehash of a swapper artifact denoting that the swap was filled.
bytes32 constant FILLED_CODEHASH = keccak256(abi.encodePacked(uint24(FILLED_ARTIFACT)));

/// @dev Contract code to deploy when the cancel() function is called; functionally equivalent to `FILLED_ARTIFACT`.
bytes3 constant CANCELLED_ARTIFACT = 0x585ffd; // PC(0) PUSH0 REVERT

/// @dev Codehash of a swapper artifact denoting that the swap was cancelled.
bytes32 constant CANCELLED_CODEHASH = keccak256(abi.encodePacked(uint24(CANCELLED_ARTIFACT)));

/// @dev Codehash denoting that a (presumed) swapper is yet to be deployed.
bytes32 constant PENDING_CODEHASH = keccak256("");

/// @dev Status of a swapper contract, determined from an account's codehash.
enum SwapStatus {
    Pending,
    Filled,
    Cancelled,
    Invalid
}

/**
 * @dev Determines the `SwapStatus` of a swapper.
 * @param swapper Predicted or existing address of a swapper contract. MUST be a valid swapper address otherwise the
 * returned value is invalid.
 */
function swapStatus(address swapper) view returns (SwapStatus) {
    bytes32 h = swapper.codehash;
    // EIP-1052 differentiates between non-existent and existent-but-codeless accounts. Any prepayment of ETH to the
    // swapper will move it from former to latter and change the value returned by EXTCODEHASH.
    if (h == 0 || h == PENDING_CODEHASH) {
        return SwapStatus.Pending;
    }
    if (h == FILLED_CODEHASH) {
        return SwapStatus.Filled;
    }
    if (h == CANCELLED_CODEHASH) {
        return SwapStatus.Cancelled;
    }
    return SwapStatus.Invalid;
}

/**
 * ======
 *
 * Errors
 *
 * ======
 */

/// @dev Thrown if an address other than the selling or buying party attempts to cancel a swap.
error OnlyPartyCanCancel();

/// @dev Thrown if phoning home returns an unsupported action. NOTE: if this happens there is a bug.
error UnsupportedAction(Action);

/// @dev Thrown by native-token swappers if the contract balance is less than `Consideration.total`.
error InsufficientBalance(uint256 actual, uint256 expected);

/// @dev Thrown if the platform fee is greater than the threshold in the swap struct.
error ExcessPlatformFee(uint256 fee, uint256 max);

struct Parties {
    address seller;
    address buyer;
}

struct PayableParties {
    address payable seller;
    address payable buyer;
}

struct Disbursement {
    address to;
    uint256 amount;
}

struct Consideration {
    Disbursement[] thirdParty;
    uint256 maxPlatformFee;
    uint256 total;
}

interface ISwapperEvents {
    event Filled(address swapper);
    event Cancelled(address swapper);
}
