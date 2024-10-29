// SPDX-License-Identifier: MIT
// Copyright 2024 Lomita Digital, Inc.
pragma solidity 0.8.25;
/**
 * GENERATED CODE - DO NOT EDIT
 */

import {TMPLSwap} from "./TMPLSwap.sol";
import {TMPLSwapperBase} from "./TMPLSwapperBase.tmpl.sol";

/// @notice Executes the TMPLSwap received in the constructor.
/// @author Arran Schlosberg (@divergencearran / github.com/arr4n)
contract TMPLSwapper is TMPLSwapperBase {
    constructor(TMPLSwap memory swap, uint256 currentChainId) TMPLSwapperBase(swap, currentChainId) {}
}
