// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
/**
 * GENERATED CODE - DO NOT EDIT
 */

import {ERC721ForNativeSwap} from "./ERC721ForNativeSwap.sol";
import {ERC721ForNativeSwapper} from "./ERC721ForNativeSwapper.sol";

import {ETDeployer, ETPredictor} from "../ET.sol";
import {ISwapperEvents, OnlyBuyerCanCancel, FILL, CANCEL} from "../TypesAndConstants.sol";

/// @dev Predictor of ERC721ForNativeSwapper contract addresses.
contract ERC721ForNativeSwapperPredictor is ETPredictor {
    function _swapper(ERC721ForNativeSwap memory swap, bytes32 salt) internal view returns (address) {
        return _predictDeploymentAddress(_bytecode(swap), salt);
    }

    function _bytecode(ERC721ForNativeSwap memory swap) internal pure returns (bytes memory) {
        return abi.encodePacked(type(ERC721ForNativeSwapper).creationCode, abi.encode(swap));
    }
}

/// @dev Deployer of ERC721ForNativeSwapper contracts.
contract ERC721ForNativeSwapperDeployer is ERC721ForNativeSwapperPredictor, ETDeployer, ISwapperEvents {
    function fill(ERC721ForNativeSwap memory swap, bytes32 salt) external payable returns (address) {
        address a = _deploy(_swapper(swap, salt), _bytecode(swap), msg.value, salt, FILL);
        emit Filled(a);
        return a;
    }

    function cancel(ERC721ForNativeSwap memory swap, bytes32 salt) external returns (address) {
        if (msg.sender != swap.parties.buyer) {
            revert OnlyBuyerCanCancel();
        }
        address a = _deploy(_swapper(swap, salt), _bytecode(swap), 0, salt, CANCEL);
        emit Cancelled(a);
        return a;
    }

    function swapper(ERC721ForNativeSwap memory swap, bytes32 salt) external view returns (address payable) {
        return payable(_swapper(swap, salt));
    }
}

/**
 * @dev Compile-time guarantee that the ERC721ForNativeSwapper constructor has the signature assumed by _bytecode().
 * @dev Always reverts and MUST NOT be used.
 */
function _enforceERC721ForNativeSwapperCtorSig() {
    assert(false);
    ERC721ForNativeSwap memory s;
    new ERC721ForNativeSwapper(s);
}
