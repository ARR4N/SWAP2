// SPDX-License-Identifier: MIT
// Copyright 2024 Divergence Tech Ltd.
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ETDeployer, ET, Message} from "../src/ET.sol";

event MessageReceived(Message indexed);

Message constant REVERT_MSG = Message.wrap(keccak256("revert"));

contract TestableET is ET {
    error Reverted(address);

    constructor() {
        Message m = _phoneHome();
        if (m == REVERT_MSG) {
            revert Reverted(address(this));
        }
        emit MessageReceived(_phoneHome());
    }
}

contract TestableETDeployer is ETDeployer {
    function deploy(bytes32 salt, Message message) external returns (address) {
        return _deploy(type(TestableET).creationCode, salt, message);
    }

    function predict(bytes32 salt) external view returns (address) {
        return _predictDeploymentAddress(type(TestableET).creationCode, salt);
    }
}

contract ETTest is Test {
    TestableETDeployer deployer = new TestableETDeployer();

    function testPhoneHome(bytes32 salt, Message message) public {
        vm.assume(message != REVERT_MSG);

        address predicted = deployer.predict(salt);
        vm.label(predicted, "predicted");

        vm.expectEmit(true, true, true, true, predicted);
        emit MessageReceived(message);
        address et = deployer.deploy(salt, message);
        vm.label(et, "actual");

        assertEq(et, predicted);
    }

    function testRecreateRevert(bytes32 salt, Message message, Message[5] memory otherMsgs) public {
        vm.assume(message != REVERT_MSG);

        deployer.deploy(salt, message);
        _recreate(salt, message);

        for (uint256 i = 0; i < otherMsgs.length; ++i) {
            _recreate(salt, otherMsgs[i]);
        }
    }

    function _recreate(bytes32 salt, Message message) internal {
        vm.expectRevert(new bytes(0));
        deployer.deploy(salt, message);
    }

    function testArbitraryRevert(bytes32 salt) public {
        address predicted = deployer.predict(salt);

        vm.expectRevert(abi.encodeWithSelector(TestableET.Reverted.selector, predicted));
        deployer.deploy(salt, REVERT_MSG);
    }
}
