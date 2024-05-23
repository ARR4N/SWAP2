// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC20Consideration} from "../ConsiderationLib.sol";
import {ERC721TransferLib} from "../ERC721TransferLib.sol";
import {Parties} from "../TypesAndConstants.sol";

struct ERC721ForERC20Swap {
    Parties parties;
    ERC721TransferLib.ERC721Token offer;
    ERC20Consideration consideration;
}
