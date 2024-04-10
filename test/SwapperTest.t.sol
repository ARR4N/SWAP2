// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SWAP2} from "../src/SWAP2.sol";
import {Parties, Consideration, Disbursement} from "../src/TypesAndConstants.sol";

import {ERC721, IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Token is ERC721 {
    constructor() ERC721("", "") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

library SwapperTestLib {
    using SwapperTestLib for SwapperTest.CommonTestCase;

    function approval(SwapperTest.CommonTestCase memory t) internal pure returns (SwapperTest.Approval) {
        return SwapperTest.Approval(t._approval % uint8(type(SwapperTest.Approval).max));
    }

    function seller(SwapperTest.CommonTestCase memory t) internal pure returns (address) {
        return t.parties.seller;
    }

    function buyer(SwapperTest.CommonTestCase memory t) internal pure returns (address) {
        return t.parties.buyer;
    }

    function total(SwapperTest.CommonTestCase memory t) internal pure returns (uint256) {
        return t.consideration.total;
    }

    function totalForSeller(SwapperTest.CommonTestCase memory t) internal pure returns (uint256) {
        return t.total() - t.totalForThirdParties();
    }

    function totalForThirdParties(SwapperTest.CommonTestCase memory t) internal pure returns (uint256) {
        uint256 sum;
        for (uint256 i = 0; i < t.consideration.thirdParty.length; ++i) {
            sum += t.consideration.thirdParty[i].amount;
        }
        return sum;
    }
}

abstract contract SwapperTest is Test {
    using SwapperTestLib for CommonTestCase;

    SWAP2 public factory;
    Token public token;

    function setUp() public virtual {
        factory = new SWAP2();
        vm.label(address(factory), "SWAP2");
        token = new Token();
        vm.label(address(token), "ERC721");
    }

    enum Approval {
        None,
        Approve,
        ApproveForAll
    }

    struct CommonTestCase {
        // Swap particulars
        Parties parties;
        Consideration consideration;
        bytes32 salt;
        // Pre-execution config
        uint8 _approval; // use SwapperTestLib.approval() to access
        // Tx execution
        address caller;
    }

    modifier assumeValidTest(CommonTestCase memory t) {
        vm.assume(address(factory).balance == 0);
        vm.assume(t.caller != address(factory));
        vm.assume(t.caller.balance == 0);

        vm.assume(t.seller() != t.buyer());
        _assumeNonContractWithoutBalance(t.seller());
        _assumeNonContractWithoutBalance(t.buyer());
        _assumeNonContractWithoutBalance(t.caller);

        vm.label(t.seller(), "seller");
        vm.label(t.buyer(), "buyer");
        vm.label(t.caller, "swap-executor");

        {
            Disbursement[] memory orig = t.consideration.thirdParty;

            uint256 n;
            uint256 remaining = t.consideration.total;

            for (uint256 i = 0; i < orig.length; ++i) {
                uint256 amt = orig[i].amount;
                if (amt > remaining) {
                    break;
                }
                remaining -= amt;

                address to = orig[i].to;
                vm.assume(to != t.seller() && to != t.buyer());

                ++n;
            }

            t.consideration.thirdParty = new Disbursement[](n);
            for (uint256 i = 0; i < n; ++i) {
                t.consideration.thirdParty[i] = orig[i];
            }
        }

        _;
    }

    function _assumeNonContractWithoutBalance(address a) internal view {
        vm.assume(uint160(a) > 0x0a);
        vm.assume(a.code.length == 0);
        vm.assume(a.balance == 0);
    }

    modifier assumeApproving(CommonTestCase memory t) {
        vm.assume(t.approval() != Approval.None);
        _;
    }

    modifier inVMSnapshot() {
        uint256 snap = vm.snapshot();
        _;
        vm.revertTo(snap);
    }

    function _approveSwapper(CommonTestCase memory t, uint256 tokenId, address swapper) internal {
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
