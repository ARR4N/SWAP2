// SPDX-License-Identifier: MIT
// Copyright 2024 Lomita Digital, Inc.
pragma solidity 0.8.25;

import {ERC20Consideration} from "../ConsiderationLib.sol";
import {ERC721TransferLib} from "../ERC721TransferLib.sol";
import {Parties} from "../TypesAndConstants.sol";

struct MultiERC721ForERC20Swap {
    Parties parties;
    ERC721TransferLib.MultiERC721Token[] offer;
    ERC20Consideration consideration;
    uint256 validUntilTime;
}
