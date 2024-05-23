// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC721TransferLib} from "../ERC721TransferLib.sol";
import {ERC20Consideration, Parties} from "../TypesAndConstants.sol";

struct MultiERC721ForERC20Swap {
    Parties parties;
    ERC721TransferLib.MultiERC721Token[] offer;
    ERC20Consideration consideration;
}
