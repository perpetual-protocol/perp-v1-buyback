pragma solidity 0.8.17;

import { IPerpBuybackPool } from "../src/interface/IPerpBuybackPool.sol";
import { IPerpBuybackEvent } from "../src/interface/IPerpBuyback.sol";
import { IVePerp } from "../src/interface/IVePerp.sol";
import { PerpBuyback } from "../src/PerpBuyback.sol";
import { SetUp } from "./SetUp.sol";

contract PerpBuybackTest is IPerpBuybackEvent, SetUp {
    uint256 private constant WEEK = 7 * 86400;

    address public vePerp;
    address public perpBuybackPool;
    PerpBuyback public perpBuyback;

    function setUp() public override {
        SetUp.setUp();

        perpBuybackPool = makeContract("PerpBuybackPool");
        vePerp = makeContract("VePerp");

        perpBuyback = new PerpBuyback();
        perpBuyback.initialize(address(usdc), address(perp), address(vePerp), perpBuybackPool);
    }

    function test_swapInPerpBuybackPool() external {
        uint256 buybackUsdcAmount = 1_800 * 10 ** 6;
        uint256 buybackPerpAmount = 180 ether;

        // assume swap 1800 USDC for 180 PERP
        usdc.mint(address(perpBuyback), buybackUsdcAmount);
        vm.mockCall(
            perpBuybackPool,
            abi.encodeWithSelector(IPerpBuybackPool.swap.selector),
            abi.encode(buybackPerpAmount)
        );

        vm.expectEmit(false, false, false, true, address(perpBuyback));
        emit BuybackTriggered(buybackUsdcAmount, buybackPerpAmount);

        perpBuyback.swapInPerpBuybackPool();

        // 3587633.63 - 1800 = 3,585,833.63
        assertEq(perpBuyback.getRemainingBuybackUsdcAmount(), 358583363 * 10 ** 4);

        // 180 PERP * 21.5717% = 38.82906
        assertEq(
            perpBuyback.getUserClaimableVePerpAmount(0x000000ea89990a17Ec07a35Ac2BBb02214C50152),
            38829060000000000000
        );

        // sum of user's personal claimable perp is 180
        uint256 num = perpBuyback.getUserNum();
        uint256 sumClaimablePerp = 0;
        for (uint256 i = 0; i < num; ++i) {
            address user = perpBuyback.getUserByIndex(i);
            uint256 claimablePerp = perpBuyback.getUserClaimableVePerpAmount(user);
            sumClaimablePerp += claimablePerp;
        }
        assertEq(sumClaimablePerp, buybackPerpAmount);
    }

    function test_swapInPerpBuybackPool_when_remainingBuybackUsdcAmount_lt_perpBuyback_usdcBalance() external {
        uint256 buybackUsdcAmount = perpBuyback.getRemainingBuybackUsdcAmount();
        uint256 buybackPerpAmount = 180 ether;
        uint256 perpBuybackUsdcBalance = buybackUsdcAmount * 42;

        // when perpBuybackUsdcBalance > remainingBuybackUsdcAmount, will use remainingBuybackUsdcAmount to swap
        usdc.mint(address(perpBuyback), perpBuybackUsdcBalance);
        vm.mockCall(
            perpBuybackPool,
            abi.encodeWithSelector(IPerpBuybackPool.swap.selector),
            abi.encode(buybackPerpAmount)
        );

        vm.expectEmit(false, false, false, true, address(perpBuyback));
        emit BuybackTriggered(buybackUsdcAmount, buybackPerpAmount);

        perpBuyback.swapInPerpBuybackPool();
    }

    function test_revert_swapInPerpBuybackPool_when_remainingBuybackUsdcAmount_is_zero() external {
        uint256 buybackUsdcAmount = perpBuyback.getRemainingBuybackUsdcAmount();
        uint256 buybackPerpAmount = 359_000 ether;

        // assume swap 3.59M USDC for 0.358M PERP
        usdc.mint(address(perpBuyback), buybackUsdcAmount);
        vm.mockCall(
            perpBuybackPool,
            abi.encodeWithSelector(IPerpBuybackPool.swap.selector),
            abi.encode(buybackPerpAmount)
        );

        perpBuyback.swapInPerpBuybackPool();

        // will revert when remainingBuybackUsdcAmount is zero
        assertEq(perpBuyback.getRemainingBuybackUsdcAmount(), 0);

        vm.expectRevert(bytes("PB_RBUAIZ"));
        perpBuyback.swapInPerpBuybackPool();
    }

    function test_claim() external {
        address user = perpBuyback.getUserByIndex(0);

        // swapInPerpBuybackPool (swap 1800 USD for 180 PERP)
        uint256 buybackUsdcAmount = 1_800 * 10 ** 6;
        uint256 buybackPerpAmount = 180 ether;

        usdc.mint(address(perpBuyback), buybackUsdcAmount);
        vm.mockCall(
            perpBuybackPool,
            abi.encodeWithSelector(IPerpBuybackPool.swap.selector),
            abi.encode(buybackPerpAmount)
        );

        perpBuyback.swapInPerpBuybackPool();

        uint256 userClaimableVePerpAmount = perpBuyback.getUserClaimableVePerpAmount(user);
        assertGt(userClaimableVePerpAmount, 0);

        // mock vePERP lock__end, deposit_for
        vm.mockCall(
            vePerp,
            abi.encodeWithSelector(IVePerp.locked__end.selector),
            abi.encode(block.timestamp + 26 * WEEK)
        );
        vm.mockCall(vePerp, abi.encodeWithSelector(IVePerp.deposit_for.selector), "");

        // claim
        vm.prank(user);
        vm.expectEmit(false, false, false, true, address(perpBuyback));
        emit Claimed(user, userClaimableVePerpAmount);
        perpBuyback.claim();

        assertEq(perpBuyback.getUserClaimableVePerpAmount(user), 0);
    }

    function test_revert_claim_when_end_time_is_less_than_26_weeks() external {
        address user = perpBuyback.getUserByIndex(0);

        // swapInPerpBuybackPool (swap 1800 USD for 180 PERP)
        uint256 buybackUsdcAmount = 1_800 * 10 ** 6;
        uint256 buybackPerpAmount = 180 ether;

        usdc.mint(address(perpBuyback), buybackUsdcAmount);
        vm.mockCall(
            perpBuybackPool,
            abi.encodeWithSelector(IPerpBuybackPool.swap.selector),
            abi.encode(buybackPerpAmount)
        );

        perpBuyback.swapInPerpBuybackPool();

        uint256 userClaimableVePerpAmount = perpBuyback.getUserClaimableVePerpAmount(user);
        assertGt(userClaimableVePerpAmount, 0);

        // mock vePERP lock__end, deposit_for
        vm.mockCall(
            vePerp,
            abi.encodeWithSelector(IVePerp.locked__end.selector),
            abi.encode(block.timestamp + 25 * WEEK)
        );
        vm.mockCall(vePerp, abi.encodeWithSelector(IVePerp.deposit_for.selector), "");

        // claim
        vm.expectRevert(bytes("PB_ETL26W"));
        vm.prank(user);
        perpBuyback.claim();
    }

    function test_revert_claim_when_user_is_not_in_user_map() external {
        vm.expectRevert(bytes("PB_UNIUM"));
        perpBuyback.claim();
    }

    function test_revert_claim_when_user_claimable_amount_is_zero() external {
        address user = perpBuyback.getUserByIndex(0);
        // mock vePERP lock__end, deposit_for
        vm.mockCall(
            vePerp,
            abi.encodeWithSelector(IVePerp.locked__end.selector),
            abi.encode(block.timestamp + 26 * WEEK)
        );
        vm.mockCall(vePerp, abi.encodeWithSelector(IVePerp.deposit_for.selector), "");

        // claim
        vm.expectRevert(bytes("PB_UCAIZ"));
        vm.prank(user);
        perpBuyback.claim();
    }

    function test_withdrawToken() external {
        uint256 buybackUsdcAmount = perpBuyback.getRemainingBuybackUsdcAmount();
        uint256 buybackPerpAmount = 359_000 ether;

        // assume swap 3.59M USDC for 0.358M PERP
        usdc.mint(address(perpBuyback), buybackUsdcAmount);
        vm.mockCall(
            perpBuybackPool,
            abi.encodeWithSelector(IPerpBuybackPool.swap.selector),
            abi.encode(buybackPerpAmount)
        );

        perpBuyback.swapInPerpBuybackPool();

        assertEq(perpBuyback.getRemainingBuybackUsdcAmount(), 0);

        // mint again and withdraw later
        usdc.mint(address(perpBuyback), buybackUsdcAmount);
        uint256 perpBuybackUsdcBalanceBefore = usdc.balanceOf(address(perpBuyback));

        perpBuyback.withdrawToken(address(usdc), buybackUsdcAmount);
        uint256 perpBuybackUsdcBalanceAfter = usdc.balanceOf(address(perpBuyback));
        assertEq(perpBuybackUsdcBalanceBefore - perpBuybackUsdcBalanceAfter, buybackUsdcAmount);
    }

    function test_revert_withdrawToken_when_remainingBuybackUsdcAmount_is_not_zero() external {
        vm.expectRevert(bytes("PB_RBUANZ"));
        perpBuyback.withdrawToken(address(usdc), 42);
    }

    function test_revert_withdrawToken_when_not_owner() external {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vm.prank(address(0x42));
        perpBuyback.withdrawToken(address(usdc), 42);
    }

    function test_getUsdc() external {
        assertEq(perpBuyback.getUsdc(), address(usdc));
    }

    function test_getPerp() external {
        assertEq(perpBuyback.getPerp(), address(perp));
    }

    function test_getVePerp() external {
        assertEq(perpBuyback.getVePerp(), address(vePerp));
    }

    function test_getPerpBuybackPool() external {
        assertEq(perpBuyback.getPerpBuybackPool(), perpBuybackPool);
    }
}
