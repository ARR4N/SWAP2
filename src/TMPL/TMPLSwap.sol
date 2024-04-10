// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Consideration, Parties} from "../TypesAndConstants.sol";

struct TMPLSwap {
    Parties parties; // Can be substituted for PayableParties
    // e.g. ERC721Token token;
    Consideration consideration;
}
