// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ITestEvents, Token} from "./SwapperTestBase.t.sol";
import {ERC721TransferLib, MultiERC721Token, IERC721} from "../src/ERC721TransferLib.sol";
import {Parties} from "../src/TypesAndConstants.sol";

contract ERC721TransferLibTest is Test, ITestEvents {
    address public tokenTemplate = address(new Token());

    uint256 constant NUM_CONTRACTS = 5;
    uint256 constant TOKENS_PER_CONTRACT = 5;

    function testMultiERC721TokenTransfer(
        address[NUM_CONTRACTS] calldata contracts,
        uint256[NUM_CONTRACTS][TOKENS_PER_CONTRACT] calldata ids,
        Parties memory parties
    ) public {
        vm.assume(parties.seller != parties.buyer);
        vm.assume(parties.seller != address(0));
        vm.assume(parties.buyer != address(0));

        vm.label(parties.seller, "seller");
        vm.label(parties.buyer, "buyer");

        MultiERC721Token[] memory tokens = new MultiERC721Token[](NUM_CONTRACTS);

        for (uint256 i = 0; i < NUM_CONTRACTS; ++i) {
            address a = contracts[i];
            vm.assume(uint160(a) > 0x0a);
            vm.assume(a.code.length == 0);
            vm.etch(a, tokenTemplate.code);

            tokens[i].addr = IERC721(a);
            tokens[i].ids = new uint256[](ids[i].length);

            Token t = Token(a);
            for (uint256 j = 0; j < TOKENS_PER_CONTRACT; ++j) {
                uint256 id = ids[i][j];
                vm.assume(!t.exists(id));
                t.mint(parties.seller, id);

                tokens[i].ids[j] = id;
            }
        }

        _assertOwner(tokens, parties.seller);

        vm.startPrank(parties.seller);
        ERC721TransferLib._transfer(tokens, parties);
        vm.stopPrank();

        _assertOwner(tokens, parties.buyer);
    }

    function _assertOwner(MultiERC721Token[] memory tokens, address owner) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            for (uint256 j = 0; j < tokens[i].ids.length; ++j) {
                assertEq(tokens[i].addr.ownerOf(tokens[i].ids[j]), owner);
            }
        }
    }
}
