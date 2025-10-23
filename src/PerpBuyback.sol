// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IPerpBuyback } from "./interface/IPerpBuyback.sol";
import { IVePerp } from "./interface/IVePerp.sol";
import { IPerpBuybackPool } from "./interface/IPerpBuybackPool.sol";
import { IUniswapV3Router } from "./interface/IUniswapV3Router.sol";
import { PerpBuybackStorage } from "./storage/PerpBuybackStorage.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import { EnumerableMapUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract PerpBuyback is IPerpBuyback, ReentrancyGuardUpgradeable, Ownable2StepUpgradeable, PerpBuybackStorage {
    using AddressUpgradeable for address;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.AddressToUintMap;

    address public constant UNISWAP_V3_ROUTER = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address public constant WETH = address(0x4200000000000000000000000000000000000006);
    uint256 private constant WEEK = 7 * 86400;
    uint256 private constant SHARE_SCALE = 1_000_000;

    // in USDC (6 decimals), 3,587,633.63 U
    uint256 private constant TOTAL_BUYBACK_USDC = 358_763_363 * 10 ** 4;

    struct UserShare {
        address user;
        uint256 share;
    }

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

        // can reference here: https://docs.google.com/spreadsheets/d/1Ok1LiKi4ApwfzviEMUd6NhxTI0B7ewogITDsq_ts7fI/edit?usp=sharing
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

        _remainingBuybackUsdcAmount = TOTAL_BUYBACK_USDC;

        __Ownable2Step_init();
        __ReentrancyGuard_init();
    }

    function withdrawToken(address token, uint256 tokenAmount) external onlyOwner {
        if (token == _usdc || token == _perp) {
            // PB_RBUAGE: remaining buyback USDC amount not zero
            require(_remainingBuybackUsdcAmount == 0, "PB_RBUANZ");
        }

        address owner = owner();
        IERC20Upgradeable(token).transfer(owner, tokenAmount);
    }

    // NOTE: use fixed path for now, and this function will only trigger by owner, MEV is not our concern
    function swapInUniswapV3Pool() external onlyOwner {
        // PB_RBUAIZ: remaining buyback USDC amount is zero
        require(_remainingBuybackUsdcAmount > 0, "PB_RBUAIZ");

        uint256 usdcBalance = IERC20Upgradeable(_usdc).balanceOf(address(this));
        uint256 buybackUsdcAmount = usdcBalance > _remainingBuybackUsdcAmount
            ? _remainingBuybackUsdcAmount
            : usdcBalance;
        _remainingBuybackUsdcAmount -= buybackUsdcAmount;

        require(IERC20Upgradeable(_usdc).approve(UNISWAP_V3_ROUTER, buybackUsdcAmount));

        // Fixed path: USDC -> WETH (0.05% pool), WETH -> PERP (0.3% pool)
        bytes memory path = abi.encodePacked(_usdc, uint24(500), WETH, uint24(3000), _perp);
        uint256 totalPerpBoughtThisTime = IUniswapV3Router(UNISWAP_V3_ROUTER).exactInput(
            IUniswapV3Router.ExactInputParams({
                path: path,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: buybackUsdcAmount,
                amountOutMinimum: 0
            })
        );

        uint256 totalUserAmount = _sharesByUser.length();
        for (uint8 i = 0; i < totalUserAmount; i++) {
            (address user, uint256 shares) = _sharesByUser.at(i);
            uint256 perpBoughtThisTimeForUser = (totalPerpBoughtThisTime * shares) / SHARE_SCALE;
            _userClaimableVePerpAmount[user] += perpBoughtThisTimeForUser;
        }

        emit BuybackTriggered(buybackUsdcAmount, totalPerpBoughtThisTime);
    }

    // NOTE: this function is deprecated, but keep this in case we need it in the future
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
            uint256 perpBoughtThisTimeForUser = (totalPerpBoughtThisTime * shares) / SHARE_SCALE;
            _userClaimableVePerpAmount[user] += perpBoughtThisTimeForUser;
        }

        emit BuybackTriggered(buybackUsdcAmount, totalPerpBoughtThisTime);
    }

    /**
     * @notice One-shot redistribution of inactive user allocations, authorized by governance.
     *
     * @dev Background: The original buyback proposal (https://gov.perp.fi/t/920) states:
     *      "If a particular user becomes inactive and did not claim any compensation for more
     *      than 1 year, or it becomes clear that the user doesn't want to claim, then the DAO
     *      treasury multisig has the full right to decide whether to withdraw that PERP and
     *      redistribute to the other users to speed up their pay offs."
     *
     *      After >1 year, 4 accounts remained inactive (no vePERP interaction). The DAO treasury
     *      exercised this right to redistribute their allocations to active users.
     *
     * @dev Actions performed:
     *      - Removes 4 inactive accounts from the share map
     *      - Redistributes their unclaimed PERP to active users using updated shares
     *      - Reduces remaining USDC budget to account for removed allocations
     *      - Emits detailed events for off-chain reconciliation
     *
     *      Safety: callable only once by owner (DAO treasury multisig)
     */
    function redistribute_2025() external nonReentrant onlyOwner {
        // Governance approved these four inactive accounts for removal; keep them in-line for readability.
        address[4] memory inactiveUsers = [
            address(0x000000ea89990a17Ec07a35Ac2BBb02214C50152),
            address(0xA0e04247d39eBc07f38ACca38Dc10E14fa8d6C98),
            address(0x39e6382ec12e06EfF56aead7b785a5d461B70e13),
            address(0x4A3eb6fea600D7E48256BAdCbE2931DA9Fc3999a)
        ];

        // Safety check: user_point_epoch == 0 confirms the account never interacted with vePERP
        // (no claim/deposit/deposit_for), proving they remain inactive and safe to remove.
        IVePerp vePerp = IVePerp(_vePerp);
        for (uint256 i = 0; i < inactiveUsers.length; ++i) {
            require(vePerp.user_point_epoch(inactiveUsers[i]) == 0, "Account has vePERP activity, cannot remove");
        }

        // each inactive account: sum their shares, prepare to move their claimable, and emit for audit trail.
        uint256 inactiveShare;
        uint256 inactiveClaimable;
        for (uint256 i = 0; i < inactiveUsers.length; ++i) {
            address user = inactiveUsers[i];
            (bool exists, uint256 share) = _sharesByUser.tryGet(user);
            require(exists, "Inactive account must exist before redistribution");

            inactiveShare += share;

            uint256 claimable = _userClaimableVePerpAmount[user];
            inactiveClaimable += claimable;
            _userClaimableVePerpAmount[user] = 0;

            _sharesByUser.remove(user);

            emit InactiveAccountCleared(user, share, claimable);
        }

        // Prevents double execution: once the inactive accounts are removed this reverts on re-entry.
        require(inactiveShare > 0, "No inactive share balance remains to redistribute");

        // https://docs.google.com/spreadsheets/d/1Ok1LiKi4ApwfzviEMUd6NhxTI0B7ewogITDsq_ts7fI/edit?gid=1240106799#gid=1240106799
        UserShare[15] memory activeUsers = [
            UserShare({ user: 0xbb327eBA8fC6085E8639E378FE86c73546ddab2D, share: 260_208 }),
            UserShare({ user: 0x9d9250586e0443b49CBc975aA51dFB739C8eC50D, share: 114_476 }),
            UserShare({ user: 0x530deFD6c816809F54F6CfA6FE873646F6EcF930, share: 94_997 }),
            UserShare({ user: 0x353D7E185B1567b7C2A54e031357aa41a7BA2e1f, share: 84_306 }),
            UserShare({ user: 0x4D930F0E508EeDF38B19041225D8Af8c153bF5e2, share: 63_277 }),
            UserShare({ user: 0xe35Bc00cf7C9D085d08084f2A1213701D6f86BCb, share: 63_358 }),
            UserShare({ user: 0xB76bF854Ef3A9105A2FFe204608d06C7A5259604, share: 26_725 }),
            UserShare({ user: 0x70D781Bbf2a5454fe688452e2D27A9b71AA1e8AB, share: 47_145 }),
            UserShare({ user: 0x6A654dc73E4e7666648044149F3a8162FD327C55, share: 48_680 }),
            UserShare({ user: 0x89501EA15422Db2C483919AFEb960bE010a8839C, share: 45_960 }),
            UserShare({ user: 0x68D779947734306136ebcecfC4AfF6Eb6ea4F5D9, share: 11_383 }),
            UserShare({ user: 0x3F48b62e129326C1235891fdebaBe2f3451ddD2e, share: 30_152 }),
            UserShare({ user: 0xfD4Bd3416270F2A432797B82Ca919e6FBC37EBc5, share: 43_908 }),
            UserShare({ user: 0x8540078e825f1A7D1c12f3C8CD4dFD7A05FE2995, share: 40_934 }),
            UserShare({ user: 0xcAcC55289917abAF27eA98c51C9aF87c6F94f6Bf, share: 24_491 })
        ];
        uint256 activeLength = activeUsers.length;

        // Update the active share table exactly as approved.
        uint256 shareSum;
        for (uint256 i = 0; i < activeLength; ++i) {
            UserShare memory entry = activeUsers[i];
            (bool hadPrevious, uint256 previousShare) = _sharesByUser.tryGet(entry.user);
            shareSum += entry.share;
            _sharesByUser.set(entry.user, entry.share);
            emit UserSharesChanged(entry.user, hadPrevious ? previousShare : 0, entry.share);
        }
        require(shareSum == SHARE_SCALE, "Active share table must sum to SHARE_SCALE");

        // Push claimable balances using the same pro-rata math as swap flows.
        uint256 redistributedPerp;
        uint256 totalUserAmount = _sharesByUser.length();
        for (uint8 i = 0; i < totalUserAmount; i++) {
            (address user, uint256 shares) = _sharesByUser.at(i);
            if (inactiveClaimable == 0) {
                continue;
            }

            uint256 allocation = (inactiveClaimable * shares) / SHARE_SCALE;
            _userClaimableVePerpAmount[user] += allocation;
            emit ActiveAccountRedistributed(user, shares, allocation);
            redistributedPerp += allocation;
        }

        // Adjust the USDC budget to account for inactive accounts removal.
        // Example: TOTAL_BUYBACK_USDC = 200; Alice and Bob each own 50%.
        // Initial state:
        //   - Total budget: 200 USDC (100 for Alice, 100 for Bob)
        //   - Already spent: 80 USDC on buybacks → currentRemaining = 120 USDC
        //   - Historical PERP: $40 worth of PERP for Alice (unclaimed), 40 for Bob (in _userClaimableVePerpAmount)
        //
        // After removing inactive Alice:
        //   - Alice's total entitlement: inactiveBudget = 200 * 50% = 100 USDC
        //   - This includes BOTH:
        //     • Past: 40 USDC worth of PERP
        //     • Future: 60 USDC not yet bought back
        //   - Subtract 100 from remaining 120 → leaves 20 USDC for Bob's future buybacks
        //   - Bob now receives: 40 (reclaimed) + his original 40 + future buybacks from 20 USDC
        //
        // Why this works: `inactiveBudget` represents inactive account's full allocation.
        // Subtracting it from `currentRemaining` simultaneously:
        //   1. Cancels her future allocation (60 USDC)
        //   2. Accounts for her historical share we just redistributed (40 USDC worth of PERP)
        uint256 inactiveBudget = (TOTAL_BUYBACK_USDC * inactiveShare) / SHARE_SCALE;
        uint256 currentRemaining = _remainingBuybackUsdcAmount;
        _remainingBuybackUsdcAmount = currentRemaining > inactiveBudget ? currentRemaining - inactiveBudget : 0;

        // Final bookkeeping event captures counts, budgets, and leftover USDC for downstream reconciliation.
        emit Redistribution2025Executed(
            inactiveUsers.length,
            activeLength,
            inactiveShare,
            inactiveBudget,
            redistributedPerp,
            _remainingBuybackUsdcAmount
        );
    }

    function claim() external nonReentrant {
        address user = msg.sender;

        // PB_UNIUM: user is not in user map
        require(_sharesByUser.contains(user), "PB_UNIUM");

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
