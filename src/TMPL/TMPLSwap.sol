// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC20Consideration} from "../ConsiderationLib.sol";
import {ERC721TransferLib} from "../ERC721TransferLib.sol";
import {Parties} from "../TypesAndConstants.sol";

struct TMPLSwap {
    Parties parties; // MUST be substituted for PayableParties for native-token consideration
    ERC721TransferLib.ERC721Token offer; // Can be substituted for any type for which ERC721TransferLib has a corresponding _transfer() function.
    ERC20Consideration consideration;
}
