// SPDX-License-Identifier: MIT
// Copyright 2024 Divergence Tech Ltd.
pragma solidity ^0.8.24;

/// @dev CREATE2 convenience wrapper allowing for precise error-path testing.
library Create2 {
    /// @dev Thrown when create2() fails with returndatasize()==0; one such reason is a create collision (redeployment).
    error Create2EmptyRevert();

    /**
     * @dev create2-deploys the `bytecode`.
     * @param bytecode Creation code for deployed contract.
     * @param value Value to send during deployment.
     * @param salt create2() salt.
     */
    function deploy(bytes memory bytecode, uint256 value, bytes32 salt) internal returns (address) {
        address deployed;
        assembly ("memory-safe") {
            deployed := create2(value, add(bytecode, 0x20), mload(bytecode), salt)
        }
        if (deployed != address(0)) {
            return deployed;
        }

        assembly ("memory-safe") {
            let free := mload(0x40)

            if iszero(returndatasize()) {
                mstore(free, 0x33d2bae4) // Create2EmptyRevert()
                revert(add(free, 28), 4)
            }

            returndatacopy(free, 0, returndatasize())
            revert(free, returndatasize())
        }
    }
}
