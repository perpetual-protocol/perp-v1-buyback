pragma solidity 0.8.17;

import { IPerpBuybackEvent } from "../src/interface/IPerpBuyback.sol";
import { IPerpBuybackPool } from "../src/interface/IPerpBuybackPool.sol";
import { IVePerp } from "../src/interface/IVePerp.sol";
import { PerpBuyback } from "../src/PerpBuyback.sol";
import { SetUp } from "./SetUp.sol";

contract PerpBuybackRedistributeTest is IPerpBuybackEvent, SetUp {
    uint256 private constant SHARE_SCALE = 1_000_000;

    address[4] private inactiveWallets;

    address public vePerp;
    address public perpBuybackPool;
    PerpBuyback public perpBuyback;

    function setUp() public override {
        SetUp.setUp();

        perpBuybackPool = makeContract("PerpBuybackPool");
        vePerp = makeContract("VePerp");

        perpBuyback = new PerpBuyback();
        perpBuyback.initialize(address(usdc), address(perp), address(vePerp), perpBuybackPool);

        inactiveWallets = [
            address(0x000000ea89990a17Ec07a35Ac2BBb02214C50152),
            address(0xA0e04247d39eBc07f38ACca38Dc10E14fa8d6C98),
            address(0x39e6382ec12e06EfF56aead7b785a5d461B70e13),
            address(0x4A3eb6fea600D7E48256BAdCbE2931DA9Fc3999a)
        ];
    }

    function _mockInactiveEpochs(uint256 epochValue) private {
        for (uint256 i = 0; i < inactiveWallets.length; ++i) {
            vm.mockCall(
                vePerp,
                abi.encodeWithSelector(IVePerp.user_point_epoch.selector, inactiveWallets[i]),
                abi.encode(epochValue)
            );
        }
    }

    function _seedSwap(uint256 buybackUsdcAmount, uint256 buybackPerpAmount) private {
        usdc.mint(address(perpBuyback), buybackUsdcAmount);
        vm.mockCall(
            perpBuybackPool,
            abi.encodeWithSelector(IPerpBuybackPool.swap.selector),
            abi.encode(buybackPerpAmount)
        );
        perpBuyback.swapInPerpBuybackPool();
    }

    function test_redistribute2025_basicFlow() external {
        uint256 remainingBefore = perpBuyback.getRemainingBuybackUsdcAmount();

        // Seed a swap so every wallet has claimable PERP under the original share map. This ensures the
        // redistribution path moves value (otherwise everything would stay zero and the assertions below
        // would be meaningless).
        _seedSwap(10_000 * 10 ** 6, 10_000 ether);
        _mockInactiveEpochs(0);

        address inactiveUser = inactiveWallets[0];
        address activeUser = 0xbb327eBA8fC6085E8639E378FE86c73546ddab2D;

        uint256 activeShareBefore = perpBuyback.getShares(activeUser);
        uint256 activeClaimableBefore = perpBuyback.getUserClaimableVePerpAmount(activeUser);
        assertGt(perpBuyback.getUserClaimableVePerpAmount(inactiveUser), 0);

        perpBuyback.redistribute_2025();

        vm.expectRevert(bytes("EnumerableMap: nonexistent key"));
        perpBuyback.getShares(inactiveUser);
        assertEq(perpBuyback.getUserClaimableVePerpAmount(inactiveUser), 0);

        // Active wallets should now own both a larger share and the PERP reclaimed from the inactive cohort.
        assertGt(perpBuyback.getShares(activeUser), activeShareBefore);
        assertTrue(perpBuyback.getUserClaimableVePerpAmount(activeUser) >= activeClaimableBefore);
        assertLt(perpBuyback.getRemainingBuybackUsdcAmount(), remainingBefore);

        vm.expectRevert(bytes("Inactive account must exist before redistribution"));
        perpBuyback.redistribute_2025();
    }

    function test_redistribute2025_revertsWhenInactiveClaimed() external {
        _mockInactiveEpochs(0);
        vm.mockCall(
            vePerp,
            abi.encodeWithSelector(IVePerp.user_point_epoch.selector, inactiveWallets[0]),
            abi.encode(uint256(1))
        );

        vm.expectRevert(bytes("Account has vePERP activity, cannot remove"));
        perpBuyback.redistribute_2025();
    }

    function test_redistribute2025_shareSumEqualsShareScale() external {
        _mockInactiveEpochs(0);
        perpBuyback.redistribute_2025();

        uint256 totalShares;
        uint256 userCount = perpBuyback.getUserNum();
        for (uint256 i = 0; i < userCount; i++) {
            totalShares += perpBuyback.getShares(perpBuyback.getUserByIndex(i));
        }

        assertEq(totalShares, SHARE_SCALE, "Total shares must equal SHARE_SCALE");
    }

    function test_redistribute2025_userCountIs15() external {
        assertEq(perpBuyback.getUserNum(), 19);

        _mockInactiveEpochs(0);
        perpBuyback.redistribute_2025();

        assertEq(perpBuyback.getUserNum(), 15);
    }

    function test_redistribute2025_exactShareValues() external {
        _mockInactiveEpochs(0);
        perpBuyback.redistribute_2025();

        assertEq(perpBuyback.getShares(0xbb327eBA8fC6085E8639E378FE86c73546ddab2D), 260_208);
        assertEq(perpBuyback.getShares(0x9d9250586e0443b49CBc975aA51dFB739C8eC50D), 114_476);
        assertEq(perpBuyback.getShares(0x530deFD6c816809F54F6CfA6FE873646F6EcF930), 94_997);
        assertEq(perpBuyback.getShares(0x353D7E185B1567b7C2A54e031357aa41a7BA2e1f), 84_306);
        assertEq(perpBuyback.getShares(0x4D930F0E508EeDF38B19041225D8Af8c153bF5e2), 63_277);
        assertEq(perpBuyback.getShares(0xe35Bc00cf7C9D085d08084f2A1213701D6f86BCb), 63_358);
        assertEq(perpBuyback.getShares(0xB76bF854Ef3A9105A2FFe204608d06C7A5259604), 26_725);
        assertEq(perpBuyback.getShares(0x70D781Bbf2a5454fe688452e2D27A9b71AA1e8AB), 47_145);
        assertEq(perpBuyback.getShares(0x6A654dc73E4e7666648044149F3a8162FD327C55), 48_680);
        assertEq(perpBuyback.getShares(0x89501EA15422Db2C483919AFEb960bE010a8839C), 45_960);
        assertEq(perpBuyback.getShares(0x68D779947734306136ebcecfC4AfF6Eb6ea4F5D9), 11_383);
        assertEq(perpBuyback.getShares(0x3F48b62e129326C1235891fdebaBe2f3451ddD2e), 30_152);
        assertEq(perpBuyback.getShares(0xfD4Bd3416270F2A432797B82Ca919e6FBC37EBc5), 43_908);
        assertEq(perpBuyback.getShares(0x8540078e825f1A7D1c12f3C8CD4dFD7A05FE2995), 40_934);
        assertEq(perpBuyback.getShares(0xcAcC55289917abAF27eA98c51C9aF87c6F94f6Bf), 24_491);
    }

    function test_redistribute2025_perpRedistributionMath() external {
        _seedSwap(10_000 * 10 ** 6, 10_000 ether);
        _mockInactiveEpochs(0);

        uint256 totalInactiveClaimable;
        for (uint256 i = 0; i < inactiveWallets.length; i++) {
            totalInactiveClaimable += perpBuyback.getUserClaimableVePerpAmount(inactiveWallets[i]);
        }

        uint256 totalClaimableBefore;
        uint256 userCount = perpBuyback.getUserNum();
        for (uint256 i = 0; i < userCount; i++) {
            totalClaimableBefore += perpBuyback.getUserClaimableVePerpAmount(perpBuyback.getUserByIndex(i));
        }

        perpBuyback.redistribute_2025();

        uint256 totalClaimableAfter;
        userCount = perpBuyback.getUserNum();
        for (uint256 i = 0; i < userCount; i++) {
            totalClaimableAfter += perpBuyback.getUserClaimableVePerpAmount(perpBuyback.getUserByIndex(i));
        }

        assertEq(totalClaimableAfter, totalClaimableBefore, "Total claimable PERP should be conserved");

        uint256 expectedShare = (totalInactiveClaimable * 260_208) / SHARE_SCALE;
        uint256 actualClaimable = perpBuyback.getUserClaimableVePerpAmount(0xbb327eBA8fC6085E8639E378FE86c73546ddab2D);
        // Integer division across 15 recipients can drop a few wei of dust. Allow a small
        // tolerance (one wei per recipient) so the assertion documents the expected precision.
        assertTrue(actualClaimable >= expectedShare - 15);
    }

    function test_redistribute2025_zeroClaimablePerp() external {
        _mockInactiveEpochs(0);

        perpBuyback.redistribute_2025();

        uint256 userCount = perpBuyback.getUserNum();
        for (uint256 i = 0; i < userCount; i++) {
            assertEq(perpBuyback.getUserClaimableVePerpAmount(perpBuyback.getUserByIndex(i)), 0);
        }
        assertEq(userCount, 15);
    }

    function test_redistribute2025_allEvents() external {
        _seedSwap(10_000 * 10 ** 6, 10_000 ether);
        _mockInactiveEpochs(0);

        address[4] memory inactiveUsers = inactiveWallets;
        uint256[4] memory inactiveShares = [uint256(215_717), 5_705, 66_269, 40_177];
        uint256[4] memory inactiveClaimables;
        for (uint256 i = 0; i < 4; ++i) {
            inactiveClaimables[i] = (10_000 ether * inactiveShares[i]) / SHARE_SCALE;
        }

        vm.expectEmit(true, false, false, false, address(perpBuyback));
        emit InactiveAccountCleared(inactiveUsers[0], inactiveShares[0], inactiveClaimables[0]);

        vm.expectEmit(true, false, false, false, address(perpBuyback));
        emit InactiveAccountCleared(inactiveUsers[1], inactiveShares[1], inactiveClaimables[1]);

        vm.expectEmit(true, false, false, false, address(perpBuyback));
        emit InactiveAccountCleared(inactiveUsers[2], inactiveShares[2], inactiveClaimables[2]);

        vm.expectEmit(true, false, false, false, address(perpBuyback));
        emit InactiveAccountCleared(inactiveUsers[3], inactiveShares[3], inactiveClaimables[3]);

        vm.expectEmit(true, false, false, false, address(perpBuyback));
        emit UserSharesChanged(0xbb327eBA8fC6085E8639E378FE86c73546ddab2D, 174_893, 260_208);

        vm.expectEmit(true, false, false, false, address(perpBuyback));
        emit UserSharesChanged(0xcAcC55289917abAF27eA98c51C9aF87c6F94f6Bf, 16_461, 24_491);

        vm.expectEmit(true, false, false, false, address(perpBuyback));
        uint256 firstAllocation = (10_000 ether * 260_208) / SHARE_SCALE;
        emit ActiveAccountRedistributed(0xbb327eBA8fC6085E8639E378FE86c73546ddab2D, 260_208, firstAllocation);

        vm.expectEmit(false, false, false, false, address(perpBuyback));
        uint256 inactiveShareTotal = inactiveShares[0] + inactiveShares[1] + inactiveShares[2] + inactiveShares[3];
        uint256 totalBudgetBefore = perpBuyback.getRemainingBuybackUsdcAmount();
        uint256 inactiveBudget = (totalBudgetBefore * inactiveShareTotal) / SHARE_SCALE;
        uint256 remainingBefore = perpBuyback.getRemainingBuybackUsdcAmount();
        emit Redistribution2025Executed(
            4,
            15,
            inactiveShareTotal,
            inactiveBudget,
            inactiveClaimables[0] + inactiveClaimables[1] + inactiveClaimables[2] + inactiveClaimables[3],
            remainingBefore > inactiveBudget ? remainingBefore - inactiveBudget : 0
        );

        perpBuyback.redistribute_2025();
    }
}
