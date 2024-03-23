// SPDX-License-Identifier: MIT
// Copyright 2024 Divergence Tech Ltd.
pragma solidity ^0.8.24; // Requires TLOAD/TSTORE

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

/**
 * @dev An arbitrary word that a deploying contract can pass to a CREATE2-deployed contract that "phones home". By
 * accessing the Message in this manner, the constructor arguments can remain static so the deployment address is
 * independent of the Message.
 */
type Message is bytes32;

/**
 * @notice A CREATE2-deployed contract that can phone home to receive a Message.
 * @dev Phoning home is typically performed in a constrctor and MUST be done in the same transaction as Messages are
 * kept in transient storage.
 * @dev ET contracts SHOULD NOT be deployed directly, but instead via ETDeployer._deploy().
 * @author Arran Schlosberg (@divergencearran / github.com/aschlosberg)
 */
contract ET {
    function _phoneHome() internal view returns (Message) {
        return IETHome(msg.sender).etMessage();
    }
}

/**
 * @dev The interface allowing an ET contract to phone home to its deployer.
 */
interface IETHome {
    function etMessage() external view returns (Message);
}

/**
 * @dev Deployer of ET contracts, responsible for storing Messages and making them available to deployed contracts.
 * @author Arran Schlosberg (@divergencearran / github.com/aschlosberg)
 */
contract ETDeployer is IETHome {
    /**
     * @dev Deploys an ET contract, first transiently storing the Message to make it available via etMessage().
     * @param bytecode Creation bytecode of the contract to be deployed; aka init_code or creationCode.
     * @param salt CREATE2 salt.
     * @param message Message to be made available to the deployed contract if it calls etMessage() on this contract.
     * @return Address of the deployed contract.
     * @custom:reverts If deployment fails; propagates the return data from CREATE2, which will be empty if attempting
     * to re-deploy to the same address.
     */
    function _deploy(bytes memory bytecode, bytes32 salt, Message message) internal returns (address) {
        address predicted = _predictDeploymentAddress(bytecode, salt);
        address deployed;

        assembly ("memory-safe") {
            // There is no need to explicitly clear this TSTORE (as solc recommends) because it is uniquely tied to the
            // deployed contract, which can never be reused.
            tstore(shr(96, shl(96, predicted)), message)
            deployed := create2(callvalue(), add(bytecode, 0x20), mload(bytecode), salt)
        }
        if (deployed != address(0)) {
            assert(deployed == predicted);
            return deployed;
        }

        // NOT memory-safe as we're reverting on all paths from here.
        assembly {
            returndatacopy(0, 0, returndatasize())
            revert(0, returndatasize())
        }
    }

    /**
     * @dev Convenience wrapper around OpenZeppelin's Create2.computeAddress() to match the argument signature of
     * _deploy().
     */
    function _predictDeploymentAddress(bytes memory bytecode, bytes32 salt) internal view returns (address) {
        return Create2.computeAddress(salt, keccak256(bytecode), address(this));
    }

    /**
     * @dev Called by the deployed ET contract to receive its message.
     * @return m The Message argument passed to _deploy().
     */
    function etMessage() external view returns (Message m) {
        assembly ("memory-safe") {
            m := tload(caller())
        }
    }
}

/**
 * @dev Equality check for two Messages, used globally as ==.
 */
function _eq(Message a, Message b) pure returns (bool) {
    return Message.unwrap(a) == Message.unwrap(b);
}

using {_eq as ==} for Message global;

/**
 * @dev Inequality check for two Messages, used globally as !=.
 */
function _neq(Message a, Message b) pure returns (bool) {
    return !_eq(a, b);
}

using {_neq as !=} for Message global;
