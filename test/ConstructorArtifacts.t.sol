// SPDX-License-Identifier: MIT
// Copyright 2024 Divergence Tech Ltd.
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ConstructorArtifacts} from "../src/ConstructorArtifacts.sol";

interface Events {
    event ConstructorRun(uint256 nonce);
}

contract Empty is ConstructorArtifacts, Events {
    constructor(uint256 nonce) emptyContract {
        emit ConstructorRun(nonce);
    }
}

contract AlwaysStops is ConstructorArtifacts, Events {
    constructor(uint256 nonce) contractAlwaysStops {
        emit ConstructorRun(nonce);
    }
}

contract AlwaysReturnsEmpty is ConstructorArtifacts, Events {
    constructor(uint256 nonce) contractAlwaysReturnsEmpty {
        emit ConstructorRun(nonce);
    }
}

contract AlwaysRevertsEmpty is ConstructorArtifacts, Events {
    constructor(uint256 nonce) contractAlwaysRevertsEmpty {
        emit ConstructorRun(nonce);
    }
}

/// @dev For demonstrative purposes to compare gas savings.
contract WithoutModifier is Events {
    constructor(uint256 nonce) {
        emit ConstructorRun(nonce);
    }
}

contract ArtifactsTest is Test, Events {
    struct TestCase {
        // Deployment
        uint256 nonce; // demonstrates that the constructor works as expected
        bytes wantDeployedByteCode;
        // Calling the artifact
        address caller;
        uint256 value;
        bytes callData;
        bool wantCallSuccess;
        bytes wantReturnData;
    }

    function _test(function(uint256) returns (address) deploy, TestCase memory tc) internal {
        vm.assume(tc.caller.balance == 0);

        vm.expectEmit(true, true, true, true);
        emit ConstructorRun(tc.nonce);
        address addr = deploy(tc.nonce);
        vm.assume(addr != tc.caller); // bizarre fuzzing edge case!

        assertEq(addr.codehash, keccak256(abi.encodePacked(tc.wantDeployedByteCode)), "code hash of deployed contract");

        vm.deal(tc.caller, tc.value);
        vm.prank(tc.caller);
        (bool success, bytes memory ret) = addr.call{value: tc.value}(tc.callData);

        assertEq(success, tc.wantCallSuccess, "success of a call to the deployed contract");
        assertEq(keccak256(ret), keccak256(tc.wantReturnData), "returned data of a call to the deployed contract");

        assertEq(
            tc.caller.balance,
            tc.wantCallSuccess ? 0 : tc.value,
            "caller balance after attempt to send all to deployed contract"
        );
        assertEq(
            addr.balance,
            tc.wantCallSuccess ? tc.value : 0,
            "contract balance after caller's attempt to send entire balance"
        );
    }

    function _deployEmpty(uint256 nonce) internal returns (address) {
        return address(new Empty(nonce));
    }

    function testEmpty(TestCase memory tc) public {
        tc.wantDeployedByteCode = "";
        tc.wantCallSuccess = true;
        tc.wantReturnData = "";
        _test(_deployEmpty, tc);
    }

    function _deployAlwaysStops(uint256 nonce) internal returns (address) {
        return address(new AlwaysStops(nonce));
    }

    function testAlwaysStops(TestCase memory tc) public {
        tc.wantDeployedByteCode = hex"00";
        tc.wantCallSuccess = true;
        tc.wantReturnData = "";
        _test(_deployAlwaysStops, tc);
    }

    function _deployAlwaysReturnsEmpty(uint256 nonce) internal returns (address) {
        return address(new AlwaysReturnsEmpty(nonce));
    }

    function testAlwaysReturnsEmpty(TestCase memory tc) public {
        tc.wantDeployedByteCode = hex"5f5ff3";
        tc.wantCallSuccess = true;
        tc.wantReturnData = "";
        _test(_deployAlwaysReturnsEmpty, tc);
    }

    function _deployAlwaysRevertsEmpty(uint256 nonce) internal returns (address) {
        return address(new AlwaysRevertsEmpty(nonce));
    }

    function testAlwaysRevertsEmpty(TestCase memory tc) public {
        tc.wantDeployedByteCode = hex"5f5ffd";
        tc.wantCallSuccess = false;
        tc.wantReturnData = "";
        _test(_deployAlwaysRevertsEmpty, tc);
    }

    function testDemonstrateBytecodeReduction(uint256 nonce) public {
        uint256 nBytes = address(new WithoutModifier(nonce)).code.length;
        console2.log(nBytes);
        assertGt(nBytes, 3);
    }
}
