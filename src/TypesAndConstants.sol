// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Message} from "./ET.sol";

/// @dev Thrown if an address other than the buying party attempts to cancel a swap.
error OnlyBuyerCanCancel();

/// @dev Thrown if phoning home returns an unsupported action. NOTE: if this happens there is a bug.
error UnsupportedAction(Message);

/// @dev Thrown by native-token swappers if the contract balance is less than `Consideration.total`.
error InsufficientBalance(uint256 actual, uint256 expected);

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
    uint256 total;
}

interface ISwapperEvents {
    event Filled(address swapper);
    event Cancelled(address swapper);
}

/// @dev Indicates that the user requested that the swap be performed.
Message constant FILL = Message.wrap(bytes32(bytes4(keccak256("FILL"))));

/// @dev Indicates that the user requested that the swap be cancelled.
Message constant CANCEL = Message.wrap(keccak256("CANCEL"));
