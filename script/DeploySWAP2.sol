// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DeploymentBase} from "./DeploymentBase.sol";
import {SWAP2} from "../src/SWAP2.sol";
import {Escrow} from "../src/Escrow.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

contract DeploySWAP2 is DeploymentBase {
    address constant DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    address constant BROADCASTER = 0x174787a207BF4eD4D8db0945602e49f42c146474;
    address payable constant OWNER = payable(0xD8b8A1d6aDda1B16D2B5117492232119682C8B2D);
    address payable constant FEE_RECIPIENT = OWNER;
    uint16 constant FEE_BASIS_POINTS = 150;

    bytes32 constant ESCROW_SALT = 0xa2873fb836a61514a7212bacc15c0ad7f691f4f77e4b3af3d91905f821c3f087;
    bytes32 constant SWAP2_SALT = 0x0803cb05dd8c01f1049143cf9c4c817e4b167f1d1b83e5c6f0f10d89ba1e7bce;

    event InitCodeHashes(bytes32 indexed escrow, bytes32 indexed swap2);

    function run() public {
        Predictions memory predictions = predictAddresses();
        emit InitCodeHashes(predictions.escrowHash, predictions.swap2Hash);

        vm.startBroadcast(BROADCASTER);

        Escrow escrow =
            predictions.escrow.code.length == 0 ? new Escrow{salt: ESCROW_SALT}() : Escrow(predictions.escrow);
        assert(address(escrow) == predictions.escrow);

        SWAP2 swap2 = predictions.swap2.code.length == 0
            ? new SWAP2{salt: SWAP2_SALT}(OWNER, Escrow(predictions.escrow), FEE_RECIPIENT, FEE_BASIS_POINTS)
            : SWAP2(predictions.swap2);
        assert(address(swap2) == predictions.swap2);

        vm.stopBroadcast();

        assert(address(swap2.escrow()) == predictions.escrow);
        assert(swap2.owner() == OWNER);
        (address feeRecipient, uint16 basisPoints) = swap2.feeConfig();
        assert(feeRecipient == FEE_RECIPIENT);
        assert(basisPoints == FEE_BASIS_POINTS);
    }

    struct Predictions {
        bytes32 escrowHash;
        address escrow;
        bytes32 swap2Hash;
        address swap2;
    }

    function predictAddresses() public pure returns (Predictions memory) {
        Predictions memory pred;
        pred.escrowHash = keccak256(type(Escrow).creationCode);
        pred.escrow = Create2.computeAddress(ESCROW_SALT, pred.escrowHash, DEPLOYER);

        pred.swap2Hash = keccak256(
            abi.encodePacked(type(SWAP2).creationCode, abi.encode(OWNER, pred.escrow, FEE_RECIPIENT, FEE_BASIS_POINTS))
        );

        pred.swap2 = Create2.computeAddress(SWAP2_SALT, pred.swap2Hash, DEPLOYER);
        return pred;
    }
}
