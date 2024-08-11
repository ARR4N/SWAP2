// SPDX-License-Identifier: UNLICENSED
// Copyright 2024 Divergence Tech Ltd.
pragma solidity 0.8.25;

import {IEscrow} from "./Escrow.sol";
import {currentChainId} from "./TypesAndConstants.sol";

interface ISwapperDeployerEvents {
    /// @dev SHOULD be emitted when the values to be returned by `_platformFeeConfig()` change.
    event PlatformFeeChanged(address indexed recipient, uint16 basisPoints);
}

/// @dev Abstract base contract for all <T>SwapperDeployer implementations.
abstract contract SwapperDeployerBase is ISwapperDeployerEvents {
    /**
     * @return recipient Address to which platform fees MUST be sent by swapper contracts.
     * @return basisPoints One-hundredths of a percentage point of swap consideration that MUST be sent to `recipient`.
     */
    function _platformFeeConfig() internal view virtual returns (address payable recipient, uint16 basisPoints);

    /**
     * @return Address of an IEscrow contract, for possible use when native-token `cancel()` fails to reimburse the
     * buyer.
     */
    function _escrow() internal view virtual returns (IEscrow);

    /// @return The current chain ID.
    function _currentChainId() internal view returns (uint256) {
        return currentChainId();
    }
}
