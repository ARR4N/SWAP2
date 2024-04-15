// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC721ForXTest} from "./ERC721ForXTest.t.sol";
import {SwapperTest, SwapperTestLib} from "./SwapperTest.t.sol";
import {ERC20Test} from "./ERC20Test.t.sol";

import {ERC721Token} from "../src/ERC721SwapperLib.sol";
import {ERC721ForERC20Swap as Swap, IERC20} from "../src/ERC721ForERC20/ERC721ForERC20Swap.sol";
import {InsufficientBalance, Disbursement, Parties} from "../src/TypesAndConstants.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract ERC721ForERC20Test is ERC721ForXTest, ERC20Test {
    using SwapperTestLib for TestCase;

    function setUp() public override (SwapperTest, ERC20Test)  {
        SwapperTest.setUp();
        ERC20Test.setUp();
    }

    function _swapper(ERC721TestCase memory t) internal view override returns (address) {
        return factory.swapper(_asSwap(t), t.common.salt);
    }

    function _fill(ERC721TestCase memory t) internal override {
        factory.fill(_asSwap(t), t.common.salt);
    }

    function _cancel(ERC721TestCase memory t) internal override {
        factory.cancel(_asSwap(t), t.common.salt);
    }

    function _replay(ERC721TestCase memory t, address replayer) internal override {
        vm.deal(t.common.buyer(), t.common.total());
        vm.startPrank(replayer);
        _fill(t);
        vm.stopPrank();
    }

    function _asSwap(ERC721TestCase memory t) internal view returns (Swap memory) {
        return Swap({
            parties: t.common.parties,
            consideration: t.common.consideration(),
            token: ERC721Token({addr: token, id: t.tokenId}),
            currency: currency
        });
    }
}
