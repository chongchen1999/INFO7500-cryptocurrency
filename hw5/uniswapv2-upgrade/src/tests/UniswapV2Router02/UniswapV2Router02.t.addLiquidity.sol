// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./UniswapV2Router02.t.base.sol";

contract TestUniswapV2RouterAddLiquidity is UniswapV2RouterTestBase {
    function testAddLiquidity() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            2000 ether,
            900 ether,
            1800 ether,
            user,
            block.timestamp + 1000
        );

        assertEq(amountA, 1000 ether, "amountA mismatch");
        assertEq(amountB, 2000 ether, "amountB mismatch");
        assertGt(liquidity, 0, "liquidity should be > 0");

        vm.stopPrank();
    }

    function testAddLiquidityETH() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);

        (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{
            value: 10 ether
        }(
            address(tokenA),
            100 ether,   // amountTokenDesired
            50 ether,    // amountTokenMin
            5 ether,     // amountETHMin
            user,
            block.timestamp + 1000
        );

        assertEq(amountToken, 100 ether, "Token used mismatch");
        assertEq(amountETH, 10 ether, "ETH used mismatch");
        assertGt(liquidity, 0, "Liquidity minted");
        vm.stopPrank();
    }

    function testAddLiquidity_CoverAllBranches() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        // First liquidity addition (empty pool)
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            2000 ether,
            1000 ether,
            2000 ether,
            user,
            block.timestamp + 1000
        );

        // Second addition: trigger "amountBOptimal <= amountBDesired"
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,   // amountADesired
            300 ether,   // amountBDesired
            70 ether,    // amountAMin
            200 ether,   // amountBMin
            user,
            block.timestamp + 1000
        );

        // Third addition: trigger "amountBOptimal > amountBDesired"
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,   // amountADesired
            150 ether,   // amountBDesired
            70 ether,    // amountAMin
            150 ether,   // amountBMin
            user,
            block.timestamp + 1000
        );

        vm.stopPrank();
    }
}