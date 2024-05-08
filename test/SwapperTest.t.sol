// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SWAP2} from "../src/SWAP2.sol";
import {Parties, PayableParties, Consideration, Disbursement, ISwapperEvents} from "../src/TypesAndConstants.sol";

import {ERC721, IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Token is ERC721 {
    constructor() ERC721("", "") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

interface ITestEvents is ISwapperEvents {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokeinId);
}

abstract contract SwapperTest is Test, ITestEvents {
    using SwapperTestLib for TestCase;

    SWAP2 public factory;
    Token public token;

    function setUp() public virtual {
        factory = new SWAP2();
        vm.label(address(factory), "SWAP2");
        token = new Token();
        vm.label(address(token), "FakeERC721");
    }

    enum Approval {
        None,
        Approve,
        ApproveForAll
    }

    struct NativePayments {
        uint128 prePay;
        uint128 callValue;
        uint128 postPay;
    }

    struct ERC20Payments {
        uint256 buyerBalance;
        uint256 swapperAllowance;
    }

    struct TestCase {
        // Swap particulars
        Parties parties;
        // Consideration, limited in the number of third-party recipients to stop the fuzzer going overboard.
        // Use SwapperTestLib.consideration() to access:
        uint256 _numThirdParty; // overidden by assumeValidTest() so sum(_thirdParty) < total
        Disbursement[5] _thirdParty;
        uint256 _totalConsideration;
        // Pre-execution config
        uint8 _approval; // use SwapperTestLib.approval() to access
        // Tx execution
        address caller;
        bytes32 salt;
        // NativePayments; only one will be necessary for the specific test.
        NativePayments native;
        ERC20Payments erc20;
    }

    function _balance(address) internal view virtual returns (uint256);

    function _deal(address, uint256 newBalance) internal virtual;

    function _beforeExecute(TestCase memory, address swapper) internal virtual;

    function _afterExecute(TestCase memory, address swapper, bool executed) internal virtual;

    function _expectedSellerBalanceAfterFill(TestCase memory) internal view virtual returns (uint256);

    function _swapperPrePay(TestCase memory) internal view virtual returns (uint256);

    function _paymentsValid(TestCase memory) internal view virtual returns (bool);

    modifier assumeValidPayments(TestCase memory t) {
        vm.assume(_paymentsValid(t));
        _;
    }

    function _totalPaying(TestCase memory) internal view virtual returns (uint256);

    function _sufficientPayment(TestCase memory t) internal view returns (bool) {
        return _totalPaying(t) >= t.total();
    }

    function _insufficientBalanceError(TestCase memory) internal view virtual returns (bytes memory);

    modifier assumeSufficientPayment(TestCase memory t) {
        vm.assume(_sufficientPayment(t));
        _;
    }

    modifier assumeInsufficientPayment(TestCase memory t) {
        vm.assume(!_sufficientPayment(t));
        _;
    }

    modifier assumeValidTest(TestCase memory t) {
        vm.assume(t.seller() != t.buyer());
        _assumeNonContractWithoutBalance(t.seller());
        _assumeNonContractWithoutBalance(t.buyer());
        _assumeNonContractWithoutBalance(t.caller);

        vm.label(t.seller(), "seller");
        vm.label(t.buyer(), "buyer");
        if (t.caller == t.seller()) {
            vm.label(t.caller, "seller (swap executor)");
        } else if (t.caller == t.buyer()) {
            vm.label(t.caller, "buyer (swap executor)");
        } else {
            vm.label(t.caller, "swap-executor");
        }

        {
            t._numThirdParty = 0;
            uint256 remaining = t._totalConsideration;

            Disbursement[5] memory disburse = t._thirdParty;
            for (uint256 i = 0; i < disburse.length; ++i) {
                uint256 amt = disburse[i].amount;
                if (amt > remaining) {
                    break;
                }
                remaining -= amt;

                address to = disburse[i].to;
                vm.assume(to != t.seller() && to != t.buyer());
                _assumeNonContractWithoutBalance(to);

                uint256 addr = uint256(uint160(to));
                bool seen;
                assembly ("memory-safe") {
                    seen := tload(addr)
                }
                vm.assume(!seen);
                assembly ("memory-safe") {
                    tstore(addr, 1)
                }

                ++t._numThirdParty;
            }
        }

        _;

        for (uint256 i = 0; i < t._thirdParty.length; ++i) {
            uint256 addr = uint256(uint160(t._thirdParty[i].to));
            assembly ("memory-safe") {
                tstore(addr, 0)
            }
        }
    }

    function _assumeNonContractWithoutBalance(address a) internal view {
        vm.assume(uint160(a) > 0x0a);
        vm.assume(a.code.length == 0);
        vm.assume(a.balance == 0);
    }

    modifier assumeApproving(TestCase memory t) {
        vm.assume(t.approval() != Approval.None);
        _;
    }

    modifier inVMSnapshot() {
        uint256 snap = vm.snapshot();
        _;
        vm.revertTo(snap);
    }

    function _approveSwapper(TestCase memory t, uint256 tokenId, address swapper) internal {
        Approval a = t.approval();

        vm.startPrank(t.seller());
        if (a == Approval.Approve) {
            token.approve(swapper, tokenId);
        } else if (a == Approval.ApproveForAll) {
            token.setApprovalForAll(swapper, true);
        }
        vm.stopPrank();
    }
}

library SwapperTestLib {
    using SwapperTestLib for SwapperTest.TestCase;

    function approval(SwapperTest.TestCase memory t) internal pure returns (SwapperTest.Approval) {
        return SwapperTest.Approval(t._approval % uint8(type(SwapperTest.Approval).max));
    }

    function seller(SwapperTest.TestCase memory t) internal pure returns (address) {
        return t.parties.seller;
    }

    function buyer(SwapperTest.TestCase memory t) internal pure returns (address) {
        return t.parties.buyer;
    }

    function total(SwapperTest.TestCase memory t) internal pure returns (uint256) {
        return t._totalConsideration;
    }

    function totalForSeller(SwapperTest.TestCase memory t) internal pure returns (uint256) {
        return t.total() - t.totalForThirdParties();
    }

    function totalForThirdParties(SwapperTest.TestCase memory t) internal pure returns (uint256) {
        Consideration memory c = t.consideration();
        uint256 sum;
        for (uint256 i = 0; i < c.thirdParty.length; ++i) {
            sum += c.thirdParty[i].amount;
        }
        return sum;
    }

    function consideration(SwapperTest.TestCase memory t) internal pure returns (Consideration memory) {
        uint256 n = t._numThirdParty;
        Consideration memory c = Consideration({thirdParty: new Disbursement[](n), total: t._totalConsideration});
        for (uint256 i = 0; i < n; ++i) {
            c.thirdParty[i] = t._thirdParty[i];
        }
        return c;
    }
}
