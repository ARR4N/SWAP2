// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Escrow} from "../src/Escrow.sol";
import {SWAP2} from "../src/SWAP2.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract OwnerTest is Test {
    function testTransferOwnership(address initial, address newOwner) public {
        // This doesn't need to be a comprehensive test, only a demonstration that we've correctly inherited from OZ.
        vm.assume(initial != address(0));
        vm.assume(newOwner != address(0));

        SWAP2 s = new SWAP2(initial, new Escrow(), payable(address(1)), 0);

        vm.prank(initial);
        s.transferOwnership(newOwner);

        assertEq(s.owner(), initial, "initial owner still owns");

        vm.prank(newOwner);
        s.acceptOwnership();

        assertEq(s.owner(), newOwner, "new owner accepted");
    }

    function testPlatformFeeConfigOnlyOwner(address owner, address vandal, SWAP2.PlatformFeeConfig memory config)
        public
    {
        vm.assume(owner != address(0));
        vm.assume(owner != vandal);

        SWAP2 s = new SWAP2(owner, new Escrow(), payable(address(1)), 0);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, vandal));
        vm.prank(vandal);
        s.setPlatformFee(config.recipient, config.basisPoints);
    }
}
