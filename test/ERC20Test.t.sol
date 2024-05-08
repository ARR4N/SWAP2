// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SwapperTest, SwapperTestLib} from "./SwapperTest.t.sol";
import {Consideration, Parties, PayableParties} from "../src/TypesAndConstants.sol";

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Currency is ERC20 {
    error InsufficientBalance(address);

    constructor() ERC20("", "") {}

    function deal(address to, uint256 amount) external {
        _burn(to, balanceOf(to));
        _mint(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (balanceOf(from) < amount) {
            // The default error contains data that we don't have access to during the test.
            revert InsufficientBalance(from);
        }
        return ERC20.transferFrom(from, to, amount);
    }
}

abstract contract ERC20Test is SwapperTest {
    using SwapperTestLib for TestCase;

    Currency public currency;

    function setUp() public virtual override {
        currency = new Currency();
        vm.label(address(currency), "currency");
    }

    function _balance(address a) internal view override returns (uint256) {
        return currency.balanceOf(a);
    }

    function _deal(address a, uint256 newBalance) internal override {
        currency.deal(a, newBalance);
    }

    function _beforeExecute(TestCase memory t, address swapper) internal override {
        _deal(t.buyer(), t.erc20.buyerBalance);
        vm.prank(t.buyer());
        currency.approve(swapper, t.erc20.swapperAllowance);
    }

    function _afterExecute(TestCase memory t, address swapper, bool executed) internal override {}

    function _expectedSellerBalanceAfterFill(TestCase memory t) internal pure override returns (uint256) {
        return t.totalForSeller();
    }

    function _swapperPrePay(TestCase memory) internal pure override returns (uint256) {
        return 0; // only relevant for native payments
    }

    function _paymentsValid(TestCase memory t) internal pure override returns (bool) {
        return t.erc20.swapperAllowance >= t.erc20.buyerBalance;
    }

    function _totalPaying(TestCase memory t) internal pure override returns (uint256) {
        return _min(t.total(), _min(t.erc20.buyerBalance, t.erc20.swapperAllowance));
    }

    function _insufficientBalanceError(TestCase memory t) internal pure override returns (bytes memory) {
        return abi.encodeWithSelector(Currency.InsufficientBalance.selector, t.buyer());
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
