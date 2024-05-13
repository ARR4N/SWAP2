// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Message} from "./ET.sol";

type Action is bytes4;

/// @dev Indicates that the user requested that the swap be performed.
Action constant FILL = Action.wrap(bytes4(keccak256("FILL")));

/// @dev Indicates that the user requested that the swap be cancelled.
Action constant CANCEL = Action.wrap(bytes4(keccak256("CANCEL")));

Message constant CANCEL_MSG = Message.wrap(bytes32(Action.unwrap(CANCEL)));

library ActionMessageLib {
    function withFeeConfig(Action a, address feeRecipient, uint16 basisPoints) internal pure returns (Message) {
        return Message.wrap(bytes32(abi.encodePacked(a, feeRecipient, basisPoints)));
    }

    function action(Message m) internal pure returns (Action) {
        return Action.wrap(bytes4(Message.unwrap(m)));
    }

    function feeConfig(Message m) internal pure returns (address payable feeRecipient, uint16 basisPoints) {
        uint256 u = uint256(Message.unwrap(m));
        feeRecipient = payable(address(bytes20(bytes28(uint224(u)))));
        basisPoints = uint16(bytes2(bytes8(uint64(u))));
    }
}

function _eq(Action a, Action b) pure returns (bool) {
    return Action.unwrap(a) == Action.unwrap(b);
}

using {_eq as ==} for Action global;

/// @dev Thrown if an address other than the buying party attempts to cancel a swap.
error OnlyBuyerCanCancel();

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
