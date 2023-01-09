// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IVePerp {
    function deposit_for(address user, uint256 value) external;

    function locked__end(address user) external view returns (uint256);
}
