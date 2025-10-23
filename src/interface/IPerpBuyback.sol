// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IPerpBuybackEvent {
    event BuybackTriggered(uint256 usdcAmount, uint256 perpAmount);

    event Claimed(address user, uint256 claimPerpAmount);

    event InactiveAccountCleared(address indexed user, uint256 previousShare, uint256 claimableRedeemed);

    event UserSharesChanged(address indexed user, uint256 previousShare, uint256 newShare);

    event ActiveAccountRedistributed(address indexed user, uint256 newShare, uint256 claimableAdded);

    event Redistribution2025Executed(
        uint256 inactiveUserCount,
        uint256 activeUserCount,
        uint256 inactiveShare,
        uint256 inactiveBudget,
        uint256 redistributedPerp,
        uint256 remainingBuybackUsdcAmount
    );
}

interface IPerpBuyback is IPerpBuybackEvent {
    function getUsdc() external view returns (address);

    function getPerp() external view returns (address);

    function getVePerp() external view returns (address);

    function getPerpBuybackPool() external view returns (address);

    function getRemainingBuybackUsdcAmount() external view returns (uint256);

    function getUserClaimableVePerpAmount(address) external view returns (uint256);

    function redistribute_2025() external;
}
