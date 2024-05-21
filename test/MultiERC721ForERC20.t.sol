// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC721ForXTest} from "./ERC721ForXTest.t.sol";
import {SwapperTestBase, SwapperTestLib} from "./SwapperTestBase.t.sol";
import {ERC20Test} from "./ERC20Test.t.sol";

import {ERC721TransferLib, IERC721} from "../src/ERC721TransferLib.sol";
import {MultiERC721ForERC20Swap, IERC20} from "../src/MultiERC721ForERC20/MultiERC721ForERC20Swap.sol";
import {MultiERC721ForERC20SwapperDeployer} from "../src/MultiERC721ForERC20/MultiERC721ForERC20SwapperDeployer.gen.sol";
import {InsufficientBalance, Consideration, Disbursement, Parties} from "../src/TypesAndConstants.sol";

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
        ERC721TransferLib.MultiERC721Token[] memory offer = new ERC721TransferLib.MultiERC721Token[](1);
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
    function _propose(ERC721TestCase memory t) internal override returns (bytes32 salt, address swapper) {
        return factory.propose(_asSwap(t));
    }

    /// @inheritdoc ERC721ForXTest
    function _encodedSwapAndSalt(ERC721TestCase memory t, bytes32 salt) internal view override returns (bytes memory) {
        return abi.encode(_asSwap(t), salt);
    }

    /// @inheritdoc ERC721ForXTest
    function _fillSelector() internal pure override returns (bytes4) {
        return MultiERC721ForERC20SwapperDeployer.fill.selector;
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
        if (block.chainid != 1 || block.number != 19524904) {
            return;
        }

        // https://etherscan.io/tx/0xe2caa083588dd7ba90f7d740813731aebc8c1146353e4d6be90574d8ca7ed189

        ERC721TransferLib.MultiERC721Token[] memory offer = new ERC721TransferLib.MultiERC721Token[](2);

        offer[0].addr = IERC721(0x99a9B7c1116f9ceEB1652de04d5969CcE509B069);
        offer[0].ids = new uint256[](4);
        offer[0].ids[0] = 395000045;
        offer[0].ids[1] = 395000284;
        offer[0].ids[2] = 389000114;
        offer[0].ids[3] = 389000018;

        offer[1].addr = IERC721(0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270);
        offer[1].ids = new uint256[](1);
        offer[1].ids[0] = 367000414;

        MultiERC721ForERC20Swap memory swap = MultiERC721ForERC20Swap({
            parties: Parties({
                seller: 0xe6291213d431d1DA9921456Aab3901fA91CD0f14,
                buyer: 0x9Af2FE7C4275D5A7a10e01C6FBF04eA9B8A99A4e
            }),
            offer: offer,
            consideration: Consideration({thirdParty: new Disbursement[](0), maxPlatformFee: 0, total: 8500000000000000000}),
            currency: IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) // weth
        });

        assertGe(swap.currency.balanceOf(swap.parties.buyer), swap.consideration.total);

        uint256 sellerBalance = swap.currency.balanceOf(swap.parties.seller);
        uint256 gasUsed;
        uint256 sudoGasUsed;

        {
            uint256 snap = vm.snapshot();

            bytes32 salt = 0;
            address swapper = factory.swapper(swap, salt);

            vm.startPrank(swap.parties.seller);
            for (uint256 i = 0; i < swap.offer.length; ++i) {
                swap.offer[i].addr.setApprovalForAll(swapper, true);
            }
            vm.stopPrank();
            vm.prank(swap.parties.buyer);
            swap.currency.approve(swapper, type(uint256).max);

            uint256 gas = gasleft();
            factory.fill(swap, salt);
            gasUsed = gas - gasleft();

            assertEq(swap.currency.balanceOf(swap.parties.seller), sellerBalance + swap.consideration.total);

            vm.revertTo(snap);
        }

        {
            bytes memory originalCall =
                hex"b4be83d50000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000007c0000000000000000000000000e6291213d431d1da9921456aab3901fa91cd0f1400000000000000000000000000000000000000000000000000000000000000000000000000000000000000004e2f98c96e2d595a83afa35888c4af58ac343e440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000660d235f0000000000000000000000000000000000000000000000000000018e7f45a7ce00000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044494cfcdd700000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000002a000000000000000000000000000000000000000000000000000000000000000440257179200000000000000000000000099a9b7c1116f9ceeb1652de04d5969cce509b06900000000000000000000000000000000000000000000000000000000178b38ed0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000440257179200000000000000000000000099a9b7c1116f9ceeb1652de04d5969cce509b06900000000000000000000000000000000000000000000000000000000178b39dc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000440257179200000000000000000000000099a9b7c1116f9ceeb1652de04d5969cce509b06900000000000000000000000000000000000000000000000000000000172fabb20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000440257179200000000000000000000000099a9b7c1116f9ceeb1652de04d5969cce509b06900000000000000000000000000000000000000000000000000000000172fab5200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004402571792000000000000000000000000a7d8d9ef8d8ce8992df33d8b8cf4aebabd5bd2700000000000000000000000000000000000000000000000000000000015dffb5e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012494cfcdd700000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000075f610f70ed20000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000024f47261b0000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000421bcd55947ddbbbb3810e4e4724391b3a54b69ce5fa1c52f6c2e848eb9fab8671dd2648c9ad6bc9bfc057b968ffdb725f37462e3475691d1f20cec722ead1cc6afa02000000000000000000000000000000000000000000000000000000000000";

            vm.prank(swap.parties.buyer);
            uint256 gas = gasleft();
            (bool success,) = 0x080bf510FCbF18b91105470639e9561022937712.call(originalCall);
            sudoGasUsed = gas - gasleft();
            require(success, "original simulation failed");

            assertEq(swap.currency.balanceOf(swap.parties.seller), sellerBalance + swap.consideration.total);
        }

        assertLt(gasUsed, sudoGasUsed, "gas usage");
        console2.log(gasUsed, sudoGasUsed, sudoGasUsed - gasUsed);
    }
}
