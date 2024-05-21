// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC721ForXTest} from "./ERC721ForXTest.t.sol";
import {SwapperTestBase, SwapperTestLib} from "./SwapperTestBase.t.sol";
import {ERC20Test} from "./ERC20Test.t.sol";

import {ERC721TransferLib, IERC721} from "../src/ERC721TransferLib.sol";
import {ERC721ForERC20Swap, IERC20} from "../src/ERC721ForERC20/ERC721ForERC20Swap.sol";
import {ERC721ForERC20SwapperDeployer} from "../src/ERC721ForERC20/ERC721ForERC20SwapperDeployer.gen.sol";
import {InsufficientBalance, Consideration, Disbursement, Parties} from "../src/TypesAndConstants.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/// @dev Couples an `ERC721ForXTest` with an `ERC20Test` to test swapping of an ERC721 for ERC20 tokens.
contract ERC721ForERC20Test is ERC721ForXTest, ERC20Test {
    using SwapperTestLib for TestCase;

    function setUp() public override(SwapperTestBase, ERC20Test) {
        SwapperTestBase.setUp();
        ERC20Test.setUp();
    }

    /**
     * @dev Constructs an `ERC721ForERC20Swap` from the test case, for use in implementing all virtual functions
     * defined by ERC721ForXTest.
     */
    function _asSwap(ERC721TestCase memory t) private view returns (ERC721ForERC20Swap memory) {
        return ERC721ForERC20Swap({
            parties: t.base.parties,
            offer: ERC721TransferLib.ERC721Token({addr: token, id: t.tokenId}),
            consideration: t.base.consideration(),
            currency: currency
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
    function _fillSelector() internal pure override returns (bytes4) {
        return ERC721ForERC20SwapperDeployer.fill.selector;
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

    function testSudoSwapGasCompare() public {
        if (block.chainid != 1 || block.number != 19448496) {
            return;
        }

        // https://etherscan.io/tx/0xdbc81a5a44db1bc2ff138cc9e4ce159adb811fed25e75c4aa8546318bdc0f79d

        uint256 tokenId = 100030075;

        ERC721ForERC20Swap memory swap = ERC721ForERC20Swap({
            parties: Parties({
                seller: 0xe7967e0ec15CB48939Fcf0BC5764c2a634349eCB,
                buyer: 0x6414258EE299B740C19a11B938AFe30A373d1AFd
            }),
            offer: ERC721TransferLib.ERC721Token({addr: IERC721(0x12F28E2106CE8Fd8464885B80EA865e98b465149), id: tokenId}),
            consideration: Consideration({thirdParty: new Disbursement[](0), maxPlatformFee: 0, total: 36000000000000000000}),
            currency: IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) // weth
        });

        assertEq(swap.offer.addr.ownerOf(tokenId), swap.parties.seller);
        assertGe(swap.currency.balanceOf(swap.parties.buyer), swap.consideration.total);

        uint256 sellerBalance = swap.currency.balanceOf(swap.parties.seller);
        uint256 gasUsed;
        uint256 sudoGasUsed;

        {
            uint256 snap = vm.snapshot();

            bytes32 salt = 0;
            address swapper = factory.swapper(swap, salt);

            vm.prank(swap.parties.seller);
            swap.offer.addr.setApprovalForAll(swapper, true);
            vm.prank(swap.parties.buyer);
            swap.currency.approve(swapper, type(uint256).max);

            vm.expectEmit(true, true, true, true, address(swap.offer.addr));
            emit Transfer(swap.parties.seller, swap.parties.buyer, tokenId);
            uint256 gas = gasleft();
            factory.fill(swap, salt);
            gasUsed = gas - gasleft();

            assertEq(swap.offer.addr.ownerOf(tokenId), swap.parties.buyer);
            assertEq(swap.currency.balanceOf(swap.parties.seller), sellerBalance + swap.consideration.total);

            vm.revertTo(snap);
        }

        {
            bytes memory originalCall =
                hex"b4be83d50000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000004c0000000000000000000000000e7967e0ec15cb48939fcf0bc5764c2a634349ecb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004e2f98c96e2d595a83afa35888c4af58ac343e44000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065fef6ec0000000000000000000000000000000000000000000000000000018e47e8071d00000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000014494cfcdd700000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000440257179200000000000000000000000012f28e2106ce8fd8464885b80ea865e98b4651490000000000000000000000000000000000000000000000000000000005f6567b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012494cfcdd7000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000001f399b1438a100000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000024f47261b0000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000421c6dba4c45cdc5831b45d6a7abb38dd983e868c78e44cf3da8231a134a1d1dfd5215e576be7869f620aa392cde9afb70cd8f9ec15338ec17b96efefe5c300190ad03000000000000000000000000000000000000000000000000000000000000";

            vm.expectEmit(true, true, true, true, address(swap.offer.addr));
            emit Transfer(swap.parties.seller, swap.parties.buyer, tokenId);
            vm.prank(swap.parties.buyer);
            uint256 gas = gasleft();
            (bool success,) = 0x080bf510FCbF18b91105470639e9561022937712.call(originalCall);
            sudoGasUsed = gas - gasleft();
            require(success, "original simulation failed");

            assertEq(swap.offer.addr.ownerOf(tokenId), swap.parties.buyer);
            assertEq(swap.currency.balanceOf(swap.parties.seller), sellerBalance + swap.consideration.total);
        }

        assertLt(gasUsed, sudoGasUsed, "gas usage");
        console2.log(gasUsed, sudoGasUsed, sudoGasUsed - gasUsed);
    }
}
