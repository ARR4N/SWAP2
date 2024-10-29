// SPDX-License-Identifier: MIT
// Copyright 2024 Lomita Digital, Inc.
pragma solidity 0.8.25;

import {Consideration} from "../ConsiderationLib.sol";
import {ERC721TransferLib} from "../ERC721TransferLib.sol";
import {PayableParties} from "../TypesAndConstants.sol";

struct ERC721ForNativeSwap {
    PayableParties parties;
    ERC721TransferLib.ERC721Token offer;
    Consideration consideration;
    uint256 validUntilTime;
}
