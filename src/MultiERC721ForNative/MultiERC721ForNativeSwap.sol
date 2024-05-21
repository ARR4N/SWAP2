// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Consideration, PayableParties} from "../TypesAndConstants.sol";
import {MultiERC721Token} from "../ERC721TransferLib.sol";

struct MultiERC721ForNativeSwap {
    PayableParties parties;
    MultiERC721Token[] offer;
    Consideration consideration;
}
