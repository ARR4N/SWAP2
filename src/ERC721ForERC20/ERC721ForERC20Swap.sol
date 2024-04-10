// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC721Token} from "../ERC721SwapperLib.sol";
import {Consideration, Parties} from "../TypesAndConstants.sol";

struct ERC721ForERC20Swap {
    Parties parties;
    ERC721Token token;
    Consideration consideration;
    IERC20 currency;
}
