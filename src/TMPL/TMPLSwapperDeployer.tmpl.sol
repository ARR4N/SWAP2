// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
/**
 * GENERATED CODE - DO NOT EDIT
 */

import {TMPLSwap} from "./TMPLSwap.sol";
import {TMPLSwapper} from "./TMPLSwapper.sol";

import {ETDeployer, ETPredictor} from "../ET.sol";
import {ISwapperEvents, OnlyBuyerCanCancel, FILL, CANCEL} from "../TypesAndConstants.sol";

/// @dev Predictor of TMPLSwapper contract addresses.
contract TMPLSwapperPredictor is ETPredictor {
    function _swapper(TMPLSwap memory swap, bytes32 salt) internal view returns (address) {
        return _predictDeploymentAddress(_bytecode(swap), salt);
    }

    function _bytecode(TMPLSwap memory swap) internal pure returns (bytes memory) {
        return abi.encodePacked(type(TMPLSwapper).creationCode, abi.encode(swap));
    }
}

/// @dev Deployer of TMPLSwapper contracts.
contract TMPLSwapperDeployer is TMPLSwapperPredictor, ETDeployer, ISwapperEvents {
    function fill(TMPLSwap memory swap, bytes32 salt) external payable returns (address) {
        address a = _deploy(_bytecode(swap), msg.value, salt, FILL);
        emit Filled(a);
        return a;
    }

    function cancel(TMPLSwap memory swap, bytes32 salt) external returns (address) {
        if (msg.sender != swap.parties.buyer) {
            revert OnlyBuyerCanCancel();
        }
        address a = _deploy(_bytecode(swap), 0, salt, CANCEL);
        emit Cancelled(a);
        return a;
    }

    function swapper(TMPLSwap memory swap, bytes32 salt) external view returns (address payable) {
        return payable(_swapper(swap, salt));
    }
}

/**
 * @dev Compile-time guarantee that the TMPLSwapper constructor has the signature assumed by _bytecode().
 * @dev Always reverts and MUST NOT be used.
 */
function _enforceTMPLSwapperCtorSig() {
    assert(false);
    TMPLSwap memory s;
    new TMPLSwapper(s);
}
