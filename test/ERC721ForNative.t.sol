// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC721ForXTest} from "./ERC721ForXTest.t.sol";
import {SwapperTestLib} from "./SwapperTest.t.sol";
import {NativeTokenTest} from "./NativeTokenTest.t.sol";

import {ERC721Token} from "../src/ERC721SwapperLib.sol";
import {ERC721ForNativeSwap as Swap} from "../src/ERC721ForNative/ERC721ForNativeSwap.sol";
import {InsufficientBalance, Disbursement, Parties} from "../src/TypesAndConstants.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract ERC721ForNativeTest is ERC721ForXTest, NativeTokenTest {
    using SwapperTestLib for TestCase;

    function _swapper(ERC721TestCase memory t) internal view override returns (address) {
        return factory.swapper(_asSwap(t), t.common.salt);
    }

    function _fill(ERC721TestCase memory t) internal override {
        _fill(t, t.common.native.callValue);
    }

    function _fill(ERC721TestCase memory t, uint256 callValue) internal {
        factory.fill{value: callValue}(_asSwap(t), t.common.salt);
    }

    function _cancel(ERC721TestCase memory t) internal override {
        factory.cancel(_asSwap(t), t.common.salt);
    }

    function _replay(ERC721TestCase memory t, address replayer) internal override {
        vm.deal(replayer, t.common.total());
        vm.startPrank(replayer);
        _fill(t, t.common.total());
        vm.stopPrank();
    }

    function _asSwap(ERC721TestCase memory t) internal view returns (Swap memory) {
        return Swap({
            parties: _asPayableParties(t.common.parties),
            consideration: t.common.consideration(),
            token: ERC721Token({addr: token, id: t.tokenId})
        });
    }
}
