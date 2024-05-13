// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC721ForNativeSwap as Swap} from "./ERC721ForNativeSwap.sol";
import {ERC721ForNativeSwapperBase} from "./ERC721ForNativeSwapperBase.gen.sol";

import {NativeTokenConsideration} from "../NativeTokenConsideration.sol";
import {SwapperBase} from "../SwapperBase.sol";
import {Consideration, PayableParties} from "../TypesAndConstants.sol";

contract ERC721ForNativeSwapper is ERC721ForNativeSwapperBase, NativeTokenConsideration {
    constructor(Swap memory swap) payable ERC721ForNativeSwapperBase(swap) {}

    function _disburseFunds(Swap memory swap, address payable feeRecipient, uint256 fee) internal override {
        NativeTokenConsideration._disburseFunds(swap.parties, swap.consideration, feeRecipient, fee);
    }

    function _cancel(PayableParties memory p) internal override(SwapperBase, NativeTokenConsideration) {
        NativeTokenConsideration._cancel(p);
    }

    function _postExecutionInvariantsMet(Swap memory) internal view override returns (bool) {
        return NativeTokenConsideration._postExecutionInvariantsMet();
    }
}
