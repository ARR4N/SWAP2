// SPDX-License-Identifier: UNLICENSED
// Copyright 2024 Divergence Tech Ltd.
pragma solidity 0.8.25;

import {
    ERC721ForNativeSwapperDeployer,
    ERC721ForNativeSwapperProposer
} from "./ERC721ForNative/ERC721ForNativeSwapperDeployer.gen.sol";
import {
    ERC721ForERC20SwapperDeployer,
    ERC721ForERC20SwapperProposer
} from "./ERC721ForERC20/ERC721ForERC20SwapperDeployer.gen.sol";
import {
    MultiERC721ForNativeSwapperDeployer,
    MultiERC721ForNativeSwapperProposer
} from "./MultiERC721ForNative/MultiERC721ForNativeSwapperDeployer.gen.sol";
import {
    MultiERC721ForERC20SwapperDeployer,
    MultiERC721ForERC20SwapperProposer
} from "./MultiERC721ForERC20/MultiERC721ForERC20SwapperDeployer.gen.sol";

import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract SWAP2Deployer is
    Ownable2Step,
    ERC721ForNativeSwapperDeployer,
    ERC721ForERC20SwapperDeployer,
    MultiERC721ForNativeSwapperDeployer,
    MultiERC721ForERC20SwapperDeployer
{
    /**
     * @param initialOwner Initial owner of the contract. SHOULD be a multisig as this address can modify platform-fee
     * configuration.
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @dev Packs platform-fee configuration into a single word.
    struct PlatformFeeConfig {
        address payable recipient;
        uint16 basisPoints;
    }

    /// @notice Platform-fee configuration.
    PlatformFeeConfig public feeConfig;

    /**
     * @notice Sets the platform fee and recipient.
     * @dev Evert <T>Swap struct includes a maximum fee, above which the swap will revert, making it impossible for this
     * function to front-run a swap unless it's in favour of the parties. In the event of a fee increase, the UI SHOULD
     * warn users and begin computing swapper addresses at the higher maximum fee.
     * @param recipient Address to which platform fees are sent.
     * @param basisPoints One-hundredths of a percentage point of swap consideration to charge as a platform fee.
     */
    function setPlatformFee(address payable recipient, uint16 basisPoints) external onlyOwner {
        feeConfig = PlatformFeeConfig({recipient: recipient, basisPoints: basisPoints});
    }

    /**
     * @dev Implements virtual function required by all <T>Deployers.
     * @return Most recent values passed to `setPlatformFee()`.
     */
    function _platformFeeConfig() internal view override returns (address payable, uint16) {
        PlatformFeeConfig memory config = feeConfig;
        return (config.recipient, config.basisPoints);
    }
}

abstract contract SWAP2ProposerBase is
    ERC721ForNativeSwapperProposer,
    ERC721ForERC20SwapperProposer,
    MultiERC721ForNativeSwapperProposer,
    MultiERC721ForERC20SwapperProposer
{}

/// @notice A standalone SWAP2 proposer for an immutable deployer address.
contract SWAP2Proposer is SWAP2ProposerBase {
    /// @notice The SWAP2Deployer for which this contract proposes swaps.
    address public immutable deployer;

    /// @param deployer_ Address of the SWAP2Deployer for which this contract proposes swaps.
    constructor(address deployer_) {
        deployer = deployer_;
    }

    /// @dev The immutable `deployer` is the swapper deployer for all types.
    function _swapperDeployer() internal view override returns (address) {
        return deployer;
    }
}

/// @notice A combined SWAP2{Deployer,Proposer}.
contract SWAP2 is SWAP2Deployer, SWAP2ProposerBase {
    constructor(address initialOwner) SWAP2Deployer(initialOwner) {}

    /// @dev The current contract is the swapper deployer for all types.
    function _swapperDeployer() internal view override returns (address) {
        return address(this);
    }
}
