// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {MultiERC721ForERC20Swap as Swap} from "./MultiERC721ForERC20Swap.sol";
import {MultiERC721ForERC20SwapperBase} from "./MultiERC721ForERC20SwapperBase.gen.sol";

import {ERC20Consideration} from "../ERC20Consideration.sol";

contract MultiERC721ForERC20Swapper is MultiERC721ForERC20SwapperBase, ERC20Consideration {
    constructor(Swap memory swap) MultiERC721ForERC20SwapperBase(swap) {}

    function _disburseFunds(Swap memory swap, address payable feeRecipient, uint256 fee) internal override {
        ERC20Consideration._disburseFunds(swap.parties, swap.consideration, swap.currency, feeRecipient, fee);
    }

    function _postExecutionInvariantsMet(Swap memory) internal pure override returns (bool) {
        // Will be removed by the compiler, but explicitly stating that there are no checks.
        return true;
    }
}
