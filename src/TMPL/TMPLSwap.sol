// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Consideration, Parties} from "../TypesAndConstants.sol";
import {ERC721Token} from "../ERC721SwapperLib.sol";

struct TMPLSwap {
    Parties parties; // Can be substituted for PayableParties
    ERC721Token offer; // Can be substituted for any assets
    Consideration consideration;
}
