// SPDX-License-Identifier: UNLICENSED
// Copyright 2024 Divergence Tech Ltd.
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {Parties} from "./TypesAndConstants.sol";

/**
 * @dev Transfers one or more ERC721 tokens between parties.
 * @dev Note that all `_transfer(<T>, Parties)` functions have effectively the same signature, allowing them to be
 * called without explicit knowledge of the <T> type as the constructor will select the respective function. This is
 * exploited by the `TMPL/SwapperBase.sol.tmpl` template.
 */
library ERC721TransferLib {
    /// @dev Represents a single ERC721 token.
    struct ERC721Token {
        IERC721 addr;
        uint256 id;
    }

    /// @dev Transfers the token from `parties.seller` to `parties.buyer`.
    function _transfer(ERC721Token memory token, Parties memory parties) internal {
        token.addr.transferFrom(parties.seller, parties.buyer, token.id);
    }

    /// @dev Represents multiple ERC721 tokens within the same contract.
    struct MultiERC721Token {
        IERC721 addr;
        uint256[] ids; // MUST be distinct
    }

    /**
     * @dev Transfers all tokens from `parties.seller` to `parties.buyer`. The order of transfer is NOT guaranteed.
     * @param tokens An _array_ of MultiERC721Token structs, representing any number of tokens. {addr,id} pairs MUST be
     * distinct across the entire array.
     */
    function _transfer(MultiERC721Token[] memory tokens, Parties memory parties) internal {
        // Reusable memory buffer for call(), so we only have to copy the tokenId and swap the address being called.
        bytes memory callData = abi.encodeWithSelector(IERC721.transferFrom.selector, parties.seller, parties.buyer, 0);

        uint256 tokenIdPtr;
        assembly ("memory-safe") {
            tokenIdPtr := add(callData, 0x64)
        }

        for (uint256 i = 0; i < tokens.length; ++i) {
            address addr = address(tokens[i].addr);
            uint256[] memory ids = tokens[i].ids;

            for (uint256 offset = tokens[i].ids.length * 0x20; offset > 0; offset -= 0x20) {
                assembly ("memory-safe") {
                    mcopy(tokenIdPtr, add(ids, offset), 0x20)
                }
                (bool success,) = addr.call(callData);

                if (!success) {
                    assembly ("memory-safe") {
                        let free := mload(0x40)
                        returndatacopy(free, 0, returndatasize())
                        revert(free, returndatasize())
                    }
                }
            }
        }
    }
}
