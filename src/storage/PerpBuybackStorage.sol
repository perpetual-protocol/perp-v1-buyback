// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { EnumerableMapUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";

abstract contract PerpBuybackStorage {
    address internal _usdc;

    address internal _perp;

    address internal _vePerp;

    address internal _perpBuybackPool;

    uint256 internal _remainingBuybackUsdcAmount;

    mapping(address => uint256) internal _userClaimableVePerpAmount;

    // in 10e6 format
    EnumerableMapUpgradeable.AddressToUintMap internal _sharesByUser;
}
