// SPDX-License-Identifier: MIT
// Copyright 2024 Lomita Digital, Inc.
pragma solidity 0.8.25;

import {Consideration} from "../ConsiderationLib.sol";
import {ERC721TransferLib} from "../ERC721TransferLib.sol";
import {PayableParties} from "../TypesAndConstants.sol";

struct MultiERC721ForNativeSwap {
    PayableParties parties;
    ERC721TransferLib.MultiERC721Token[] offer;
    Consideration consideration;
    uint256 validUntilTime;
}
