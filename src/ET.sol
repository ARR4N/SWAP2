// SPDX-License-Identifier: MIT
// Copyright 2024 Divergence Tech Ltd.
pragma solidity ^0.8.24; // Requires TLOAD/TSTORE

import {Create2} from "./Create2.sol";
import {Create2 as OZCreate2} from "@openzeppelin/contracts/utils/Create2.sol";

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
 * @author Arran Schlosberg (@divergencearran / github.com/arr4n)
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
 * @dev Predictor of ET contract addresses. Little more than a wrapper around OpenZeppelin's Create2 library.
 * @author Arran Schlosberg (@divergencearran / github.com/arr4n)
 */
library ETPredictor {
    /**
     * @dev Convenience wrapper around OpenZeppelin's Create2.computeAddress() to match the argument signature of
     * `ETDeployer._deploy()`, assuming `address(this)` as the `deployer`.
     */
    function deploymentAddress(bytes memory bytecode, bytes32 salt) internal view returns (address) {
        return deploymentAddress(bytecode, salt, address(this));
    }

    /**
     * @dev Convenience wrapper around OpenZeppelin's Create2.computeAddress() to mirror the argument signature of
     * `ETDeployer._deploy()`, with the exception of an additional `deployer` address.
     */
    function deploymentAddress(bytes memory bytecode, bytes32 salt, address deployer) internal pure returns (address) {
        return OZCreate2.computeAddress(salt, keccak256(bytecode), deployer);
    }
}

/**
 * @dev Deployer of ET contracts, responsible for storing Messages and making them available to deployed contracts.
 * @author Arran Schlosberg (@divergencearran / github.com/arr4n)
 */
contract ETDeployer is IETHome {
    error PredictedAddressMismatch(address deployed, address predicted);

    /**
     * @dev Deploys an ET contract, first transiently storing the Message to make it available via etMessage().
     * @param predicted Predicted deployment address, saving gas if pre-computed off-chain.
     * @param bytecode Creation bytecode of the contract to be deployed; aka init_code or creationCode.
     * @param value Amount, in wei, to send during deployment.
     * @param salt CREATE2 salt.
     * @param message Message to be made available to the deployed contract if it calls etMessage() on this contract.
     * @return Address of the deployed contract.
     * @custom:reverts If deployment fails; propagates the return data from CREATE2, which will be empty if attempting
     * to re-deploy to the same address.
     */
    function _deploy(address predicted, bytes memory bytecode, uint256 value, bytes32 salt, Message message)
        internal
        returns (address)
    {
        assembly ("memory-safe") {
            // There is no need to explicitly clear this TSTORE (as solc recommends) because it is uniquely tied to the
            // deployed contract, which can never be reused.
            tstore(shr(96, shl(96, predicted)), message)
        }

        address deployed = Create2.deploy(bytecode, value, salt);
        if (deployed != predicted) {
            revert PredictedAddressMismatch(deployed, predicted);
        }
        return deployed;
    }

    /// @dev Identical to `_deploy(address predicted, ...)` except that the predicted address is computed.
    function _deploy(bytes memory bytecode, uint256 value, bytes32 salt, Message message) internal returns (address) {
        return _deploy(ETPredictor.deploymentAddress(bytecode, salt), bytecode, value, salt, message);
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
