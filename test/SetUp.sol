pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { TestERC20 } from "../src/test/TestERC20.sol";

contract SetUp is Test {
    TestERC20 public usdc;
    TestERC20 public perp;

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

    function setUp() public virtual {
        usdc = makeTestERC20("USD Coin", "USDC", 6);

        perp = makeTestERC20("Perpetual", "PERP", 18);
    }
}
