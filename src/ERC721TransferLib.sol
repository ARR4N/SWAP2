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
     * @param tokens Any number of ERC721 tokens from a single contract; ids MUST be distinct across the entire array.
     */
    function _transfer(MultiERC721Token memory tokens, Parties memory parties) internal {
        _transfer(tokens, _reusableTransferCallData(parties));
    }

    /**
     * @dev Transfers all tokens from `parties.seller` to `parties.buyer`. The order of transfer is NOT guaranteed.
     * @param tokens An _array_ of MultiERC721Token structs, representing any number of tokens. {addr,id} pairs MUST be
     * distinct across the entire array.
     */
    function _transfer(MultiERC721Token[] memory tokens, Parties memory parties) internal {
        bytes memory callData = _reusableTransferCallData(parties);
        for (uint256 i = 0; i < tokens.length; ++i) {
            _transfer(tokens[i], callData);
        }
    }

    function _reusableTransferCallData(Parties memory parties) private pure returns (bytes memory) {
        return abi.encodeCall(IERC721.transferFrom, (parties.seller, parties.buyer, 0));
    }

    function _transfer(MultiERC721Token memory token, bytes memory reusableCallData) private {
        uint256 tokenIdPtr;
        assembly ("memory-safe") {
            tokenIdPtr := add(reusableCallData, 0x64)
        }

        address addr = address(token.addr);
        uint256[] memory ids = token.ids;

        for (uint256 offset = ids.length * 0x20; offset > 0; offset -= 0x20) {
            assembly ("memory-safe") {
                mcopy(tokenIdPtr, add(ids, offset), 0x20)
            }
            (bool success,) = addr.call(reusableCallData);

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
