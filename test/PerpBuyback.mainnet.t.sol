pragma solidity 0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPerpBuybackPool } from "../src/interface/IPerpBuybackPool.sol";
import { IPerpBuybackEvent } from "../src/interface/IPerpBuyback.sol";
import { IVePerp } from "../src/interface/IVePerp.sol";
import { PerpBuyback } from "../src/PerpBuyback.sol";
import { SetUp } from "./SetUp.sol";

contract PerpBuybackMainnetTest is IPerpBuybackEvent, SetUp {
    uint256 private constant WEEK = 7 * 86400;
    address public constant USDC = address(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    address public constant PERP = address(0x9e1028F5F1D5eDE59748FFceE5532509976840E0);

    address public vePerp;
    address public perpBuybackPool;
    PerpBuyback public perpBuyback;

    function setUp() public override {
        vm.createSelectFork(vm.envString("OPTIMISM_WEB3_ENDPOINT_ARCHIVE"), 108842000);

        SetUp.setUp();

        perpBuybackPool = makeContract("PerpBuybackPool");
        vePerp = makeContract("VePerp");

        perpBuyback = new PerpBuyback();
        perpBuyback.initialize(USDC, PERP, address(vePerp), perpBuybackPool);
    }

    function test_swapInUniswapV3Pool() public {
        uint256 buybackUsdcAmount = 1_800 * 10 ** 6;
        deal(USDC, address(perpBuyback), buybackUsdcAmount, true);

        uint256 beforeRemainingAmount = perpBuyback.getRemainingBuybackUsdcAmount();

        // 1800 USDC can swap to 4357.247957568872865183 PERP
        uint256 buybackPerpAmount = 4357247957568872865183;
        vm.expectEmit(false, false, false, true, address(perpBuyback));
        emit BuybackTriggered(buybackUsdcAmount, buybackPerpAmount);

        perpBuyback.swapInUniswapV3Pool();

        uint256 afterRemainingAmount = perpBuyback.getRemainingBuybackUsdcAmount();

        assertEq(beforeRemainingAmount - afterRemainingAmount, buybackUsdcAmount);
        assertEq(IERC20(PERP).balanceOf(address(perpBuyback)), buybackPerpAmount);
    }

    function test_revert_swapInUniswapV3Pool_not_owner() public {
        address notOwner = makeAddr("NotOwner");

        vm.prank(notOwner);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        perpBuyback.swapInUniswapV3Pool();
    }
}
