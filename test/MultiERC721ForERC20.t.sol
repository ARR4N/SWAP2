// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC721ForXTest} from "./ERC721ForXTest.t.sol";
import {SwapperTestBase, SwapperTestLib} from "./SwapperTestBase.t.sol";
import {ERC20Test} from "./ERC20Test.t.sol";

import {MultiERC721Token} from "../src/ERC721SwapperLib.sol";
import {MultiERC721ForERC20Swap, IERC20} from "../src/MultiERC721ForERC20/MultiERC721ForERC20Swap.sol";
import {InsufficientBalance, Disbursement, Parties} from "../src/TypesAndConstants.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/**
 * @dev Couples an `ERC721ForXTest` with an `ERC20Test` to test swapping of an ERC721 for ERC20 tokens, but using the
 * MultiERC721 swapper.
 */
contract MultiERC721ForERC20Test is ERC721ForXTest, ERC20Test {
    using SwapperTestLib for TestCase;

    function setUp() public override(SwapperTestBase, ERC20Test) {
        SwapperTestBase.setUp();
        ERC20Test.setUp();
    }

    /**
     * @dev Constructs an `MultiERC721ForERC20Swap` from the test case, for use in implementing all virtual functions
     * defined by ERC721ForXTest.
     */
    function _asSwap(ERC721TestCase memory t) private view returns (MultiERC721ForERC20Swap memory) {
        MultiERC721Token[] memory offer = new MultiERC721Token[](1);
        offer[0].addr = token;
        offer[0].ids = new uint256[](1);
        offer[0].ids[0] = t.tokenId;

        return MultiERC721ForERC20Swap({
            parties: t.base.parties,
            offer: offer,
            consideration: t.base.consideration(),
            currency: currency
        });
    }

    /// @inheritdoc ERC721ForXTest
    function _swapper(ERC721TestCase memory t) internal view override returns (address) {
        return factory.swapper(_asSwap(t), t.base.salt);
    }

    /// @inheritdoc ERC721ForXTest
    function _broadcast(ERC721TestCase memory t) internal override returns (bytes32 salt, address swapper) {
        return factory.broadcast(_asSwap(t));
    }

    /// @inheritdoc ERC721ForXTest
    function _encodedSaltAndSwap(ERC721TestCase memory t) internal view override returns (bytes memory) {
        return abi.encode(t.base.salt, _asSwap(t));
    }

    /// @inheritdoc ERC721ForXTest
    function _fill(ERC721TestCase memory t) internal override {
        factory.fill(_asSwap(t), t.base.salt);
    }

    /// @inheritdoc ERC721ForXTest
    function _cancel(ERC721TestCase memory t) internal override {
        factory.cancel(_asSwap(t), t.base.salt);
    }

    /// @inheritdoc ERC721ForXTest
    function _replay(ERC721TestCase memory t, address replayer) internal override {
        vm.deal(t.base.buyer(), t.base.total());
        vm.startPrank(replayer);
        _fill(t);
        vm.stopPrank();
    }
}
