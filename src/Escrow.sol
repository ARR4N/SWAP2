// SPDX-License-Identifier: UNLICENSED
// Copyright 2024 Divergence Tech Ltd.
pragma solidity 0.8.25;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

interface IEscrowEvents {
    event Deposit(address, uint256);
    event Withdrawal(address, uint256);
}

interface IEscrow {
    function deposit(address payable) external payable;
}

contract Escrow is IEscrow, IEscrowEvents {
    error ZeroBalance(address);

    mapping(address => uint256) public balance;

    function deposit(address payable account) external payable {
        balance[account] += msg.value;
        emit Deposit(account, msg.value);
    }

    function withdraw() external {
        withdraw(payable(msg.sender));
    }

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
