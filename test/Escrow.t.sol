// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Escrow, IEscrowEvents} from "../src/Escrow.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract ReentryWithdrawer {
    Escrow private immutable _escrow;
    bool private _reenter;

    constructor(Escrow escrow) {
        _escrow = escrow;
    }

    receive() external payable {
        if (_reenter) {
            _escrow.withdraw();
        }
    }

    function withdraw() external {
        _escrow.withdraw();
    }

    function reenter(bool b) external {
        _reenter = b;
    }
}

contract EscrowTest is Test, IEscrowEvents {
    Escrow escrow = new Escrow();

    struct Beneficiary {
        address payable addr;
        uint248[10] amounts;
        bool withdrawEarly;
        bool withdrawAsBeneficiary;
    }

    mapping(address => bool) addressSeen;

    function testDepositAndWithdraw(address depositor, address withdrawer, Beneficiary[10] memory bs) public {
        vm.assume(address(escrow).balance == 0);
        vm.assume(depositor != address(0));
        vm.deal(depositor, type(uint256).max);

        uint256[] memory totals = new uint256[](bs.length);

        for (uint256 i = 0; i < bs.length; ++i) {
            address payable addr = bs[i].addr;
            vm.assume(!addressSeen[addr]);
            addressSeen[addr] = true;

            _assumeNonContractWithZeroBalance(addr);

            uint248[10] memory amounts = bs[i].amounts;

            for (uint256 j = 0; j < amounts.length; ++j) {
                vm.expectEmit(true, true, true, true, address(escrow));
                emit Deposit(addr, amounts[j]);
                vm.prank(depositor);
                escrow.deposit{value: amounts[j]}(addr);

                totals[i] += amounts[j];
                assertEq(escrow.balance(addr), totals[i], "balance after single deposit");
            }

            if (!bs[i].withdrawEarly) {
                continue;
            }

            _withdraw(withdrawer, bs[i], totals[i]);
            totals[i] = 0;
        }

        for (uint256 i = 0; i < bs.length; ++i) {
            address payable addr = bs[i].addr;
            assertEq(escrow.balance(addr), totals[i], "balance after all deposits for all beneficiaries");

            _withdraw(withdrawer, bs[i], totals[i]);
        }

        assertEq(address(escrow).balance, 0, "escrow contract emptied");
    }

    function _assumeNonContractWithZeroBalance(address addr) internal view {
        vm.assume(addr > address(0xa));
        vm.assume(addr.balance == 0);
        vm.assume(addr.code.length == 0);
    }

    function _withdraw(address withdrawer, Beneficiary memory b, uint256 expectedTotal) internal {
        if (expectedTotal == 0) {
            vm.expectRevert(abi.encodeWithSelector(Escrow.ZeroBalance.selector, b.addr));
        } else {
            vm.expectEmit(true, true, true, true, address(escrow));
            emit Withdrawal(b.addr, expectedTotal);
        }

        if (b.withdrawAsBeneficiary) {
            vm.prank(b.addr);
            escrow.withdraw();
        } else {
            vm.prank(withdrawer);
            escrow.withdraw(b.addr);
        }
        assertEq(escrow.balance(b.addr), 0, "zero balance after withdrawal");
    }

    function testDepositSum(address payable beneficiary, uint8 init, uint8 doublings) public {
        // Although this test isn't strictly necessary, the other one is tautological when it comes to checking the
        // property that withdrawal == sum(deposits).

        _assumeNonContractWithZeroBalance(beneficiary);
        vm.assume(init > 0);
        vm.assume(doublings < 248);

        vm.deal(address(this), type(uint256).max);

        escrow.deposit{value: init}(beneficiary);
        for (uint8 i = 0; i < doublings; ++i) {
            escrow.deposit{value: escrow.balance(beneficiary)}(beneficiary);
        }

        uint256 total = uint256(init) << doublings;
        vm.expectEmit(true, true, true, true, address(escrow));
        emit Withdrawal(beneficiary, total);
        escrow.withdraw(beneficiary);
    }

    function testNonReentrant(uint256 amount, bytes32 salt) public {
        vm.assume(amount > 0);

        ReentryWithdrawer thief = new ReentryWithdrawer{salt: salt}(escrow);
        address payable addr = payable(thief);
        vm.assume(addr.balance == 0);

        vm.deal(address(this), amount);
        escrow.deposit{value: amount}(addr);

        thief.reenter(true);
        vm.expectRevert(Address.FailedInnerCall.selector);
        thief.withdraw();

        // The OpenZeppelin failure mode hides the underlying cause by not propagating the revert error. The closest we
        // can get to proving the source is by repeating the identical action and showing that it no longer reverts.
        thief.reenter(false);
        thief.withdraw();
        assertEq(addr.balance, amount, "withdraw() succeeds when no longer reentering");
    }
}
