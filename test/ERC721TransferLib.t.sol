// SPDX-License-Identifier: MIT
// Copyright 2024 Divergence Tech Ltd.
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ITestEvents, Token} from "./SwapperTestBase.t.sol";
import {ERC721TransferLib, IERC721} from "../src/ERC721TransferLib.sol";
import {Parties} from "../src/TypesAndConstants.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract ERC721Receiver is IERC721Receiver {
    mapping(uint256 => bytes) public tokenData;

    function onERC721Received(address, address, uint256 tokenId, bytes calldata data) external returns (bytes4) {
        tokenData[tokenId] = data;
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract ERC721Transferrer {
    function transfer(ERC721TransferLib.MultiERC721Token[] memory tokens, Parties memory parties) external {
        ERC721TransferLib._transfer(tokens, parties);
    }
}

contract ERC721TransferLibTest is Test, ITestEvents {
    using ERC721TransferLib for *;

    address public tokenTemplate = address(new Token());

    uint256 constant NUM_CONTRACTS = 5;
    uint256 constant TOKENS_PER_CONTRACT = 10;

    function testERC721TokenTransfers(
        bytes32[NUM_CONTRACTS] calldata deploySalts,
        uint256[TOKENS_PER_CONTRACT][NUM_CONTRACTS] calldata ids,
        Parties memory parties
    ) public {
        vm.assume(parties.buyer.code.length == 0); // otherwise safeTransferFrom() will fail

        ERC721TransferLib.MultiERC721Token[] memory tokens = _testSetup(deploySalts, ids, parties);

        function(ERC721TransferLib.MultiERC721Token[] memory, Parties memory)[6] memory funcs = [
            _transferBatch,
            _safeTransferBatch,
            _transferPerContract,
            _safeTransferPerContract,
            _transferIndividually,
            _safeTransferIndividually
        ];

        for (uint256 i = 0; i < funcs.length; ++i) {
            uint256 snap = vm.snapshot();
            _assertOwner(tokens, parties.seller);

            vm.startPrank(parties.seller);
            funcs[i](tokens, parties);
            vm.stopPrank();

            _assertOwner(tokens, parties.buyer);
            vm.revertTo(snap);
        }
    }

    function _transferBatch(ERC721TransferLib.MultiERC721Token[] memory tokens, Parties memory parties) internal {
        tokens._transfer(parties);
    }

    function _safeTransferBatch(ERC721TransferLib.MultiERC721Token[] memory tokens, Parties memory parties) internal {
        _safeTransferBatchWithData(tokens, parties, "");
    }

    /// @dev The `WithData` suffix avoids overloading so the functions can be placed in arrays for test suites.
    function _safeTransferBatchWithData(
        ERC721TransferLib.MultiERC721Token[] memory tokens,
        Parties memory parties,
        bytes memory data
    ) internal {
        tokens._safeTransfer(parties, data);
    }

    function _transferPerContract(ERC721TransferLib.MultiERC721Token[] memory tokens, Parties memory parties)
        internal
    {
        for (uint256 i = 0; i < tokens.length; ++i) {
            tokens[i]._transfer(parties);
        }
    }

    function _safeTransferPerContract(ERC721TransferLib.MultiERC721Token[] memory tokens, Parties memory parties)
        internal
    {
        _safeTransferPerContractWithData(tokens, parties, "");
    }

    function _safeTransferPerContractWithData(
        ERC721TransferLib.MultiERC721Token[] memory tokens,
        Parties memory parties,
        bytes memory data
    ) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            tokens[i]._safeTransfer(parties, data);
        }
    }

    function _transferIndividually(ERC721TransferLib.MultiERC721Token[] memory tokens, Parties memory parties)
        internal
    {
        for (uint256 i = 0; i < tokens.length; ++i) {
            for (uint256 j = 0; j < tokens[i].ids.length; ++j) {
                ERC721TransferLib.ERC721Token({addr: tokens[i].addr, id: tokens[i].ids[j]})._transfer(parties);
            }
        }
    }

    function _safeTransferIndividually(ERC721TransferLib.MultiERC721Token[] memory tokens, Parties memory parties)
        internal
    {
        _safeTransferIndividuallyWithData(tokens, parties, "");
    }

    function _safeTransferIndividuallyWithData(
        ERC721TransferLib.MultiERC721Token[] memory tokens,
        Parties memory parties,
        bytes memory data
    ) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            for (uint256 j = 0; j < tokens[i].ids.length; ++j) {
                ERC721TransferLib.ERC721Token({addr: tokens[i].addr, id: tokens[i].ids[j]})._safeTransfer(parties, data);
            }
        }
    }

    function testGas(
        bytes32[NUM_CONTRACTS] calldata deploySalts,
        uint256[TOKENS_PER_CONTRACT][NUM_CONTRACTS] calldata ids,
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
            tokens._transfer(parties);
            libGas -= gasleft();
        }

        // Gas saving per token was found empirically; it has no special meaning other than to demonstrate the saving
        // in this specific instance and may be a change-detector test.
        assertLe(libGas + 147 * NUM_CONTRACTS * TOKENS_PER_CONTRACT, naiveGas);
        console2.log(naiveGas - libGas);
    }

    mapping(bytes32 => bool) private _saltSeen;

    function _testSetup(
        bytes32[NUM_CONTRACTS] calldata deploySalts,
        uint256[TOKENS_PER_CONTRACT][NUM_CONTRACTS] calldata ids,
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
            tokens[i].ids = new uint256[](TOKENS_PER_CONTRACT);

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

    function testMultiERC721TokenTransferNothing(bytes32 tokenDeploySalt, Parties memory parties) public {
        ERC721TransferLib.MultiERC721Token[] memory tokens = new ERC721TransferLib.MultiERC721Token[](1);
        tokens[0].addr = new Token{salt: tokenDeploySalt}();
        tokens._transfer(parties);
    }

    function testSafeTransferDataPropagation(uint256 tokenId, address seller, bytes32 buyerSalt, bytes memory data)
        external
    {
        vm.assume(seller != address(0));

        ERC721Receiver buyer = new ERC721Receiver{salt: buyerSalt}();
        Parties memory parties = Parties({seller: seller, buyer: address(buyer)});

        Token t = new Token();
        t.mint(seller, tokenId);

        ERC721TransferLib.MultiERC721Token[] memory tokens = new ERC721TransferLib.MultiERC721Token[](1);
        tokens[0].addr = IERC721(t);
        tokens[0].ids = new uint256[](1);
        tokens[0].ids[0] = tokenId;

        function(ERC721TransferLib.MultiERC721Token[] memory, Parties memory, bytes memory)[3] memory funcs =
            [_safeTransferBatchWithData, _safeTransferPerContractWithData, _safeTransferIndividuallyWithData];

        for (uint256 i = 0; i < funcs.length; ++i) {
            uint256 snap = vm.snapshot();
            _assertOwner(tokens, parties.seller);
            assertEq(buyer.tokenData(tokenId), "", "safeTransfer() data recorder empty");

            vm.startPrank(parties.seller);
            funcs[i](tokens, parties, data);
            vm.stopPrank();

            _assertOwner(tokens, parties.buyer);
            assertEq(buyer.tokenData(tokenId), data, "safeTransfer() data propagated");
            vm.revertTo(snap);
        }
    }

    function testNoCodeAtTokenAddress(
        bytes32[NUM_CONTRACTS] calldata deploySalts,
        uint256[TOKENS_PER_CONTRACT][NUM_CONTRACTS] calldata ids,
        address emptyTokenContract,
        uint256 contractToEmpty,
        Parties memory parties
    ) public {
        vm.assume(emptyTokenContract.code.length == 0);

        ERC721TransferLib.MultiERC721Token[] memory tokens = _testSetup(deploySalts, ids, parties);

        // When using vm.expectRevert(), it expects the very next external call to be the one that reverts, but that
        // won't be the case when using an internal library function. We therefore have to have a proxy contract use the
        // library as a means of wrapping all transfers into a single (reverting) call.
        ERC721Transferrer proxy = new ERC721Transferrer();
        for (uint256 i = 0; i < tokens.length; ++i) {
            vm.prank(parties.seller);
            tokens[i].addr.setApprovalForAll(address(proxy), true);
        }

        // By only clearing the contract now, the approval loop above is much cleaner.
        tokens[bound(contractToEmpty, 0, tokens.length - 1)].addr = IERC721(emptyTokenContract);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferLib.NoCodeAtAddress.selector, emptyTokenContract));
        proxy.transfer(tokens, parties);
        vm.stopPrank();
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
        tokens._transfer(parties);
    }
}
