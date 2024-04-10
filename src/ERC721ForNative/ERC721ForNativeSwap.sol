// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC721Token} from "../ERC721SwapperLib.sol";
import {Consideration, PayableParties} from "../TypesAndConstants.sol";

struct ERC721ForNativeSwap {
    PayableParties parties;
    ERC721Token token;
    Consideration consideration;
}
