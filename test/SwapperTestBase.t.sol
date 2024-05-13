// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SWAP2} from "../src/SWAP2.sol";
import {Parties, PayableParties, Consideration, Disbursement, ISwapperEvents} from "../src/TypesAndConstants.sol";

import {ERC721, IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract Token is ERC721 {
    constructor() ERC721("", "") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

interface ITestEvents is ISwapperEvents {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokeinId);
}

contract TestableSWAP2 is SWAP2 {
    function setPlatformFee(address payable recipient, uint16 basisPoints) external {
        feeConfig.recipient = recipient;
        feeConfig.basisPoints = basisPoints;
    }
}

/**
 * @dev SwapperTestBase is the abstract base of all other tests. It defines:
 *   - A common TestCase struct, useful for fuzzing.
 *   - A set of (virtual) functions that non-abstract test contracts can expect to be present; these are mostly
 *     implemented by NativeTokenTest and ERC20Test.
 *   - Modifiers for test*() functions, implementing common assumptions.
 * @dev Notably, SwapperTestBase doesn't implement any actual tests.
 */
abstract contract SwapperTestBase is Test, ITestEvents {
    using SwapperTestLib for TestCase;

    SWAP2 public factory;
    TestableSWAP2 public mutableFactory;
    Token public token;

    function setUp() public virtual {
        mutableFactory = new TestableSWAP2();
        factory = mutableFactory;
        vm.label(address(factory), "SWAP2");
        token = new Token();
        vm.label(address(token), "FakeERC721");
    }

    /// @dev Whether to use approve(), setApprovalForAll(), or no approval on ERC721 tokens.
    enum Approval {
        None,
        Approve,
        ApproveForAll
    }

    /// @dev Payment parameters when using native-token consideration.
    struct NativePayments {
        uint128 prePay; // Sent beforehand to the predicted swapper address.
        uint128 callValue; // Value sent during the call to fill().
        uint128 postPay; // Sent to the swapper address after execution and MUST be rejected if execution succeeded.
    }

    /// @dev Payment parameters when using ERC20 consideration.
    struct ERC20Payments {
        uint256 buyerBalance;
        uint256 swapperAllowance;
    }

    /**
     * @dev A set of fuzzable parameters, common to all tests.
     * @dev Underscore-prefixed fields MUST NOT be accessed directly; use SwapperTestLib functions instead.
     */
    struct TestCase {
        // Swap particulars
        Parties parties;
        // Fees
        address payable platformFeeRecipient;
        uint16 platformFeeBasisPoints;
        // Consideration, limited in the number of third-party recipients to stop the fuzzer going overboard.
        // Use SwapperTestLib.consideration() to access:
        uint256 _numThirdParty; // overidden by assumeValidTest() so sum(_thirdParty) < total
        Disbursement[5] _thirdParty;
        uint256 _totalConsideration;
        uint256 _maxPlatformFee;
        // Pre-execution config
        uint8 _approval; // use SwapperTestLib.approval() to access as an Approval enum.
        // Tx execution
        address caller;
        bytes32 salt;
        // Payments; only one will be necessary for the specific test.
        NativePayments native;
        ERC20Payments erc20;
    }

    /// @dev Sets the platform-fee config to the parameters provided in the test case.
    function _setPlatformFee(TestCase memory t) internal {
        mutableFactory.setPlatformFee(t.platformFeeRecipient, t.platformFeeBasisPoints);
    }

    /// @dev Returns the balance of the address, denominated in the payment currency (native or specific ERC20).
    function _balance(address) internal view virtual returns (uint256);

    /// @dev Sets the account's balance, similarly to vm.deal(), which SHOULD be used when appropriate.
    function _deal(address account, uint256 newBalance) internal virtual;

    /// @dev Called before a call to fill() or cancel().
    function _beforeExecute(TestCase memory, address swapper) internal virtual;

    /// @dev Called after a call to fill() or cancel(). MUST be tagged with inVMSnapshot modifier if modifiying state.
    function _afterExecute(TestCase memory, address swapper, bool executed) internal virtual;

    /**
     * @dev Returns the total consideration the seller is expected to receive, beyond the total consideration, after a
     * successful call to fill().
     * @dev Although in production this will be `Consideration.total` minus the sum of third-party disbursements, in
     * fuzzed tests for native-token consideration the pre-payment + call-value may exceed this value.
     */
    function _expectedExcessSellerBalanceAfterFill(TestCase memory) internal view virtual returns (uint256);

    /// @dev Returns the amount to pre-pay the predicted swapper address. Only valid for native-token consideration.
    function _swapperPrePay(TestCase memory) internal view virtual returns (uint256);

    /// @dev Returns whether the NativePayments or ERC20Payments struct (as appropriate) is valid.
    function _paymentsValid(TestCase memory) internal view virtual returns (bool);

    /// @dev Calls vm.assume() with the return value of _paymentsValid().
    modifier assumePaymentsValid(TestCase memory t) {
        vm.assume(_paymentsValid(t));
        _;
    }

    /**
     * @dev Returns the payment amount made available to the swapper contract to use as consideration. When paying with
     * native token, this is the balance of the swapper at execution. When paying with ERC20, this is the minimum of the
     * buyer's balance and the amount for which the swapper is approved.
     */
    function _paymentTendered(TestCase memory) internal view virtual returns (uint256);

    /// @dev Returns whether sufficient payment is being issued to cover the total consideration.
    function _sufficientPayment(TestCase memory t) internal view returns (bool) {
        return _paymentTendered(t) >= t.total();
    }

    /// @dev Calls vm.assume() with the return value of _sufficientPayment().
    modifier assumeSufficientPayment(TestCase memory t) {
        vm.assume(_sufficientPayment(t));
        _;
    }

    /// @dev Calls vm.assume() with the negation of the return value of _sufficientPayment().
    modifier assumeInsufficientPayment(TestCase memory t) {
        vm.assume(!_sufficientPayment(t));
        _;
    }

    modifier assumeValidPlatformFee(TestCase memory t) {
        vm.assume(t.platformFee() <= t._maxPlatformFee);
        _;
    }

    modifier assumeExcessPlatformFee(TestCase memory t) {
        vm.assume(t.platformFee() > t._maxPlatformFee);
        _;
    }

    /// @dev Returns the expected error when insufficient payment is being issued to cover the total consideration.
    function _insufficientBalanceError(TestCase memory) internal view virtual returns (bytes memory);

    /**
     * @dev Confirms a series of assumptions about the TestCase that make it valid (i.e. plausible).
     * @dev Additionally prunes third-party disbursements such that (a) they don't exceed total consideration, and (b)
     * the recipients are distinct.
     */
    modifier assumeValidTest(TestCase memory t) {
        {
            vm.assume(t.seller() != t.buyer());
            _assumeNonContractWithoutBalance(t.seller());
            _assumeNonContractWithoutBalance(t.buyer());
            _assumeNonContractWithoutBalance(t.caller);
            _assumeNonContractWithoutBalance(t.platformFeeRecipient);

            vm.label(t.seller(), "seller");
            vm.label(t.buyer(), "buyer");
            if (t.caller == t.seller()) {
                vm.label(t.caller, "seller (swap executor)");
            } else if (t.caller == t.buyer()) {
                vm.label(t.caller, "buyer (swap executor)");
            } else {
                vm.label(t.caller, "swap-executor");
            }

            address rec = t.platformFeeRecipient;
            vm.assume(rec != t.seller() && rec != t.buyer());
            vm.label(t.platformFeeRecipient, "platform-fee-recipient");
        }

        {
            vm.assume(t._totalConsideration >= t._maxPlatformFee);
            vm.assume(t.platformFeeBasisPoints <= 10_000);
            uint256 remaining = t._totalConsideration - t._maxPlatformFee;

            t._numThirdParty = 0;

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

    /// @dev Assumes that the address is not a contract (nor pre-compile) and has zero balance.
    function _assumeNonContractWithoutBalance(address a) internal view {
        vm.assume(uint160(a) > 0x0a);
        vm.assume(a.code.length == 0);
        vm.assume(a.balance == 0);
    }

    /// @dev Assumes that either approve() or setApprovalForAll() will be called by _approveSwapper().
    modifier assumeApproving(TestCase memory t) {
        vm.assume(t.approval() != Approval.None);
        _;
    }

    /// @dev Assumes that neither approve() nor setApprovalForAll() will be called by _approveSwapper().
    modifier assumeNotApproving(TestCase memory t) {
        vm.assume(t.approval() == Approval.None);
        _;
    }

    /**
     * @dev Calls the respective approval function, as dictated by t.approval(), with the `swapper` as the operator.
     * @dev If t.approval() returns `Approval.None` then _approveSwapper() is a no-op.
     */
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

    /// @dev Runs the function in a vm.snapshot(), reverting at the end.
    modifier inVMSnapshot() {
        uint256 snap = vm.snapshot();
        _;
        vm.revertTo(snap);
    }
}

/**
 * @dev Library of getters for reading SwapperTestBase.TestCase struct fields that aren't directly accessible (i.e. are
 * underscore-prefixed) or require syntactic sugar for convenience.
 */
library SwapperTestLib {
    using SwapperTestLib for SwapperTestBase.TestCase;

    /// @dev Returns `t._approval` as an `Approval` enum.
    function approval(SwapperTestBase.TestCase memory t) internal pure returns (SwapperTestBase.Approval) {
        return SwapperTestBase.Approval(t._approval % uint8(type(SwapperTestBase.Approval).max));
    }

    /// @dev Returns the `seller` address.
    function seller(SwapperTestBase.TestCase memory t) internal pure returns (address) {
        return t.parties.seller;
    }

    /// @dev Returns the `buyer` address.
    function buyer(SwapperTestBase.TestCase memory t) internal pure returns (address) {
        return t.parties.buyer;
    }

    /**
     * @dev Returns the test case's `Consideration` struct.
     * @dev If only the total is required, use total() instead.
     */
    function consideration(SwapperTestBase.TestCase memory t) internal pure returns (Consideration memory) {
        uint256 n = t._numThirdParty;
        Consideration memory c = Consideration({
            thirdParty: new Disbursement[](n),
            maxPlatformFee: t._maxPlatformFee,
            total: t._totalConsideration
        });
        for (uint256 i = 0; i < n; ++i) {
            c.thirdParty[i] = t._thirdParty[i];
        }
        return c;
    }

    /// @dev Returns total consideration, mirroring the value in the struct returned by consideration().
    function total(SwapperTestBase.TestCase memory t) internal pure returns (uint256) {
        return t._totalConsideration;
    }

    /// @dev Returns the sum of all third-party disbursements.
    function totalForThirdParties(SwapperTestBase.TestCase memory t) internal pure returns (uint256) {
        Consideration memory c = t.consideration();
        uint256 sum;
        for (uint256 i = 0; i < c.thirdParty.length; ++i) {
            sum += c.thirdParty[i].amount;
        }
        return sum;
    }

    /// @dev Returns the platform fee required to fill the swap defined by the test case.
    function platformFee(SwapperTestBase.TestCase memory t) internal pure returns (uint256) {
        return Math.mulDiv(t.total(), t.platformFeeBasisPoints, 10_000);
    }

    /// @dev Returns the total consideration remaining for the seller after deducting all third-party disbursements.
    function totalForSeller(SwapperTestBase.TestCase memory t) internal pure returns (uint256) {
        return t.total() - t.totalForThirdParties() - t.platformFee();
    }
}