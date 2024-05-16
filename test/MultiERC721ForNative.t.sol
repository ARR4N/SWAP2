// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC721ForXTest} from "./ERC721ForXTest.t.sol";
import {SwapperTestLib} from "./SwapperTestBase.t.sol";
import {NativeTokenTest} from "./NativeTokenTest.t.sol";

import {MultiERC721Token} from "../src/ERC721SwapperLib.sol";
import {MultiERC721ForNativeSwap} from "../src/MultiERC721ForNative/MultiERC721ForNativeSwap.sol";
import {InsufficientBalance, Disbursement, Parties} from "../src/TypesAndConstants.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/**
 * @dev Couples an `ERC721ForXTest` with a `NativeTokenTest` to test swapping of an ERC721 for ERC20 tokens, but using
 * the MultiERC721 swapper.
 */
contract MultiERC721ForNativeTest is ERC721ForXTest, NativeTokenTest {
    using SwapperTestLib for TestCase;

    /**
     * @dev Constructs an `MultiERC721ForNativeSwap` from the test case, for use in implementing all virtual functions
     * defined by ERC721ForXTest.
     */
    function _asSwap(ERC721TestCase memory t) private view returns (MultiERC721ForNativeSwap memory) {
        MultiERC721Token[] memory offer = new MultiERC721Token[](1);
        offer[0].addr = token;
        offer[0].ids = new uint256[](1);
        offer[0].ids[0] = t.tokenId;

        return MultiERC721ForNativeSwap({
            parties: _asPayableParties(t.base.parties),
            offer: offer,
            consideration: t.base.consideration()
        });
    }

    /// @inheritdoc ERC721ForXTest
    function _swapper(ERC721TestCase memory t) internal view override returns (address) {
        return factory.swapper(_asSwap(t), t.base.salt);
    }

    /// @inheritdoc ERC721ForXTest
    function _propose(ERC721TestCase memory t) internal override returns (bytes32 salt, address swapper) {
        return factory.propose(_asSwap(t));
    }

    /// @inheritdoc ERC721ForXTest
    function _encodedSwapAndSalt(ERC721TestCase memory t, bytes32 salt) internal view override returns (bytes memory) {
        return abi.encode(_asSwap(t), salt);
    }

    /// @inheritdoc ERC721ForXTest
    function _fill(ERC721TestCase memory t) internal override {
        _fill(t, t.base.native.callValue);
    }

    function _fill(ERC721TestCase memory t, uint256 callValue) internal {
        factory.fill{value: callValue}(_asSwap(t), t.base.salt);
    }

    /// @inheritdoc ERC721ForXTest
    function _cancel(ERC721TestCase memory t) internal override {
        factory.cancel(_asSwap(t), t.base.salt);
    }

    /// @inheritdoc ERC721ForXTest
    function _replay(ERC721TestCase memory t, address replayer) internal override {
        vm.deal(replayer, t.base.total());
        vm.startPrank(replayer);
        _fill(t, t.base.total());
        vm.stopPrank();
    }
}
