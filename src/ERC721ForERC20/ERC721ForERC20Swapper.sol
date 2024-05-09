// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC721ForERC20Swap as Swap} from "./ERC721ForERC20Swap.sol";
import {ERC721ForERC20SwapperBase} from "./ERC721ForERC20SwapperBase.gen.sol";

import {ERC20Consideration} from "../ERC20Consideration.sol";

contract ERC721ForERC20Swapper is ERC721ForERC20SwapperBase, ERC20Consideration {
    constructor(Swap memory swap) ERC721ForERC20SwapperBase(swap) {}

    function _disburseFunds(Swap memory swap) internal override {
        ERC20Consideration._disburseFunds(swap.parties, swap.consideration, swap.currency);
    }

    function _postExecutionInvariantsMet(Swap memory) internal pure override returns (bool) {
        // Will be removed by the compiler, but explicitly stating that there are no checks.
        return true;
    }
}
