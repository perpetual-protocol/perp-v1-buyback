// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract PerpBuybackStorage {
    address internal _usdc;

    address internal _perp;

    address internal _vePerp;

    address internal _perpBuybackPool;

    address[18] internal _whitelistUser;

    uint256 internal _remainingBuybackUsdcAmount;

    mapping(address => bool) internal _isInWhitelist;

    mapping(address => uint256) internal _userClaimableVePerpAmount;
}
