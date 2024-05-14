// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC721ForNativeSwapperDeployer} from "./ERC721ForNative/ERC721ForNativeSwapperDeployer.gen.sol";
import {ERC721ForERC20SwapperDeployer} from "./ERC721ForERC20/ERC721ForERC20SwapperDeployer.gen.sol";
import {MultiERC721ForNativeSwapperDeployer} from "./MultiERC721ForNative/MultiERC721ForNativeSwapperDeployer.gen.sol";
import {MultiERC721ForERC20SwapperDeployer} from "./MultiERC721ForERC20/MultiERC721ForERC20SwapperDeployer.gen.sol";

contract SWAP2 is
    ERC721ForNativeSwapperDeployer,
    ERC721ForERC20SwapperDeployer,
    MultiERC721ForNativeSwapperDeployer,
    MultiERC721ForERC20SwapperDeployer
{
    struct PlatformFeeConfig {
        address payable recipient;
        uint16 basisPoints;
    }

    PlatformFeeConfig public feeConfig;

    function _platformFeeConfig() internal view override returns (address payable, uint16) {
        PlatformFeeConfig memory config = feeConfig;
        return (config.recipient, config.basisPoints);
    }
}
