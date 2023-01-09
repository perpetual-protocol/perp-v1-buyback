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

        address[18] memory userList = _userList;
        for (uint8 i = 0; i < 18; i++) {
            _canClaimVePerpUsers[userList[i]] = true;
        }

        __Ownable2Step_init();
    }

    function withdrawToken(address token, uint256 tokenAmount) external onlyOwner {
        require(_remainingBuybackUsdcAmount == 0);
        address owner = owner();
        IERC20Upgradeable(token).transfer(owner, tokenAmount);
    }

    function swapInPerpBuybackPool() external {
        require(_remainingBuybackUsdcAmount > 0);

        uint256 usdcBalance = IERC20Upgradeable(_usdc).balanceOf(address(this));
        uint256 usdcBuybackAmount = usdcBalance > _remainingBuybackUsdcAmount
            ? _remainingBuybackUsdcAmount
            : usdcBalance;
        _remainingBuybackUsdcAmount -= usdcBuybackAmount;

        address perpBuybackPool = _perpBuybackPool;
        require(IERC20Upgradeable(_usdc).approve(perpBuybackPool, usdcBuybackAmount));

        uint256 buybackPerpAmount = IPerpBuybackPool(perpBuybackPool).swap(usdcBuybackAmount);
        uint256 eachUserPerpAmount = buybackPerpAmount / 18;

        address[18] memory userList = _userList;
        for (uint8 i = 0; i < 18; i++) {
            _userClaimableVePerpAmount[userList[i]] += eachUserPerpAmount;
        }

        emit BuybackTriggered(usdcBuybackAmount, buybackPerpAmount);
    }

    function claim() external {
        address user = msg.sender;
        require(_canClaimVePerpUsers[user]);

        address vePerp = _vePerp;
        uint256 currentWeekStart = (block.timestamp / WEEK) * WEEK;
        uint256 lockEnd = IVePerp(vePerp).locked__end(user);

        // PB_LET26W: end time less than 26 weeks
        require(lockEnd > currentWeekStart + 26 * WEEK, "PB_ETL26W");

        uint256 userClaimableVePerpAmount = _userClaimableVePerpAmount[user];
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

    function getUserList() external view override returns (address[18] memory) {
        return _userList;
    }

    function getRemainingBuybackUsdcAmount() external view override returns (uint256) {
        return _remainingBuybackUsdcAmount;
    }

    function canClaimVePerp(address user) external view override returns (bool) {
        return _canClaimVePerpUsers[user];
    }

    function getUserClaimableVePerpAmount(address user) external view override returns (uint256) {
        return _userClaimableVePerpAmount[user];
    }
}
