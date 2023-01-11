// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract PerpBuybackPoolStorage {
    address internal _perp;

    address internal _usdc;

    address internal _perpBuyBack;

    address internal _perpChainlinkAggregator;
}
