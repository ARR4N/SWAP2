// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Consideration, Parties} from "../TypesAndConstants.sol";
import {ERC721TransferLib} from "../ERC721TransferLib.sol";

struct MultiERC721ForERC20Swap {
    Parties parties;
    ERC721TransferLib.MultiERC721Token[] offer;
    Consideration consideration;
    IERC20 currency;
}
