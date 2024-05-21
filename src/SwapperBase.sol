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
    /**
     * @dev All <T>Swappers call _cancel() with their respective [Payable]Parties, the specific one chosen by the
     * compiler.
     * @dev Active cancellation isn't needed by all consideration types, hence the empty implementations. If a
     * <U>Consideration contract overrides a function then the compiler will guide composition of contracts
     * by requiring an explicit override. See `TMPL/ForNativeSwapper.sol.tmpl` as an example.
     */
    function _cancel(Parties memory) internal virtual {}
    function _cancel(PayableParties memory) internal virtual {}

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
