// SPDX-License-Identifier: MIT
// Copyright 2024 Divergence Tech Ltd.
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

/**
 * @notice Deployment script that confirms the current Foundry profile in setup.
 * @dev Useful for turning off features during development (e.g. slow `via_ir`) that MUST be enabled for deployment.
 */
contract DeploymentBase is Script {
    error NotDeployProfile(string);

    function setUp() public view virtual {
        string memory profile = vm.envString("FOUNDRY_PROFILE");
        if (keccak256(abi.encodePacked(profile)) != keccak256("deploy")) {
            revert NotDeployProfile(profile);
        }
    }
}
