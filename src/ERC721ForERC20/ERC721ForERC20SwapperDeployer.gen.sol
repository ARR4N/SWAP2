// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
/**
 * GENERATED CODE - DO NOT EDIT
 */

import {ERC721ForERC20Swap} from "./ERC721ForERC20Swap.sol";
import {ERC721ForERC20Swapper} from "./ERC721ForERC20Swapper.sol";

import {ETDeployer, ETPredictor} from "../ET.sol";
import {ISwapperEvents, OnlyBuyerCanCancel, FILL, CANCEL} from "../TypesAndConstants.sol";

/// @dev Predictor of ERC721ForERC20Swapper contract addresses.
contract ERC721ForERC20SwapperPredictor is ETPredictor {
    function _swapper(ERC721ForERC20Swap memory swap, bytes32 salt) internal view returns (address) {
        return _predictDeploymentAddress(_bytecode(swap), salt);
    }

    function _bytecode(ERC721ForERC20Swap memory swap) internal pure returns (bytes memory) {
        return abi.encodePacked(type(ERC721ForERC20Swapper).creationCode, abi.encode(swap));
    }
}

/// @dev Deployer of ERC721ForERC20Swapper contracts.
contract ERC721ForERC20SwapperDeployer is ERC721ForERC20SwapperPredictor, ETDeployer, ISwapperEvents {
    function fill(ERC721ForERC20Swap memory swap, bytes32 salt) external payable returns (address) {
        address a = _deploy(_swapper(swap, salt), _bytecode(swap), msg.value, salt, FILL);
        emit Filled(a);
        return a;
    }

    function cancel(ERC721ForERC20Swap memory swap, bytes32 salt) external returns (address) {
        if (msg.sender != swap.parties.buyer) {
            revert OnlyBuyerCanCancel();
        }
        address a = _deploy(_swapper(swap, salt), _bytecode(swap), 0, salt, CANCEL);
        emit Cancelled(a);
        return a;
    }

    function swapper(ERC721ForERC20Swap memory swap, bytes32 salt) external view returns (address payable) {
        return payable(_swapper(swap, salt));
    }
}

/**
 * @dev Compile-time guarantee that the ERC721ForERC20Swapper constructor has the signature assumed by _bytecode().
 * @dev Always reverts and MUST NOT be used.
 */
function _enforceERC721ForERC20SwapperCtorSig() {
    assert(false);
    ERC721ForERC20Swap memory s;
    new ERC721ForERC20Swapper(s);
}
