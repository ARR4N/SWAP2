// SPDX-License-Identifier: MIT
// Copyright 2024 Lomita Digital, Inc.
pragma solidity 0.8.25;
/**
 * GENERATED CODE - DO NOT EDIT
 */

import {TMPLSwap} from "./TMPLSwap.sol";
import {TMPLSwapper} from "./TMPLSwapper.tmpl.sol";

import {ETDeployer, ETPredictor} from "../ET.sol";
import {SwapperDeployerBase} from "../SwapperDeployerBase.sol";
import {SwapperProposerBase} from "../SwapperProposerBase.sol";
import {OnlyPartyCanCancel, ActionMessageLib, CANCEL_MSG, ISwapperEvents} from "../TypesAndConstants.sol";

/// @dev Predictor of TMPLSwapper contract addresses.
/// @author Arran Schlosberg (@divergencearran / github.com/arr4n)
contract TMPLSwapperPredictor {
    function _swapper(TMPLSwap calldata swap, bytes32 salt, address deployer, uint256 chainId)
        internal
        pure
        returns (address)
    {
        return ETPredictor.deploymentAddress(_bytecode(swap, chainId), salt, deployer);
    }

    function _bytecode(TMPLSwap calldata swap, uint256 chainId) internal pure returns (bytes memory) {
        return abi.encodePacked(type(TMPLSwapper).creationCode, abi.encode(swap, chainId));
    }
}

/// @dev Deployer of TMPLSwapper contracts.
/// @author Arran Schlosberg (@divergencearran / github.com/arr4n)
abstract contract TMPLSwapperDeployer is TMPLSwapperPredictor, ETDeployer, SwapperDeployerBase, ISwapperEvents {
    /// @dev Execute the `TMPLSwap`, transferring all assets between the parties.
    function fillTMPL(TMPLSwap calldata swap, bytes32 salt) external payable returns (address) {
        (address payable feeRecipient, uint16 basisPoints) = _platformFeeConfig();
        address a = _deploy(
            _bytecode(swap, _currentChainId()),
            msg.value,
            salt,
            ActionMessageLib.fillWithFeeConfig(feeRecipient, basisPoints)
        );
        emit Filled(a);
        return a;
    }

    /// @dev Permanently invalidate the `TMPLSwap`.
    function cancelTMPL(TMPLSwap calldata swap, bytes32 salt) external returns (address) {
        if (msg.sender != swap.parties.seller && msg.sender != swap.parties.buyer) {
            revert OnlyPartyCanCancel();
        }
        address a = _deploy(_bytecode(swap, _currentChainId()), 0, salt, ActionMessageLib.cancelWithEscrow(_escrow()));
        emit Cancelled(a);
        return a;
    }

    /**
     * @notice Computes the address of the swapper contract that will be deployed to execute the `TMPLSwap`.
     * @dev Important: see `TMPLSwapperProposer.propose()` as an alternative.
     */
    function swapperOfTMPL(TMPLSwap calldata swap, bytes32 salt) external view returns (address) {
        return _swapper(swap, salt, address(this), _currentChainId());
    }
}

interface ITMPLSwapperProposerEvents {
    event TMPLProposal(address indexed swapper, address indexed seller, address indexed buyer, TMPLSwap, bytes32 salt);
}

/// @author Arran Schlosberg (@divergencearran / github.com/arr4n)
abstract contract TMPLSwapperProposer is TMPLSwapperPredictor, ITMPLSwapperProposerEvents, SwapperProposerBase {
    /**
     * @notice "Announces" a propsed swap (in the form of a `Proposal` event), using the last block's hash as the salt
     * for the predicted swapper address.
     * @dev This is an optional step and swaps will function without prior proposal, but users SHOULD use this function
     * as it provides two security benefits: (i) a trusted means by which to safely determine the address they need to
     * approve to transfer their assets; and (ii) increasing the security level of the swapper address from 80 to 160
     * bits.
     * @dev A salt known to an adversary reduces the security of the swapper address to that of collision resistance
     * (~80 bits) whereas an unknown salt relies on second pre-image resistance (full address space = 160 bits). Using
     * the last block's hash would require computing a collision in the inter-block period so is sufficient. The Bitcoin
     * hash rate at the time of writing is almost 800e18 Hz, which would require a little over 25 minutes to brute-force
     * attack 80-bit security: https://www.wolframalpha.com/input?i=%282%5E80+%2F+800e18%29+seconds.
     * @dev This function MAY be called on a different chain to the one on which the swap will occur, provided that the
     * deployer contract has the same address.
     */
    function proposeTMPL(TMPLSwap calldata swap) external returns (bytes32, address) {
        // We use blockhash instead of difficulty to allow this to work on chains other than ETH mainnet. The
        // malleability of block hashes is too low and their rate of production too slow for an attack based on
        // discarding undesirable salts.
        bytes32 salt = blockhash(block.number - 1);
        (address deployer, uint256 chainId) = _swapperDeployer();
        address swapper_ = _swapper(swap, salt, deployer, chainId);
        emit TMPLProposal(swapper_, swap.parties.seller, swap.parties.buyer, swap, salt);
        return (salt, swapper_);
    }

    function _swapperDeployer(TMPLSwap calldata) internal virtual returns (address, uint256 chainId) {
        return _swapperDeployer();
    }
}

/**
 * @dev Compile-time guarantee that the TMPLSwapper constructor has the signature assumed by _bytecode().
 * @dev Always reverts and MUST NOT be used.
 */
function _enforceTMPLSwapperCtorSig() {
    assert(false);
    TMPLSwap memory s;
    new TMPLSwapper(s, uint256(0));
}
