// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC721ForNativeSwap as Swap} from "./ERC721ForNativeSwap.sol";
import {ERC721ForNativeSwapperBase} from "./ERC721ForNativeSwapperBase.gen.sol";

import {ERC721SwapperLib} from "../ERC721SwapperLib.sol";
import {NativeTokenConsideration} from "../NativeTokenConsideration.sol";

contract ERC721ForNativeSwapper is ERC721ForNativeSwapperBase, NativeTokenConsideration {
    constructor(Swap memory swap) payable ERC721ForNativeSwapperBase(swap) {}

    function _fill(Swap memory swap) internal override {
        NativeTokenConsideration._beforeFill(swap.consideration);
        ERC721SwapperLib._transfer(swap.token, _asNonPayableParties(swap.parties));
        NativeTokenConsideration._disburseFunds(swap.parties, swap.consideration);
    }

    function _cancel(Swap memory swap) internal override {
        NativeTokenConsideration._cancel(swap.parties);
    }

    function _postExecutionInvariantsMet(Swap memory) internal view override returns (bool) {
        return NativeTokenConsideration._postExecutionInvariantsMet();
    }
}
