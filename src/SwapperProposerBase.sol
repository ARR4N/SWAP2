// SPDX-License-Identifier: MIT
// Copyright 2024 Lomita Digital, Inc.
pragma solidity 0.8.25;

/// @dev Abstract base contract for all <T>SwapperProposer implementations.
abstract contract SwapperProposerBase {
    /// @dev Returns the address and chain ID of the factory contract that deploys swappers, regardless of swap type.
    function _swapperDeployer() internal view virtual returns (address, uint256 chainId);
}
