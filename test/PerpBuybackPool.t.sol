pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { PerpBuybackPool } from "../src/PerpBuybackPool.sol";
import { TestERC20 } from "../src/test/TestERC20.sol";
import { IPriceFeed } from "../src/interface/IPriceFeed.sol";
import { Vm } from "forge-std/Vm.sol";

contract PerpBuybackPoolTest is Test {
    TestERC20 public usdc;
    TestERC20 public perp;
    address public perpBuyback;
    address public perpChainlinkAggregator;

    PerpBuybackPool public perpBuybackPool;

    function makeContract(string memory contractName) public returns (address) {
        address contractAddr = makeAddr(contractName);
        vm.etch(contractAddr, bytes(contractName));
        return contractAddr;
    }

    function makeTestERC20(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public returns (TestERC20) {
        TestERC20 testErc20 = new TestERC20(name, symbol, decimals);
        vm.label(address(testErc20), name);
        return testErc20;
    }

    function setUp() external {
        usdc = makeTestERC20("USD Coin", "USDC", 6);

        perp = makeTestERC20("Perpetual", "PERP", 18);

        perpBuyback = makeContract("PerpBuyback");
        perpChainlinkAggregator = makeContract("PerpChainlinkAggregator");

        // mock perp price at 10 USD
        vm.mockCall(
            address(perpChainlinkAggregator),
            abi.encodeWithSelector(IPriceFeed.latestAnswer.selector),
            abi.encode(10 * 10**8)
        );

        perpBuybackPool = new PerpBuybackPool();
        perpBuybackPool.initialize(address(usdc), address(perp), perpChainlinkAggregator);

        perpBuybackPool.setPerpBuyback(perpBuyback);

        // prepare 1000 PERP in perpBuybackPool
        perp.mint(address(perpBuybackPool), 1000 ether);
    }

    function test_swap() external {
        uint256 usdcBuybackAmount = 420 * 10**6;
        usdc.mint(perpBuyback, usdcBuybackAmount);

        uint256 perpBuybackPoolPerpBalanceBefore = perp.balanceOf(address(perpBuybackPool));
        uint256 perpBuybackPoolUsdcBalanceBefore = usdc.balanceOf(address(perpBuybackPool));
        uint256 perpBuybackPerpBalanceBefore = perp.balanceOf(perpBuyback);
        uint256 perpBuybackUsdcBalanceBefore = usdc.balanceOf(perpBuyback);

        vm.startPrank(perpBuyback);
        // PERP price is 10 USD, 420 USD will swap for 42 PERP
        usdc.approve(address(perpBuybackPool), usdcBuybackAmount);
        uint256 perpBuybackAmount = perpBuybackPool.swap(usdcBuybackAmount);
        vm.stopPrank();

        uint256 perpBuybackPoolPerpBalanceAfter = perp.balanceOf(address(perpBuybackPool));
        uint256 perpBuybackPoolUsdcBalanceAfter = usdc.balanceOf(address(perpBuybackPool));
        uint256 perpBuybackPerpBalanceAfter = perp.balanceOf(perpBuyback);
        uint256 perpBuybackUsdcBalanceAfter = usdc.balanceOf(perpBuyback);

        assertEq(perpBuybackAmount, 42 ether);
        assertEq(perpBuybackPoolPerpBalanceBefore - perpBuybackPoolPerpBalanceAfter, perpBuybackAmount);
        assertEq(perpBuybackPoolUsdcBalanceAfter - perpBuybackPoolUsdcBalanceBefore, usdcBuybackAmount);
        assertEq(perpBuybackPerpBalanceAfter - perpBuybackPerpBalanceBefore, perpBuybackAmount);
        assertEq(perpBuybackUsdcBalanceBefore - perpBuybackUsdcBalanceAfter, usdcBuybackAmount);
    }

    function test_revert_swap_perp_balance_insufficient() external {
        // perpBuyBackPool has only 1000 PERP, PERP price is 10 USD, swap amount > 10000 USD will revert
        uint256 usdcBuybackAmount = 10001 * 10**6;
        usdc.mint(perpBuyback, usdcBuybackAmount);

        vm.startPrank(perpBuyback);
        usdc.approve(address(perpBuybackPool), usdcBuybackAmount);
        vm.expectRevert(bytes("PBP_PBI"));
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
