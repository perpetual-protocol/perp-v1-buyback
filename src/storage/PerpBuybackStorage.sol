// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract PerpBuybackStorage {
    address internal _usdc;

    address internal _perp;

    address internal _vePerp;

    address internal _perpBuybackPool;

    // TODO: need to add source url
    address[18] internal _userList = [
        0x0000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000002,
        0x0000000000000000000000000000000000000003,
        0x0000000000000000000000000000000000000004,
        0x0000000000000000000000000000000000000005,
        0x0000000000000000000000000000000000000006,
        0x0000000000000000000000000000000000000007,
        0x0000000000000000000000000000000000000008,
        0x0000000000000000000000000000000000000009,
        0x000000000000000000000000000000000000000A,
        0x000000000000000000000000000000000000000b,
        0x000000000000000000000000000000000000000C,
        0x000000000000000000000000000000000000000d,
        0x000000000000000000000000000000000000000E,
        0x000000000000000000000000000000000000000F,
        0x0000000000000000000000000000000000000010,
        0x0000000000000000000000000000000000000011,
        0x0000000000000000000000000000000000000012
    ];

    // 3.59M in USDC (6 decimals)
    uint256 internal _remainingBuybackUsdcAmount = 3590000 * 10**6;

    mapping(address => bool) internal _canClaimVePerpUsers;

    mapping(address => uint256) internal _userClaimableVePerpAmount;
}
