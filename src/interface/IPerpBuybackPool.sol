// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IPerpBuybackPool {
    function swap(uint256 UsdcAmount) external returns (uint256 perpAmount);

    function getUsdc() external view returns (address);

    function getPerp() external view returns (address);

    function getPerpBuyback() external view returns (address);

    function getPerpChainlinkAggregator() external view returns (address);
}
