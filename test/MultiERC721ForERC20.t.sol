// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC721ForXTest} from "./ERC721ForXTest.t.sol";
import {SwapperTestBase, SwapperTestLib} from "./SwapperTestBase.t.sol";
import {ERC20Test} from "./ERC20Test.t.sol";

import {ERC721TransferLib} from "../src/ERC721TransferLib.sol";
import {MultiERC721ForERC20Swap} from "../src/MultiERC721ForERC20/MultiERC721ForERC20Swap.sol";
import {
    MultiERC721ForERC20SwapperDeployer,
    IMultiERC721ForERC20SwapperProposerEvents
} from "../src/MultiERC721ForERC20/MultiERC721ForERC20SwapperDeployer.gen.sol";
import {InsufficientBalance, Parties} from "../src/TypesAndConstants.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/**
 * @dev Couples an `ERC721ForXTest` with an `ERC20Test` to test swapping of an ERC721 for ERC20 tokens, but using the
 * MultiERC721 swapper.
 */
contract MultiERC721ForERC20Test is IMultiERC721ForERC20SwapperProposerEvents, ERC721ForXTest, ERC20Test {
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
        ERC721TransferLib.MultiERC721Token[] memory offer = new ERC721TransferLib.MultiERC721Token[](1);
        offer[0].addr = token;
        offer[0].ids = new uint256[](1);
        offer[0].ids[0] = t.tokenId;

        return MultiERC721ForERC20Swap({
            parties: t.base.parties,
            offer: offer,
            consideration: t.base.erc20Consideration(currency),
            validUntilTime: t.base.validUntilTime
        });
    }

    /// @inheritdoc ERC721ForXTest
    function _swapper(ERC721TestCase memory t) internal view override returns (address) {
        return factory.swapperOfMultiERC721ForERC20(_asSwap(t), t.base.salt);
    }

    /// @inheritdoc ERC721ForXTest
    function _propose(ERC721TestCase memory t) internal override returns (bytes32 salt, address swapper) {
        return factory.proposeMultiERC721ForERC20(_asSwap(t));
    }

    /// @inheritdoc ERC721ForXTest
    function _encodedSwapAndSalt(ERC721TestCase memory t, bytes32 salt) internal view override returns (bytes memory) {
        return abi.encode(_asSwap(t), salt);
    }

    /// @inheritdoc ERC721ForXTest
    function _fillSelector() internal pure override returns (bytes4) {
        return MultiERC721ForERC20SwapperDeployer.fillMultiERC721ForERC20.selector;
    }

    /// @inheritdoc ERC721ForXTest
    function _cancelSelector() internal pure override returns (bytes4) {
        return MultiERC721ForERC20SwapperDeployer.cancelMultiERC721ForERC20.selector;
    }

    /// @inheritdoc ERC721ForXTest
    function _proposalEventTopic() internal pure override returns (bytes32) {
        return MultiERC721ForERC20Proposal.selector;
    }

    /// @inheritdoc ERC721ForXTest
    function _fill(ERC721TestCase memory t) internal override {
        factory.fillMultiERC721ForERC20(_asSwap(t), t.base.salt);
    }

    /// @inheritdoc ERC721ForXTest
    function _cancel(ERC721TestCase memory t) internal override {
        factory.cancelMultiERC721ForERC20(_asSwap(t), t.base.salt);
    }

    /// @inheritdoc ERC721ForXTest
    function _replay(ERC721TestCase memory t, address replayer) internal override {
        vm.deal(t.base.buyer(), t.base.total());
        vm.startPrank(replayer);
        _fill(t);
        vm.stopPrank();
    }
}
