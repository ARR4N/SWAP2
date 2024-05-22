// SPDX-License-Identifier: UNLICENSED
// Copyright 2024 Divergence Tech Ltd.
pragma solidity 0.8.25;

/// @dev Abstract base contract for all <T>SwapperProposer implementations.
abstract contract SwapperProposerBase {
    /// @dev Returns the address of the factory contract that deploys swappers, regardless of swap type.
    function _swapperDeployer() internal view virtual returns (address);
}
