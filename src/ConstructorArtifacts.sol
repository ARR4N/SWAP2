// SPDX-License-Identifier: MIT
// Copyright 2024 Divergence Tech Ltd.
pragma solidity ^0.8.20; // Requires PUSH0

/**
 * @notice A set of modifiers, for use on constructors only, that govern the code deployed to the address after the
 * constructor returns.
 * @dev Single-use contracts that only perform meaningful actions in their constructors don't need to leave significant
 * bytecode in place. As SELFDESTRUCT is deprecated (EIP-6049), an alternative is to minimise the deployed footprint as
 * it costs 200 gas per byte.
 * @dev Even without any public/external functions, Solidity leaves approximately 60 bytes at a cost of ~12k gas.
 */
abstract contract ConstructorArtifacts {
    /**
     * @dev The deployed contract is empty and no additional gas is paid.
     * @dev WARNING: it is possible to send ETH to the deployed contract, permanently locking it.
     */
    modifier emptyContract() {
        _;
        assembly ("memory-safe") {
            return(0, 0)
        }
    }

    /**
     * @dev The deployed contract only contains the STOP op-code, at a cost of 200 gas.
     * @dev WARNING: it is possible to send ETH to the deployed contract, permanently locking it.
     */
    modifier contractAlwaysStops() {
        _;
        assembly ("memory-safe") {
            mstore(0, 0x00) // STOP
            return(0, 1)
        }
    }

    /**
     * @dev The deployed contract is equivalent to return(0,0), at a cost of 600 gas.
     * @dev WARNING: it is possible to send ETH to the deployed contract, permanently locking it.
     */
    modifier contractAlwaysReturnsEmpty() {
        _;
        assembly ("memory-safe") {
            mstore(0, 0x5f5ff3) // PUSH0 PUSH0 RETURN
            return(29, 3)
        }
    }

    /**
     * @dev The deployed contract is equivalent to revert(0,0), at a cost of 600 gas.
     * @dev Unlike all other modifiers, it is impossible to (accidentally) send ETH to the deployed contract as it will
     * revert. ETH can, however, be forced in via SELFDESTRUCT.
     */
    modifier contractAlwaysRevertsEmpty() {
        _;
        assembly ("memory-safe") {
            mstore(0, 0x5f5ffd) // PUSH0 PUSH0 REVERT
            return(29, 3)
        }
    }
}
