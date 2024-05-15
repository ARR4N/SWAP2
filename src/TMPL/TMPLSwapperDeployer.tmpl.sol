// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
/**
 * GENERATED CODE - DO NOT EDIT
 */

import {TMPLSwap} from "./TMPLSwap.sol";
import {TMPLSwapper} from "./TMPLSwapper.sol";

import {ETDeployer, ETPredictor} from "../ET.sol";
import {SwapperDeployerBase} from "../SwapperDeployerBase.sol";
import {OnlyPartyCanCancel, Action, ActionMessageLib, FILL, CANCEL_MSG} from "../TypesAndConstants.sol";

/// @dev Predictor of TMPLSwapper contract addresses.
contract TMPLSwapperPredictor is ETPredictor {
    function _swapper(TMPLSwap calldata swap, bytes32 salt) internal view returns (address) {
        return _predictDeploymentAddress(_bytecode(swap), salt);
    }

    function _bytecode(TMPLSwap calldata swap) internal pure returns (bytes memory) {
        return abi.encodePacked(type(TMPLSwapper).creationCode, abi.encode(swap));
    }
}

/// @dev Deployer of TMPLSwapper contracts.
abstract contract TMPLSwapperDeployer is TMPLSwapperPredictor, ETDeployer, SwapperDeployerBase {
    using ActionMessageLib for Action;

    event Swap(address indexed seller, address indexed buyer, bytes32 salt, address swapper, TMPLSwap);

    function fill(TMPLSwap calldata swap, bytes32 salt) external payable returns (address) {
        (address payable feeRecipient, uint16 basisPoints) = _platformFeeConfig();
        address a = _deploy(_bytecode(swap), msg.value, salt, FILL.withFeeConfig(feeRecipient, basisPoints));
        emit Filled(a);
        return a;
    }

    function cancel(TMPLSwap calldata swap, bytes32 salt) external returns (address) {
        if (msg.sender != swap.parties.seller && msg.sender != swap.parties.buyer) {
            revert OnlyPartyCanCancel();
        }
        address a = _deploy(_bytecode(swap), 0, salt, CANCEL_MSG);
        emit Cancelled(a);
        return a;
    }

    function swapper(TMPLSwap calldata swap, bytes32 salt) external view returns (address) {
        return _swapper(swap, salt);
    }

    /**
     * @notice Uses the last block's hash as a salt to predict a swapper address for the swap, and emits a `Swap`
     * event.
     * @dev A salt known to an adversary reduces the security of the swapper address to that of collision resistance
     * (~80 bits) whereas an unknown salt relies on second pre-image resistance (full address space = 160 bits). Using
     * the last block's hash would require computing a collision in the inter-block period (12s) so is sufficient.
     */
    function broadcast(TMPLSwap calldata swap) external returns (bytes32, address) {
        bytes32 salt = blockhash(block.number - 1);
        address s = _swapper(swap, salt);
        emit Swap(swap.parties.seller, swap.parties.buyer, salt, s, swap);
        return (salt, s);
    }
}

/**
 * @dev Compile-time guarantee that the TMPLSwapper constructor has the signature assumed by _bytecode().
 * @dev Always reverts and MUST NOT be used.
 */
function _enforceTMPLSwapperCtorSig() {
    assert(false);
    TMPLSwap memory s;
    new TMPLSwapper(s);
}
