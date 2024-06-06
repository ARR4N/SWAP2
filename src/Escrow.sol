// SPDX-License-Identifier: MIT
// Copyright 2024 Divergence Tech Ltd.
pragma solidity 0.8.25;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

interface IEscrowEvents {
    event Deposit(address, uint256);
    event Withdrawal(address, uint256);
}

/// @dev Minimal interface required for depositing funds in an escrow.
interface IEscrow {
    function deposit(address payable) external payable;
}

/// @notice Permissionless escrow contract for pull payments.
contract Escrow is IEscrow, IEscrowEvents {
    /// @dev Thrown if attempting to withdraw for account with no balance.
    error ZeroBalance(address);

    /// @dev Per-account escrowed balance.
    mapping(address => uint256) public balance;

    /// @dev Deposit the sent value such that it can only be withdrawn into `account`.
    function deposit(address payable account) external payable {
        balance[account] += msg.value;
        emit Deposit(account, msg.value);
    }

    /// @dev Equivalent to `withdraw(msg.sender)`.
    function withdraw() external {
        withdraw(payable(msg.sender));
    }

    /// @dev Withdraw all funds previously deposited for `account`.
    function withdraw(address account) public {
        // CHECK
        uint256 bal = balance[account];
        if (bal == 0) {
            revert ZeroBalance(account);
        }
        // EFFECT
        balance[account] = 0;
        // INTERACTION
        Address.sendValue(payable(account), bal);

        emit Withdrawal(account, bal);
    }
}
