// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC721ForNativeSwapperDeployer} from "./ERC721ForNative/ERC721ForNativeSwapperDeployer.gen.sol";
import {ERC721ForERC20SwapperDeployer} from "./ERC721ForERC20/ERC721ForERC20SwapperDeployer.gen.sol";
import {MultiERC721ForNativeSwapperDeployer} from "./MultiERC721ForNative/MultiERC721ForNativeSwapperDeployer.gen.sol";
import {MultiERC721ForERC20SwapperDeployer} from "./MultiERC721ForERC20/MultiERC721ForERC20SwapperDeployer.gen.sol";

import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract SWAP2 is
    Ownable2Step,
    ERC721ForNativeSwapperDeployer,
    ERC721ForERC20SwapperDeployer,
    MultiERC721ForNativeSwapperDeployer,
    MultiERC721ForERC20SwapperDeployer
{
    constructor(address initialOwner) Ownable(initialOwner) {}

    struct PlatformFeeConfig {
        address payable recipient;
        uint16 basisPoints;
    }

    PlatformFeeConfig public feeConfig;

    function setPlatformFee(address payable recipient, uint16 basisPoints) external onlyOwner {
        feeConfig = PlatformFeeConfig({recipient: recipient, basisPoints: basisPoints});
    }

    function _platformFeeConfig() internal view override returns (address payable, uint16) {
        PlatformFeeConfig memory config = feeConfig;
        return (config.recipient, config.basisPoints);
    }
}
