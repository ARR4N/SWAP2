// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

/// @dev Abstract base contract for all <T>SwapperDeployer implementations.
abstract contract SwapperDeployerBase {
    /**
     * @return recipient Address to which platform fees MUST be sent by swapper contracts.
     * @return basisPoints One-hundredths of a percentage point of swap consideration that MUST be sent to `recipient`.
     */
    function _platformFeeConfig() internal view virtual returns (address payable recipient, uint16 basisPoints);
}
