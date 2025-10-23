pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPerpBuybackEvent} from "../src/interface/IPerpBuyback.sol";
import {IVePerp} from "../src/interface/IVePerp.sol";
import {PerpBuyback} from "../src/PerpBuyback.sol";
import {SetUp} from "./SetUp.sol";

contract PerpBuybackRedistributeMainnetTest is IPerpBuybackEvent, SetUp {
    uint256 private constant SHARE_SCALE = 1_000_000;
    uint256 private constant TOTAL_BUYBACK_USDC = 358_763_363 * 10 ** 4;

    address private constant USDC = address(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    address private constant PERP = address(0x9e1028F5F1D5eDE59748FFceE5532509976840E0);
    address private constant VEPERP = address(0xD360B73b19Fb20aC874633553Fb1007e9FcB2b78);
    address private constant PERP_BUYBACK_POOL = address(0x23e440a6A792D3161e963b9Ff6bdAa005C06CA03);

    address private constant ACTIVE_USER = address(0xbb327eBA8fC6085E8639E378FE86c73546ddab2D); // Pick one from activeUsers
    uint256 private constant ACTIVE_USER_SHARE_AFTER = 260_208; // Pick one from activeUsers

    uint256 private constant ACTIVE_USER_COUNT_AFTER = 19 - 4;

    address[4] private inactiveUsers;
    PerpBuyback private perpBuyback;

    function setUp() public override {
        vm.createSelectFork(vm.envString("OPTIMISM_WEB3_ENDPOINT_ARCHIVE"), 142795917); // Thu Oct 23 2025 11:36:51 GMT+0800

        SetUp.setUp();

        inactiveUsers = [
            address(0x000000ea89990a17Ec07a35Ac2BBb02214C50152),
            address(0xA0e04247d39eBc07f38ACca38Dc10E14fa8d6C98),
            address(0x39e6382ec12e06EfF56aead7b785a5d461B70e13),
            address(0x4A3eb6fea600D7E48256BAdCbE2931DA9Fc3999a)
        ];

        perpBuyback = new PerpBuyback();
        perpBuyback.initialize(USDC, PERP, VEPERP, PERP_BUYBACK_POOL);
    }

    function test_redistribute2025() external {
        uint256 initialRemaining = perpBuyback.getRemainingBuybackUsdcAmount();
        assertEq(initialRemaining, TOTAL_BUYBACK_USDC, "initial remaining USDC budget mismatch");

        uint256 buybackUsdcAmount = 10_000 * 10 ** 6;
        deal(USDC, address(perpBuyback), buybackUsdcAmount, true);

        perpBuyback.swapInUniswapV3Pool();

        uint256 remainingAfterSwap = perpBuyback.getRemainingBuybackUsdcAmount();
        assertEq(
            initialRemaining - remainingAfterSwap,
            buybackUsdcAmount,
            "swap should reduce remaining USDC by amount spent"
        );
        assertGt(IERC20(PERP).balanceOf(address(perpBuyback)), 0, "PERP balance should increase after swap");

        uint256 inactiveShare = _sumInactiveShares();
        uint256 inactiveClaimableBefore = _sumInactiveClaimables();
        assertGt(inactiveShare, 0, "inactive cohort must own some share");
        assertGt(inactiveClaimableBefore, 0, "inactive cohort must have claimable PERP");

        for (uint256 i = 0; i < inactiveUsers.length; ++i) {
            assertEq(
                IVePerp(VEPERP).user_point_epoch(inactiveUsers[i]), 0, "inactive user unexpectedly has vePERP activity"
            );
        }

        uint256 totalClaimableBefore = _totalClaimable();
        uint256 activeShareBefore = perpBuyback.getShares(ACTIVE_USER);
        uint256 activeClaimableBefore = perpBuyback.getUserClaimableVePerpAmount(ACTIVE_USER);
        uint256 remainingBeforeRedistribution = perpBuyback.getRemainingBuybackUsdcAmount();

        perpBuyback.redistribute_2025();

        assertEq(perpBuyback.getUserNum(), ACTIVE_USER_COUNT_AFTER, "active user count after redistribution mismatch");

        for (uint256 i = 0; i < inactiveUsers.length; ++i) {
            // inactive user should have zero share after redistribution
            vm.expectRevert(bytes("EnumerableMap: nonexistent key"));
            perpBuyback.getShares(inactiveUsers[i]);

            assertEq(
                perpBuyback.getUserClaimableVePerpAmount(inactiveUsers[i]),
                0,
                "inactive user should have zero claimable after redistribution"
            );
        }

        uint256 activeShareAfter = perpBuyback.getShares(ACTIVE_USER);
        assertEq(activeShareAfter, ACTIVE_USER_SHARE_AFTER, "active user share not updated to approved value");
        assertGt(activeShareAfter, activeShareBefore, "active user share should increase after redistribution");

        uint256 activeClaimableAfter = perpBuyback.getUserClaimableVePerpAmount(ACTIVE_USER);
        assertGt(
            activeClaimableAfter, activeClaimableBefore, "active user claimable should increase after redistribution"
        );

        uint256 totalClaimableAfter = _totalClaimable();
        assertApproxEqAbs(
            totalClaimableBefore,
            totalClaimableAfter,
            10,
            "total claimable before and after should be within dust tolerance"
        );
        assertLe(
            totalClaimableAfter, totalClaimableBefore, "total claimable should not exceed pre-redistribution amount"
        );

        uint256 expectedInactiveBudget = (TOTAL_BUYBACK_USDC * inactiveShare) / SHARE_SCALE;
        uint256 expectedRemaining = remainingBeforeRedistribution > expectedInactiveBudget
            ? remainingBeforeRedistribution - expectedInactiveBudget
            : 0;

        assertEq(
            perpBuyback.getRemainingBuybackUsdcAmount(),
            expectedRemaining,
            "remaining USDC budget mismatch after redistribution"
        );

        vm.expectRevert(bytes("Inactive account must exist before redistribution"));
        perpBuyback.redistribute_2025();
    }

    function _sumInactiveShares() private view returns (uint256 total) {
        for (uint256 i = 0; i < inactiveUsers.length; ++i) {
            total += perpBuyback.getShares(inactiveUsers[i]);
        }
    }

    function _sumInactiveClaimables() private view returns (uint256 total) {
        for (uint256 i = 0; i < inactiveUsers.length; ++i) {
            total += perpBuyback.getUserClaimableVePerpAmount(inactiveUsers[i]);
        }
    }

    function _totalClaimable() private view returns (uint256 total) {
        uint256 userCount = perpBuyback.getUserNum();
        for (uint256 i = 0; i < userCount; ++i) {
            address user = perpBuyback.getUserByIndex(i);
            total += perpBuyback.getUserClaimableVePerpAmount(user);
        }
    }
}
