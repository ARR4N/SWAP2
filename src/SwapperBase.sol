// SPDX-License-Identifier: UNLICENSED
// Copyright 2024 Divergence Tech Ltd.
pragma solidity 0.8.25;

import {Parties, PayableParties} from "./TypesAndConstants.sol";

/**
 * @dev Base contract for all <T>Swapper implementations. As implementations are created by simple text substitution
 * from templates, they require function overloading based on <T>Swap struct fields; this contract enables such
 * behaviour, greatly simplifying code generation.
 */
contract SwapperBase {
    /// @dev Converts a `PayableParties` struct into a `Parties`, using the same backing memory.
    function _asNonPayableParties(PayableParties memory pay) internal pure returns (Parties memory nonPay) {
        assembly ("memory-safe") {
            nonPay := pay
        }
    }

    /// @dev Echoes its argument unchanged.
    function _asNonPayableParties(Parties memory p) internal pure returns (Parties memory) {
        return p;
    }
}
