// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ISwapperEvents} from "./TypesAndConstants.sol";

/// @dev Abstract base contract for all <T>SwapperDeployer implementations.
abstract contract SwapperDeployerBase is ISwapperEvents {
    function _platformFeeConfig() internal view virtual returns (address payable recipient, uint16 basisPoints);
}
