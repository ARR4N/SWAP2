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
    /// @dev Thrown if a token address doesn't contain any code.
    error NoCodeAtAddress(address);

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
     * @dev Transfers all tokens from `parties.seller` to `parties.buyer`.
     * @param tokens Any number of ERC721 tokens from a single contract; ids MUST be distinct across the entire array.
     */
    function _transfer(MultiERC721Token memory tokens, Parties memory parties) internal {
        _transfer(tokens, _reusableTransferCallData(parties));
    }

    /**
     * @dev Transfers all tokens from `parties.seller` to `parties.buyer`.
     * @param tokens An _array_ of MultiERC721Token structs, representing any number of tokens. {addr,id} pairs MUST be
     * distinct across the entire array.
     */
    function _transfer(MultiERC721Token[] memory tokens, Parties memory parties) internal {
        bytes memory callData = _reusableTransferCallData(parties);
        for (uint256 i = 0; i < tokens.length; ++i) {
            _transfer(tokens[i], callData);
        }
    }

    /**
     * @dev Returns calldata for `ERC721.transferFrom(parties.seller, parties.buyer, 0)`, which can be reused to avoid
     * unnecessary memory expansion when transferring large numbers of tokens.
     */
    function _reusableTransferCallData(Parties memory parties) private pure returns (bytes memory) {
        return abi.encodeCall(IERC721.transferFrom, (parties.seller, parties.buyer, 0));
    }

    /**
     * @param token Contract and IDs of tokens to be transferred.
     * @param reusableCallData Output of `_reusableTransferCallData()`.
     */
    function _transfer(MultiERC721Token memory token, bytes memory reusableCallData) private {
        address addr = address(token.addr);
        if (addr.code.length == 0) {
            revert NoCodeAtAddress(addr);
        }
        uint256[] memory ids = token.ids;

        assembly ("memory-safe") {
            let idSrc := add(ids, 0x20)
            let idDst := add(reusableCallData, 0x64)
            let dataPtr := add(reusableCallData, 0x20)

            for { let end := add(idSrc, mul(mload(ids), 0x20)) } lt(idSrc, end) { idSrc := add(idSrc, 0x20) } {
                mcopy(idDst, idSrc, 0x20)

                if iszero(call(gas(), addr, 0, dataPtr, reusableCallData, 0, 0)) {
                    // Even though this may extend beyond scratch space, we revert the current context immediately so
                    // it's still memory-safe.
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }
    }
}
