// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IPerpBuyback } from "./interface/IPerpBuyback.sol";
import { IVePerp } from "./interface/IVePerp.sol";
import { IPerpBuybackPool } from "./interface/IPerpBuybackPool.sol";
import { PerpBuybackStorage } from "./storage/PerpBuybackStorage.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import { EnumerableMapUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract PerpBuyback is IPerpBuyback, ReentrancyGuardUpgradeable, Ownable2StepUpgradeable, PerpBuybackStorage {
    using AddressUpgradeable for address;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.AddressToUintMap;

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

        _sharesByUser.set(0x000000ea89990a17Ec07a35Ac2BBb02214C50152, 215717);
        _sharesByUser.set(0xbb327eBA8fC6085E8639E378FE86c73546ddab2D, 174893);
        _sharesByUser.set(0xA0e04247d39eBc07f38ACca38Dc10E14fa8d6C98, 5705);
        _sharesByUser.set(0x9d9250586e0443b49CBc975aA51dFB739C8eC50D, 76943);
        _sharesByUser.set(0x39e6382ec12e06EfF56aead7b785a5d461B70e13, 66269);
        _sharesByUser.set(0x530deFD6c816809F54F6CfA6FE873646F6EcF930, 63850);
        _sharesByUser.set(0x353D7E185B1567b7C2A54e031357aa41a7BA2e1f, 56664);
        _sharesByUser.set(0x4D930F0E508EeDF38B19041225D8Af8c153bF5e2, 42530);
        _sharesByUser.set(0x4A3eb6fea600D7E48256BAdCbE2931DA9Fc3999a, 40177);
        _sharesByUser.set(0xe35Bc00cf7C9D085d08084f2A1213701D6f86BCb, 42586);
        _sharesByUser.set(0xB76bF854Ef3A9105A2FFe204608d06C7A5259604, 17964);
        _sharesByUser.set(0x70D781Bbf2a5454fe688452e2D27A9b71AA1e8AB, 31688);
        _sharesByUser.set(0x6A654dc73E4e7666648044149F3a8162FD327C55, 32719);
        _sharesByUser.set(0x89501EA15422Db2C483919AFEb960bE010a8839C, 30891);
        _sharesByUser.set(0x68D779947734306136ebcecfC4AfF6Eb6ea4F5D9, 7651);
        _sharesByUser.set(0x3F48b62e129326C1235891fdebaBe2f3451ddD2e, 20267);
        _sharesByUser.set(0xfD4Bd3416270F2A432797B82Ca919e6FBC37EBc5, 29512);
        _sharesByUser.set(0x8540078e825f1A7D1c12f3C8CD4dFD7A05FE2995, 27513);
        _sharesByUser.set(0xcAcC55289917abAF27eA98c51C9aF87c6F94f6Bf, 16461);

        // in USDC (6 decimals)
        _remainingBuybackUsdcAmount = 358763363 * 10 ** 6;

        __Ownable2Step_init();
        __ReentrancyGuard_init();
    }

    function withdrawToken(address token, uint256 tokenAmount) external onlyOwner {
        if (token == _usdc) {
            // PB_RBUAGE: remaining buyback USDC amount not zero
            require(_remainingBuybackUsdcAmount == 0, "PB_RBUANZ");
        }

        address owner = owner();
        IERC20Upgradeable(token).transfer(owner, tokenAmount);
    }

    function swapInPerpBuybackPool() external nonReentrant {
        // PB_RBUAIZ: remaining buyback USDC amount is zero
        require(_remainingBuybackUsdcAmount > 0, "PB_RBUAIZ");

        uint256 usdcBalance = IERC20Upgradeable(_usdc).balanceOf(address(this));
        uint256 buybackUsdcAmount = usdcBalance > _remainingBuybackUsdcAmount
            ? _remainingBuybackUsdcAmount
            : usdcBalance;
        _remainingBuybackUsdcAmount -= buybackUsdcAmount;

        address perpBuybackPool = _perpBuybackPool;
        require(IERC20Upgradeable(_usdc).approve(perpBuybackPool, buybackUsdcAmount));

        uint256 totalPerpBoughtThisTime = IPerpBuybackPool(perpBuybackPool).swap(buybackUsdcAmount);

        uint256 totalUserAmount = _sharesByUser.length();
        for (uint8 i = 0; i < totalUserAmount; i++) {
            (address user, uint256 shares) = _sharesByUser.at(i);
            uint256 perpBoughtThisTimeForUser = (totalPerpBoughtThisTime * shares) / 10 ** 6;
            _userClaimableVePerpAmount[user] += perpBoughtThisTimeForUser;
        }

        emit BuybackTriggered(buybackUsdcAmount, totalPerpBoughtThisTime);
    }

    function claim() external nonReentrant {
        address user = msg.sender;
        // PB_UINC: user is not whitelisted
        require(_sharesByUser.get(user) > 0, "PB_UINC");

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

    function getRemainingBuybackUsdcAmount() external view override returns (uint256) {
        return _remainingBuybackUsdcAmount;
    }

    function getUserClaimableVePerpAmount(address user) external view override returns (uint256) {
        return _userClaimableVePerpAmount[user];
    }

    function getUserNum() external view returns (uint256) {
        return _sharesByUser.length();
    }

    function getShares(address user) external view returns (uint256) {
        return _sharesByUser.get(user);
    }

    function getUserByIndex(uint256 index) external view returns (address) {
        (address user, ) = _sharesByUser.at(index);
        return user;
    }
}
