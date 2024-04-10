// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC721ForNativeSwapperDeployer} from "./ERC721ForNative/ERC721ForNativeSwapperDeployer.gen.sol";
import {ERC721ForERC20SwapperDeployer} from "./ERC721ForERC20/ERC721ForERC20SwapperDeployer.gen.sol";

contract SWAP2 is ERC721ForNativeSwapperDeployer, ERC721ForERC20SwapperDeployer {}
