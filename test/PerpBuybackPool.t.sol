pragma solidity 0.8.17;

import { SetUp } from "./SetUp.sol";
import { PerpBuybackPool } from "../src/PerpBuybackPool.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.6/interfaces/AggregatorV2V3Interface.sol";

contract PerpBuybackPoolTest is SetUp {
    address public perpBuyback;
    address public perpChainlinkAggregator;

    PerpBuybackPool public perpBuybackPool;

    function setUp() public override {
        SetUp.setUp();

        perpBuyback = makeContract("PerpBuyback");
        perpChainlinkAggregator = makeContract("PerpChainlinkAggregator");

        // mock perpChainlinkAggregator price at 10 USD and decimals at 8
        // not sure why using AggregatorV2V3Interface will failed here, so separate interface first
        vm.mockCall(
            perpChainlinkAggregator,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(0, 10 * 1e8, block.timestamp, block.timestamp, 0)
        );
        vm.mockCall(
            perpChainlinkAggregator,
            abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
            abi.encode(8)
        );

        perpBuybackPool = new PerpBuybackPool();
        perpBuybackPool.initialize(address(usdc), address(perp), perpChainlinkAggregator);

        perpBuybackPool.setPerpBuyback(perpBuyback);

        // prepare 1000 PERP in perpBuybackPool
        perp.mint(address(perpBuybackPool), 1000 ether);
    }

    function test_swap(uint256 perpPriceLatestAnswer) external {
        // assume perp price is between 0.1U ~ 10U
        perpPriceLatestAnswer = bound(perpPriceLatestAnswer, 0.1e8, 10e8);
        vm.mockCall(
            perpChainlinkAggregator,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(0, perpPriceLatestAnswer, block.timestamp, block.timestamp, 0)
        );

        uint256 usdcBuybackAmount = 42 * 10 ** 6;
        usdc.mint(perpBuyback, usdcBuybackAmount);

        uint256 perpBuybackPoolPerpBalanceBefore = perp.balanceOf(address(perpBuybackPool));
        uint256 perpBuybackPoolUsdcBalanceBefore = usdc.balanceOf(address(perpBuybackPool));
        uint256 perpBuybackPerpBalanceBefore = perp.balanceOf(perpBuyback);
        uint256 perpBuybackUsdcBalanceBefore = usdc.balanceOf(perpBuyback);

        vm.startPrank(perpBuyback);
        usdc.approve(address(perpBuybackPool), usdcBuybackAmount);
        uint256 perpBuybackAmount = perpBuybackPool.swap(usdcBuybackAmount);
        vm.stopPrank();

        uint256 perpBuybackPoolPerpBalanceAfter = perp.balanceOf(address(perpBuybackPool));
        uint256 perpBuybackPoolUsdcBalanceAfter = usdc.balanceOf(address(perpBuybackPool));
        uint256 perpBuybackPerpBalanceAfter = perp.balanceOf(perpBuyback);
        uint256 perpBuybackUsdcBalanceAfter = usdc.balanceOf(perpBuyback);

        // expectedPerpBuybackAmount = usdcBuybackAmount * 1e12 * 1e8 / perpPriceLatestAnswer
        uint256 expectedPerpBuybackAmount = (usdcBuybackAmount * 1e20) / perpPriceLatestAnswer;
        assertEq(perpBuybackAmount, expectedPerpBuybackAmount);
        assertEq(perpBuybackPoolPerpBalanceBefore - perpBuybackPoolPerpBalanceAfter, perpBuybackAmount);
        assertEq(perpBuybackPoolUsdcBalanceAfter - perpBuybackPoolUsdcBalanceBefore, usdcBuybackAmount);
        assertEq(perpBuybackPerpBalanceAfter - perpBuybackPerpBalanceBefore, perpBuybackAmount);
        assertEq(perpBuybackUsdcBalanceBefore - perpBuybackUsdcBalanceAfter, usdcBuybackAmount);
    }

    function test_swap_less_than_1() external {
        // given perp price is 0.1, chainlink decimal is 8
        vm.mockCall(
            perpChainlinkAggregator,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(0, 0.1e8, block.timestamp, block.timestamp, 0)
        );

        // given Buyback has 42 USDC (6 decimals), 0 PERP (18 decimals)
        uint256 usdcBuybackAmount = 42 * 10 ** 6;
        usdc.mint(perpBuyback, usdcBuybackAmount);
        assertEq(usdc.balanceOf(address(perpBuyback)), usdcBuybackAmount);
        assertEq(perp.balanceOf(address(perpBuyback)), 0);

        // when Buyback swap 42 USDC to 420 PERP (18 decimals) at price 0.1
        vm.startPrank(perpBuyback);
        usdc.approve(address(perpBuybackPool), usdcBuybackAmount);
        assertEq(perpBuybackPool.swap(usdcBuybackAmount), 420 * 10 ** 18);
        vm.stopPrank();

        // then Buyback has 0 USDC, 420 PERP
        assertEq(usdc.balanceOf(address(perpBuyback)), 0);
        assertEq(perp.balanceOf(address(perpBuyback)), 420 * 10 ** 18);
    }

    function test_swap_greater_than_1() external {
        // given perp price is 1.5, chainlink decimal is 8
        vm.mockCall(
            perpChainlinkAggregator,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(0, 1.5e8, block.timestamp, block.timestamp, 0)
        );

        // given Buyback has 42 USDC (6 decimals), 0 PERP (18 decimals)
        uint256 usdcBuybackAmount = 42 * 10 ** 6;
        usdc.mint(perpBuyback, usdcBuybackAmount);
        assertEq(usdc.balanceOf(address(perpBuyback)), usdcBuybackAmount);
        assertEq(perp.balanceOf(address(perpBuyback)), 0);

        // when Buyback swap 42 USDC to 28 PERP (18 decimals) at price 1.5
        vm.startPrank(perpBuyback);
        usdc.approve(address(perpBuybackPool), usdcBuybackAmount);
        assertEq(perpBuybackPool.swap(usdcBuybackAmount), 28 * 10 ** 18);
        vm.stopPrank();

        // then Buyback has 0 USDC, 28 PERP
        assertEq(usdc.balanceOf(address(perpBuyback)), 0);
        assertEq(perp.balanceOf(address(perpBuyback)), 28 * 10 ** 18);
    }

    function test_revert_swap_perp_balance_insufficient() external {
        // perpBuyBackPool has only 1000 PERP, PERP price is 10 USD, swap amount > 10000 USD will revert
        uint256 usdcBuybackAmount = 10001 * 10 ** 6;
        usdc.mint(perpBuyback, usdcBuybackAmount);

        vm.startPrank(perpBuyback);
        usdc.approve(address(perpBuybackPool), usdcBuybackAmount);
        vm.expectRevert(bytes("PBP_PBI"));
        perpBuybackPool.swap(usdcBuybackAmount);
        vm.stopPrank();
    }

    function test_revert_swap_stale_price() external {
        vm.mockCall(
            perpChainlinkAggregator,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(0, 0 * 10 ** 8, block.timestamp, block.timestamp, 0)
        );

        // forward block.timestamp to 1 day + 1 minute later
        vm.warp(86400 + 60);

        vm.startPrank(perpBuyback);
        vm.expectRevert(bytes("PBP_SP"));
        perpBuybackPool.swap(1);
        vm.stopPrank();
    }

    function test_revert_swap_perp_oracle_is_zero() external {
        vm.mockCall(
            perpChainlinkAggregator,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(0, 0 * 10 ** 8, block.timestamp, block.timestamp, 0)
        );

        uint256 usdcBuybackAmount = 10 * 10 ** 6;
        usdc.mint(perpBuyback, usdcBuybackAmount);

        vm.startPrank(perpBuyback);
        usdc.approve(address(perpBuybackPool), usdcBuybackAmount);
        vm.expectRevert(bytes("PBP_OIZ"));
        perpBuybackPool.swap(usdcBuybackAmount);
        vm.stopPrank();
    }

    function test_revert_swap_not_perpBuyBack() external {
        vm.expectRevert(bytes("PBP_OPB"));
        vm.prank(address(0x42));
        perpBuybackPool.swap(42);
    }

    function test_withdrawToken() external {
        address perpBuybackPoolOwner = perpBuybackPool.owner();
        uint256 withdrawAmount = 42 ether;

        uint256 ownerPerpBalanceBefore = perp.balanceOf(perpBuybackPoolOwner);
        perpBuybackPool.withdrawToken(address(perp), withdrawAmount);

        uint256 ownerPerpBalanceAfter = perp.balanceOf(perpBuybackPoolOwner);
        assertEq(ownerPerpBalanceAfter - ownerPerpBalanceBefore, withdrawAmount);
    }

    function test_revert_withdrawToken_when_not_owner() external {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vm.prank(address(0x42));
        perpBuybackPool.withdrawToken(address(perp), 42 ether);
    }

    function test_withdrawAllToken() external {
        address perpBuybackPoolOwner = perpBuybackPool.owner();

        uint256 ownerPerpBalanceBefore = perp.balanceOf(perpBuybackPoolOwner);
        perpBuybackPool.withdrawAllToken(address(perp));

        uint256 ownerPerpBalanceAfter = perp.balanceOf(perpBuybackPoolOwner);

        // initial perpBuybackPool has 1000 PERP
        assertEq(ownerPerpBalanceAfter - ownerPerpBalanceBefore, 1000 ether);
    }

    function test_revert_withdrawAllToken_when_not_owner() external {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vm.prank(address(0x42));
        perpBuybackPool.withdrawAllToken(address(perp));
    }

    function test_revert_setPerpBuyback_when_not_owner() external {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vm.prank(address(0x42));
        perpBuybackPool.setPerpBuyback(perpBuyback);
    }

    function test_revert_setPerpBuyback_when_not_contract() external {
        vm.expectRevert(bytes("PBP_PBINC"));
        perpBuybackPool.setPerpBuyback(address(0x42));
    }

    function test_getUsdc() external {
        assertEq(perpBuybackPool.getUsdc(), address(usdc));
    }

    function test_getPerp() external {
        assertEq(perpBuybackPool.getPerp(), address(perp));
    }

    function test_getPerpBuyback() external {
        assertEq(perpBuybackPool.getPerpBuyback(), perpBuyback);
    }

    function test_getPerpChainlinkAggregator() external {
        assertEq(perpBuybackPool.getPerpChainlinkAggregator(), perpChainlinkAggregator);
    }
}
