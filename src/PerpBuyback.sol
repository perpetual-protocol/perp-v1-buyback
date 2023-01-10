// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IPerpBuyback } from "./interface/IPerpBuyback.sol";
import { IVePerp } from "./interface/IVePerp.sol";
import { IPerpBuybackPool } from "./interface/IPerpBuybackPool.sol";
import { PerpBuybackStorage } from "./storage/PerpBuybackStorage.sol";
import { Ownable2StepUpgradeable } from "openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { AddressUpgradeable } from "openzeppelin-contracts-upgradeable/utils/AddressUpgradeable.sol";

contract PerpBuyback is IPerpBuyback, Ownable2StepUpgradeable, PerpBuybackStorage {
    using AddressUpgradeable for address;

    uint256 private constant WEEK = 7 * 86400;

    //
    // EXTERNAL NON-VIEW
    //

    function initialize(
        address usdcArg,
        address perpArg,
        address vePerpArg,
        address perpBuybackPoolArg
    ) external initializer {
        // PB_UINC: usdc is not contract
        require(usdcArg.isContract(), "PB_UINC");
        // PB_PINC: perp is not contract
        require(perpArg.isContract(), "PB_PINC");
        // PB_VPINC: vePERP is not contract
        require(vePerpArg.isContract(), "PB_VPINC");
        // PB_PBPINC: perpBuybackPool is not contract
        require(perpBuybackPoolArg.isContract(), "PB_PBPINC");

        _usdc = usdcArg;
        _perp = perpArg;
        _vePerp = vePerpArg;
        _perpBuybackPool = perpBuybackPoolArg;

        // TODO: need to add source url
        _whitelistUser = [
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
        _remainingBuybackUsdcAmount = 3590000 * 10**6;

        address[18] memory whitelistUser = _whitelistUser;
        for (uint8 i = 0; i < 18; ++i) {
            _isInWhitelist[whitelistUser[i]] = true;
        }

        __Ownable2Step_init();
    }

    function withdrawToken(address token, uint256 tokenAmount) external onlyOwner {
        // PB_RBUAGE: remaining buyback USDC amount not zero
        require(_remainingBuybackUsdcAmount == 0, "PB_RBUANZ");
        address owner = owner();
        IERC20Upgradeable(token).transfer(owner, tokenAmount);
    }

    function swapInPerpBuybackPool() external {
        // PB_RBUAIZ: remaining buyback USDC amount is zero
        require(_remainingBuybackUsdcAmount > 0, "PB_RBUAIZ");

        uint256 usdcBalance = IERC20Upgradeable(_usdc).balanceOf(address(this));
        uint256 buybackUsdcAmount = usdcBalance > _remainingBuybackUsdcAmount
            ? _remainingBuybackUsdcAmount
            : usdcBalance;
        _remainingBuybackUsdcAmount -= buybackUsdcAmount;

        address perpBuybackPool = _perpBuybackPool;
        require(IERC20Upgradeable(_usdc).approve(perpBuybackPool, buybackUsdcAmount));

        uint256 buybackPerpAmount = IPerpBuybackPool(perpBuybackPool).swap(buybackUsdcAmount);
        uint256 eachUserPerpAmount = buybackPerpAmount / 18;

        address[18] memory whitelistUser = _whitelistUser;
        for (uint8 i = 0; i < 18; ++i) {
            _userClaimableVePerpAmount[whitelistUser[i]] += eachUserPerpAmount;
        }

        emit BuybackTriggered(buybackUsdcAmount, buybackPerpAmount);
    }

    function claim() external {
        address user = msg.sender;
        // PB_UINC: user is not whitelisted
        require(_isInWhitelist[user], "PB_UINW");

        address vePerp = _vePerp;
        uint256 currentWeekStart = (block.timestamp / WEEK) * WEEK;
        uint256 lockEnd = IVePerp(vePerp).locked__end(user);

        // PB_LET26W: end time less than 26 weeks
        require(lockEnd > currentWeekStart + 26 * WEEK, "PB_ETL26W");

        uint256 userClaimableVePerpAmount = _userClaimableVePerpAmount[user];
        // PB_UCAIZ: user claimable amount is zero
        require(userClaimableVePerpAmount > 0, "PB_UCAIZ");
        _userClaimableVePerpAmount[user] = 0;

        IERC20Upgradeable(_perp).approve(vePerp, userClaimableVePerpAmount);
        IVePerp(vePerp).deposit_for(user, userClaimableVePerpAmount);

        emit Claimed(user, userClaimableVePerpAmount);
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

    function getVePerp() external view override returns (address) {
        return _vePerp;
    }

    function getPerpBuybackPool() external view override returns (address) {
        return _perpBuybackPool;
    }

    function getWhitelistUser() external view override returns (address[18] memory) {
        return _whitelistUser;
    }

    function getRemainingBuybackUsdcAmount() external view override returns (uint256) {
        return _remainingBuybackUsdcAmount;
    }

    function getUserClaimableVePerpAmount(address user) external view override returns (uint256) {
        return _userClaimableVePerpAmount[user];
    }

    function isInWhitelist(address user) external view override returns (bool) {
        return _isInWhitelist[user];
    }
}
