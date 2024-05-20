// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Consideration, Parties} from "../TypesAndConstants.sol";
import {ERC721Token} from "../ERC721SwapperLib.sol";

struct TMPLSwap {
    Parties parties; // MUST be substituted for PayableParties for native-token consideration
    ERC721Token offer; // Can be substituted for any assets
    Consideration consideration;
    IERC20 currency; // SHOULD be removed for native-token consideration
}
