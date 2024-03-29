// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IPerpBuybackPool } from "./interface/IPerpBuybackPool.sol";
import { AggregatorV2V3Interface } from "@chainlink/contracts/src/v0.6/interfaces/AggregatorV2V3Interface.sol";
import { PerpBuybackPoolStorage } from "./storage/PerpBuybackPoolStorage.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

contract PerpBuybackPool is IPerpBuybackPool, Ownable2StepUpgradeable, PerpBuybackPoolStorage {
    using AddressUpgradeable for address;

    // https://docs.chain.link/data-feeds/price-feeds/addresses?network=optimism#Optimism%20Mainnet
    uint256 public constant PERP_PRICE_FEED_HEARTBEAT = 86400;

    //
    // EXTERNAL NON-VIEW
    //

    function initialize(address usdcArg, address perpArg, address perpChainlinkAggregatorArg) external initializer {
        // PBP_UINC: usdc is not contract
        require(usdcArg.isContract(), "PBP_UINC");
        // PBP_PINC: perp is not contract
        require(perpArg.isContract(), "PBP_PINC");
        // PBP_PCAINC: perpChainlinkAggregator is not contract
        require(perpChainlinkAggregatorArg.isContract(), "PBP_PCAINC");

        _perp = perpArg;
        _usdc = usdcArg;
        _perpChainlinkAggregator = perpChainlinkAggregatorArg;

        __Ownable2Step_init();
    }

    function setPerpBuyback(address perpBuybackArg) external onlyOwner {
        // PBP_PBINC: perpBuyback is not contract
        require(perpBuybackArg.isContract(), "PBP_PBINC");
        _perpBuyBack = perpBuybackArg;
    }

    function withdrawToken(address token, uint256 tokenAmount) external onlyOwner {
        address owner = owner();
        IERC20Upgradeable(token).transfer(owner, tokenAmount);
    }

    function withdrawAllToken(address token) external onlyOwner {
        address owner = owner();
        uint256 balance = IERC20Upgradeable(token).balanceOf(address(this));
        IERC20Upgradeable(token).transfer(owner, balance);
    }

    function swap(uint256 usdcAmount) external override returns (uint256) {
        address perpBuyback = _perpBuyBack;

        // PBP_OPB: only perpBuyback
        require(msg.sender == perpBuyback, "PBP_OPB");

        uint8 chainlinkDecimals = AggregatorV2V3Interface(_perpChainlinkAggregator).decimals();
        (, int256 latestAnswer, , uint256 updatedAt, ) = AggregatorV2V3Interface(_perpChainlinkAggregator)
            .latestRoundData();

        // PBP_SP: stale price
        require(block.timestamp <= updatedAt + PERP_PRICE_FEED_HEARTBEAT, "PBP_SP");
        // PBP_OIZ: oracle is zero
        require(latestAnswer > 0, "PBP_OIZ");

        // usdc is in 6 decimals, perp is in 18 decimals
        uint256 buybackPerpAmount = (usdcAmount * (10 ** (12 + chainlinkDecimals))) / uint256(latestAnswer);
        uint256 perpBalance = IERC20Upgradeable(_perp).balanceOf(address(this));

        // PBP_PBI: perp balance is insufficient
        require(buybackPerpAmount <= perpBalance, "PBP_PBI");

        IERC20Upgradeable(_usdc).transferFrom(perpBuyback, address(this), usdcAmount);
        IERC20Upgradeable(_perp).transfer(perpBuyback, buybackPerpAmount);

        return buybackPerpAmount;
    }

    //
    // EXTERNAL VIEW
    //

    function getUsdc() external view override returns (address) {
        return _usdc;
    }

    function getPerp() external view override returns (address) {
        return _perp;
    }

    function getPerpBuyback() external view override returns (address) {
        return _perpBuyBack;
    }

    function getPerpChainlinkAggregator() external view override returns (address) {
        return _perpChainlinkAggregator;
    }
}
