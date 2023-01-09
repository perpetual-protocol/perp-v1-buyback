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
    address[18] public whitelistUser = [
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

    PerpBuyback public perpBuyback;

    function setUp() public override {
        SetUp.setUp();

        perpBuybackPool = makeContract("PerpBuybackPool");
        vePerp = makeContract("VePerp");

        perpBuyback = new PerpBuyback();
        perpBuyback.initialize(address(usdc), address(perp), address(vePerp), perpBuybackPool);
    }

    function test_swapInPerpBuybackPool() external {
        uint256 buybackUsdcAmount = 1_800 * 10**6;
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

        // 3.59M - 1800 = 3,588,200
        assertEq(perpBuyback.getRemainingBuybackUsdcAmount(), 3_588_200 * 10**6);

        for (uint256 i = 0; i < 18; ++i) {
            assertEq(perpBuyback.getUserClaimableVePerpAmount(whitelistUser[i]), buybackPerpAmount / 18);
        }
    }

    function test_swapInPerpBuybackPool_when_remainingBuybackUsdcAmount_lt_perpBuyback_usdcBalance() external {
        uint256 buybackUsdcAmount = 3_590_000 * 10**6;
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
        uint256 buybackUsdcAmount = 3_590_000 * 10**6;
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
        address user = address(0x1);

        // swapInPerpBuybackPool (swap 1800 USD for 180 PERP)
        uint256 buybackUsdcAmount = 1_800 * 10**6;
        uint256 buybackPerpAmount = 180 ether;

        usdc.mint(address(perpBuyback), buybackUsdcAmount);
        vm.mockCall(
            perpBuybackPool,
            abi.encodeWithSelector(IPerpBuybackPool.swap.selector),
            abi.encode(buybackPerpAmount)
        );

        perpBuyback.swapInPerpBuybackPool();

        uint256 userClaimableVePerpAmount = perpBuyback.getUserClaimableVePerpAmount(user);
        assertEq(userClaimableVePerpAmount, 10 ether);

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
        address user = address(0x1);

        // swapInPerpBuybackPool (swap 1800 USD for 180 PERP)
        uint256 buybackUsdcAmount = 1_800 * 10**6;
        uint256 buybackPerpAmount = 180 ether;

        usdc.mint(address(perpBuyback), buybackUsdcAmount);
        vm.mockCall(
            perpBuybackPool,
            abi.encodeWithSelector(IPerpBuybackPool.swap.selector),
            abi.encode(buybackPerpAmount)
        );

        perpBuyback.swapInPerpBuybackPool();

        uint256 userClaimableVePerpAmount = perpBuyback.getUserClaimableVePerpAmount(user);
        assertEq(userClaimableVePerpAmount, 10 ether);

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

    function test_revert_claim_when_user_is_not_in_canClaimVePerpUsers() external {
        vm.expectRevert(bytes("PB_UINW"));
        perpBuyback.claim();
    }

    function test_revert_claim_when_user_claimable_amount_is_zero() external {
        address user = address(0x1);
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
        uint256 buybackUsdcAmount = 3_590_000 * 10**6;
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

    function test_getWhitelistUser() external {
        address[18] memory users = perpBuyback.getWhitelistUser();

        for (uint256 i = 0; i < 18; ++i) {
            assertEq(whitelistUser[i], users[i]);
        }
    }

    function test_isInWhitelist() external {
        for (uint256 i = 0; i < 18; ++i) {
            assertEq(perpBuyback.isInWhitelist(whitelistUser[i]), true);
        }
    }
}
