// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {Parties} from "./TypesAndConstants.sol";

struct ERC721Token {
    IERC721 addr;
    uint256 id;
}

struct MultiERC721Token {
    IERC721 addr;
    uint256[] ids;
}

library ERC721SwapperLib {
    function _transfer(ERC721Token memory token, Parties memory parties) internal {
        token.addr.transferFrom(parties.seller, parties.buyer, token.id);
    }

    function _transfer(MultiERC721Token[] memory tokens, Parties memory parties) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            IERC721 t = tokens[i].addr;
            for (uint256 j = 0; j < tokens[i].ids.length; ++j) {
                t.transferFrom(parties.seller, parties.buyer, tokens[i].ids[j]);
            }
        }
    }
}
