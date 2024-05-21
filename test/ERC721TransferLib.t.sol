// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ITestEvents, Token} from "./SwapperTestBase.t.sol";
import {ERC721TransferLib, IERC721} from "../src/ERC721TransferLib.sol";
import {Parties} from "../src/TypesAndConstants.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract ERC721TransferLibTest is Test, ITestEvents {
    address public tokenTemplate = address(new Token());

    uint256 constant NUM_CONTRACTS = 5;
    uint256 constant TOKENS_PER_CONTRACT = 5;

    function testMultiERC721TokenTransfer(
        bytes32[NUM_CONTRACTS] calldata deploySalts,
        uint256[NUM_CONTRACTS][TOKENS_PER_CONTRACT] calldata ids,
        Parties memory parties
    ) public {
        ERC721TransferLib.MultiERC721Token[] memory tokens = _testSetup(deploySalts, ids, parties);

        _assertOwner(tokens, parties.seller);

        vm.startPrank(parties.seller);
        ERC721TransferLib._transfer(tokens, parties);
        vm.stopPrank();

        _assertOwner(tokens, parties.buyer);
    }

    function testGas(
        bytes32[NUM_CONTRACTS] calldata deploySalts,
        uint256[NUM_CONTRACTS][TOKENS_PER_CONTRACT] calldata ids,
        Parties memory parties
    ) public {
        ERC721TransferLib.MultiERC721Token[] memory tokens = _testSetup(deploySalts, ids, parties);

        vm.startPrank(parties.seller);
        uint256 naiveGas;
        uint256 libGas;

        {
            uint256 snap = vm.snapshot();
            naiveGas = gasleft();

            for (uint256 i = 0; i < tokens.length; ++i) {
                IERC721 t = tokens[i].addr;
                for (uint256 j = 0; j < tokens[i].ids.length; ++j) {
                    t.transferFrom(parties.seller, parties.buyer, tokens[i].ids[j]);
                }
            }

            naiveGas -= gasleft();

            _assertOwner(tokens, parties.buyer);
            vm.revertTo(snap);
        }

        {
            libGas = gasleft();
            ERC721TransferLib._transfer(tokens, parties);
            libGas -= gasleft();
        }

        // 140 gas per token was found empirically; it has no special meaning other than to demonstrate the gas saving
        // in this particular instance and may be a change-detector test.
        assertLt(libGas + 140 * NUM_CONTRACTS * TOKENS_PER_CONTRACT, naiveGas);
        console2.log(naiveGas - libGas);
    }

    mapping(bytes32 => bool) private _saltSeen;

    function _testSetup(
        bytes32[NUM_CONTRACTS] calldata deploySalts,
        uint256[NUM_CONTRACTS][TOKENS_PER_CONTRACT] calldata ids,
        Parties memory parties
    ) internal returns (ERC721TransferLib.MultiERC721Token[] memory) {
        vm.assume(parties.seller != parties.buyer);
        vm.assume(parties.seller != address(0));
        vm.assume(parties.buyer != address(0));

        vm.label(parties.seller, "seller");
        vm.label(parties.buyer, "buyer");

        ERC721TransferLib.MultiERC721Token[] memory tokens = new ERC721TransferLib.MultiERC721Token[](NUM_CONTRACTS);

        for (uint256 i = 0; i < NUM_CONTRACTS; ++i) {
            bytes32 salt = deploySalts[i];
            vm.assume(!_saltSeen[salt]);
            _saltSeen[salt] = true;

            Token t = new Token{salt: deploySalts[i]}();
            tokens[i].addr = t;
            tokens[i].ids = new uint256[](ids[i].length);

            for (uint256 j = 0; j < TOKENS_PER_CONTRACT; ++j) {
                uint256 id = ids[i][j];
                vm.assume(!t.exists(id));
                t.mint(parties.seller, id);

                tokens[i].ids[j] = id;
            }
        }

        return tokens;
    }

    function _assertOwner(ERC721TransferLib.MultiERC721Token[] memory tokens, address owner) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            for (uint256 j = 0; j < tokens[i].ids.length; ++j) {
                assertEq(tokens[i].addr.ownerOf(tokens[i].ids[j]), owner);
            }
        }
    }

    function testMultiERC721TokenTransferNothing(address tokenContract, Parties memory parties) public {
        ERC721TransferLib.MultiERC721Token[] memory tokens = new ERC721TransferLib.MultiERC721Token[](1);
        tokens[0].addr = IERC721(tokenContract);
        ERC721TransferLib._transfer(tokens, parties);
    }

    function testErrorPropagation(uint256 tokenId, Parties memory parties) public {
        // The implementation uses a direct call() and propagates failures with assembly so needs to be tested.

        ERC721TransferLib.MultiERC721Token[] memory tokens = new ERC721TransferLib.MultiERC721Token[](1);
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;

        tokens[0] = ERC721TransferLib.MultiERC721Token({addr: IERC721(tokenTemplate), ids: ids});

        vm.expectRevert(
            parties.buyer == address(0)
                ? abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(0))
                : abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId)
        );
        ERC721TransferLib._transfer(tokens, parties);
    }
}
