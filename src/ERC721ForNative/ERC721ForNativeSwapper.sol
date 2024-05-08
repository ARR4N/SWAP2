// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC721ForNativeSwap as Swap} from "./ERC721ForNativeSwap.sol";
import {ERC721ForNativeSwapperBase} from "./ERC721ForNativeSwapperBase.gen.sol";

import {ERC721SwapperLib} from "../ERC721SwapperLib.sol";
import {NativeTokenConsideration} from "../NativeTokenConsideration.sol";
import {Consideration, PayableParties} from "../TypesAndConstants.sol";

contract ERC721ForNativeSwapper is ERC721ForNativeSwapperBase, NativeTokenConsideration {
    constructor(Swap memory swap) payable ERC721ForNativeSwapperBase(swap) {}

    function _beforeFill(Consideration memory c)
        internal
        view
        override(ERC721ForNativeSwapperBase, NativeTokenConsideration)
    {
        NativeTokenConsideration._beforeFill(c);
    }

    function _fill(Swap memory swap) internal override {
        ERC721SwapperLib._transfer(swap.token, _asNonPayableParties(swap.parties));
        NativeTokenConsideration._disburseFunds(swap.parties, swap.consideration);
    }

    function _cancel(PayableParties memory p) internal override(ERC721ForNativeSwapperBase, NativeTokenConsideration) {
        NativeTokenConsideration._cancel(p);
    }

    function _postExecutionInvariantsMet(Swap memory) internal view override returns (bool) {
        return NativeTokenConsideration._postExecutionInvariantsMet();
    }
}
