// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {TMPLSwap as Swap} from "./TMPLSwap.sol";
import {TMPLSwapperBase} from "./TMPLSwapperBase.gen.sol";

contract TMPLSwapper is TMPLSwapperBase {
    constructor(Swap memory swap) TMPLSwapperBase(swap) {}

    function _disburseFunds(Swap memory, address payable, uint256) internal override {}

    function _postExecutionInvariantsMet(Swap memory) internal pure override returns (bool) {
        return false;
    }
}
