// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IPerpBuybackEvent {
    event BuybackTriggered(uint256 usdcAmount, uint256 perpAmount);

    event Claimed(address user, uint256 claimPerpAmount);
}

interface IPerpBuyback is IPerpBuybackEvent {
    function getUsdc() external view returns (address);

    function getPerp() external view returns (address);

    function getVePerp() external view returns (address);

    function getPerpBuybackPool() external view returns (address);

    function getWhitelistUser() external view returns (address[18] memory);

    function getRemainingBuybackUsdcAmount() external view returns (uint256);

    function getUserClaimableVePerpAmount(address) external view returns (uint256);

    function isInWhitelist(address user) external view returns (bool);
}
