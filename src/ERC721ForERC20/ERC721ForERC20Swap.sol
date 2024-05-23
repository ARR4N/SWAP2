// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC721TransferLib} from "../ERC721TransferLib.sol";
import {ERC20Consideration, Parties} from "../TypesAndConstants.sol";

struct ERC721ForERC20Swap {
    Parties parties;
    ERC721TransferLib.ERC721Token offer;
    ERC20Consideration consideration;
}
