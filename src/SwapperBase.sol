// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Parties, PayableParties} from "./TypesAndConstants.sol";

/// @dev Base contract for all <T>Swapper implementations.
contract SwapperBase {
    function _cancel(Parties memory) internal virtual {}
    function _cancel(PayableParties memory) internal virtual {}

    /// @dev Converts a `PayableParties` struct into a `Parties`, using the same backing memory.
    function _asNonPayableParties(PayableParties memory pay) internal pure returns (Parties memory nonPay) {
        assembly ("memory-safe") {
            nonPay := pay
        }
    }

    /**
     * @dev Echoes its argument unchanged. This is a convenience for code that may have either a `Parties` or a
     * `PayableParties` but needs the former, greatly simplifying code generation by having the compiler choose the
     * correct function based on argument type.
     */
    function _asNonPayableParties(Parties memory p) internal pure returns (Parties memory) {
        return p;
    }
}
