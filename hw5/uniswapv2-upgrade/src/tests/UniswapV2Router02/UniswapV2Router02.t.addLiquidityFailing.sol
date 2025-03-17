// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "src/tests/UniswapV2Router02/UniswapV2Router02.t.base.sol";
import "src/tests/mocks/MockFailingPair.sol"; // Make sure to save the previous contract in this file

contract TestUniswapV2RouterAddLiquidityFailing is UniswapV2RouterTestBase {
    MockFailingPair public failingPair;
    MockFailingFactory public mockFactory;
    UniswapV2Router02 public routerWithMockFactory;

    function setUp() public override {
        super.setUp();
        
        // Deploy the failing pair and factory
        failingPair = new MockFailingPair();
        mockFactory = new MockFailingFactory(address(failingPair));
        
        // Deploy a new router that uses the mock factory
        routerWithMockFactory = new UniswapV2Router02(
            address(mockFactory),
            address(weth)
        );
    }

    function testAddLiquidity_WithFailingGetReserves() public {
        vm.startPrank(user);
        tokenA.approve(address(routerWithMockFactory), type(uint).max);
        tokenB.approve(address(routerWithMockFactory), type(uint).max);

        // This will trigger the catch block because getReserves() will fail
        (uint amountA, uint amountB, uint liquidity) = routerWithMockFactory.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            2000 ether,
            900 ether,
            1800 ether,
            user,
            block.timestamp + 1000
        );

        // Since getReserves failed, it should treat it as an empty pool
        assertEq(amountA, 1000 ether, "amountA should be equal to desired amount");
        assertEq(amountB, 2000 ether, "amountB should be equal to desired amount");
        assertEq(liquidity, 100, "liquidity should be 100 (from mock)");

        vm.stopPrank();
    }
}