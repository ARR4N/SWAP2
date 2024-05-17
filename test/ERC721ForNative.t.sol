// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC721ForXTest} from "./ERC721ForXTest.t.sol";
import {SwapperTestLib} from "./SwapperTestBase.t.sol";
import {NativeTokenTest} from "./NativeTokenTest.t.sol";

import {ERC721Token, IERC721} from "../src/ERC721SwapperLib.sol";
import {ERC721ForNativeSwap} from "../src/ERC721ForNative/ERC721ForNativeSwap.sol";
import {InsufficientBalance, Consideration, Disbursement, PayableParties} from "../src/TypesAndConstants.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/// @dev Couples an `ERC721ForXTest` with a `NativeTokenTest` to test swapping of an ERC721 for native token.
contract ERC721ForNativeTest is ERC721ForXTest, NativeTokenTest {
    using SwapperTestLib for TestCase;

    /**
     * @dev Constructs an `ERC721ForNativeSwap` from the test case, for use in implementing all virtual functions
     * defined by ERC721ForXTest.
     */
    function _asSwap(ERC721TestCase memory t) private view returns (ERC721ForNativeSwap memory) {
        return ERC721ForNativeSwap({
            parties: _asPayableParties(t.base.parties),
            offer: ERC721Token({addr: token, id: t.tokenId}),
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

    function testSeaportGasCompare() public {
        if (block.chainid != 1 || block.number != 19888952) {
            return;
        }

        // https://etherscan.io/tx/0x0e8d587764350a81de48148430899e738666d942f25896d5851ef2d217e84d33

        uint256 tokenId = 17300;
        uint256 consideration = 2.55 ether;
        _setPlatformFee(0x0000a26b00c1F0DF003000390027140000fAa719, 250); // same recipient as Seaport

        ERC721ForNativeSwap memory swap = ERC721ForNativeSwap({
            parties: PayableParties({
                seller: payable(0xb29f8DDD1ADe87EE93E7CC7497d4e65Db46b8A20),
                buyer: payable(0x999a44114408Cf52e75244054b8533649CFcAc69)
            }),
            offer: ERC721Token({addr: IERC721(0x60E4d786628Fea6478F785A6d7e704777c86a7c6), id: tokenId}),
            consideration: Consideration({
                thirdParty: new Disbursement[](0),
                maxPlatformFee: consideration / 40,
                total: consideration
            })
        });

        assertEq(swap.offer.addr.ownerOf(tokenId), swap.parties.seller);
        assertGe(swap.parties.buyer.balance, swap.consideration.total);

        uint256 sellerBalance = swap.parties.seller.balance;
        uint256 gasUsed;
        uint256 seaportGasUsed;

        {
            uint256 snap = vm.snapshot();

            bytes32 salt = keccak256("pepper");
            address swapper = factory.swapper(swap, salt);

            vm.prank(swap.parties.seller);
            swap.offer.addr.setApprovalForAll(swapper, true);

            vm.expectEmit(true, true, true, true, address(swap.offer.addr));
            emit Transfer(swap.parties.seller, swap.parties.buyer, tokenId);
            vm.startPrank(swap.parties.buyer);
            uint256 gas = gasleft();
            factory.fill{value: consideration}(swap, salt);
            gasUsed = gas - gasleft();
            vm.stopPrank();

            assertEq(swap.offer.addr.ownerOf(tokenId), swap.parties.buyer);
            assertEq(swap.parties.seller.balance, sellerBalance + (2.55 ether * 9750) / 10_000);

            vm.revertTo(snap);
        }

        {
            bytes memory originalCall =
                hex"000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002280ef33c8d0a000000000000000000000000000b29f8ddd1ade87ee93e7cc7497d4e65db46b8a20000000000000000000000000004c00500000ad104d7dbd00e3ae0a5c00560c0000000000000000000000000060e4d786628fea6478f785a6d7e704777c86a7c6000000000000000000000000000000000000000000000000000000000000439400000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006646f7c7000000000000000000000000000000000000000000000000000000006665d15d0000000000000000000000000000000000000000000000000000000000000000360c6ebe00000000000000000000000000000000000000005f2cafec3135fabb0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f00000000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f00000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000024000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000e27c49886e60000000000000000000000000000000a26b00c1f0df003000390027140000faa7190000000000000000000000000000000000000000000000000000000000000040fd26990e977a1a7f7d1712e10f18170a4c040c27e4389543e407c0c246c0120b5814671480c0d5406c2f527d5ffd84416a62f21efd121bfca69d8f4a9f7c0ed700000000360c6ebe";

            vm.expectEmit(true, true, true, true, address(swap.offer.addr));
            emit Transfer(swap.parties.seller, swap.parties.buyer, tokenId);
            vm.prank(swap.parties.buyer);
            uint256 gas = gasleft();
            (bool success,) = 0x0000000000000068F116a894984e2DB1123eB395.call{value: consideration}(originalCall);
            seaportGasUsed = gas - gasleft();
            require(success, "original simulation failed");

            assertEq(swap.offer.addr.ownerOf(tokenId), swap.parties.buyer);
            assertEq(swap.parties.seller.balance, sellerBalance + (2.55 ether * 9750) / 10_000);
        }

        assertLt(gasUsed, seaportGasUsed, "gas usage");
        console2.log(gasUsed, seaportGasUsed, seaportGasUsed - gasUsed);
    }
}
