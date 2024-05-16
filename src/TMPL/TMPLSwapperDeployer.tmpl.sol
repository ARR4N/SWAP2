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

    event Proposal(address indexed swapper, address indexed seller, address indexed buyer, TMPLSwap, bytes32 salt);

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
     * @notice "Announces" a propsed swap (in the form of a `Proposal` event), using the last block's hash as the salt
     * for the predicted swapper address.
     * @dev This is an optional step and swaps will function without prior proposal, but users SHOULD use this function
     * as it provides two security benefits: (i) a trusted means by which to safely determine the address they need to
     * approve to transfer their assets; and (ii) increasing the security level of the swapper address from 80 to 160
     * bits.
     * @dev A salt known to an adversary reduces the security of the swapper address to that of collision resistance
     * (~80 bits) whereas an unknown salt relies on second pre-image resistance (full address space = 160 bits). Using
     * the last block's hash would require computing a collision in the inter-block period (12s) so is sufficient.
     * @dev This function MAY be called on a different chain to the one on which the swap will occur, provided that the
     * deployer contract has the same address.
     */
    function propose(TMPLSwap calldata swap) external returns (bytes32, address) {
        bytes32 salt = blockhash(block.number - 1);
        address swapper_ = _swapper(swap, salt);
        emit Proposal(swapper_, swap.parties.seller, swap.parties.buyer, swap, salt);
        return (salt, swapper_);
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
