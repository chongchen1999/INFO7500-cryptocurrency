// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./UniswapV2Router02.t.base.sol";

contract TestUniswapV2RouterSwap is UniswapV2RouterTestBase {
    function testSwapExactTokensForTokens() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        // Add initial liquidity
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            1000 ether,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );

        uint balanceBBefore = tokenB.balanceOf(user);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        router.swapExactTokensForTokens(
            100 ether,
            1,
            path,
            user,
            block.timestamp + 1000
        );

        uint balanceBAfter = tokenB.balanceOf(user);
        assertGt(balanceBAfter, balanceBBefore, "User B balance should increase");

        vm.stopPrank();
    }

    function testSwapTokensForExactTokens() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        // Add initial liquidity
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            1000 ether,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint[] memory amounts = router.swapTokensForExactTokens(
            200 ether,
            300 ether,
            path,
            user,
            block.timestamp + 1000
        );

        assertLe(amounts[0], 300 ether, "Spent too many TokenA");
        assertEq(amounts[1], 200 ether, "Did not get exact B");
        vm.stopPrank();
    }

    function testSwapExactTokensForETH() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);

        // Add initial TokenA/WETH liquidity
        router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            1000 ether,
            1000 ether,
            10 ether,
            user,
            block.timestamp + 1000
        );

        uint balanceETHBefore = user.balance;

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);

        router.swapExactTokensForETH(
            100 ether,
            1,
            path,
            user,
            block.timestamp + 1000
        );

        uint balanceETHAfter = user.balance;
        assertGt(balanceETHAfter, balanceETHBefore, "User's ETH balance should increase");

        vm.stopPrank();
    }

    function testSwapTokensForExactETH() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);

        // Add initial TokenA/WETH liquidity
        router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            1000 ether,
            900 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );

        uint balanceETHBefore = user.balance;

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);

        uint[] memory amounts = router.swapTokensForExactETH(
            2 ether,
            500 ether,
            path,
            user,
            block.timestamp + 1000
        );

        assertEq(amounts[1], 2 ether, "Did not get exact 2 ETH");
        assertLe(amounts[0], 500 ether, "Spent too many TokenA");

        uint balanceETHAfter = user.balance;
        assertEq(balanceETHAfter, balanceETHBefore + 2 ether, "ETH not correct");

        vm.stopPrank();
    }

    function testSwapExactETHForTokens() public {
        vm.startPrank(user);
        tokenB.approve(address(router), type(uint).max);

        // Add initial TokenB/WETH liquidity
        router.addLiquidityETH{value: 10 ether}(
            address(tokenB),
            1000 ether,
            900 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );

        uint balanceBBefore = tokenB.balanceOf(user);

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenB);

        router.swapExactETHForTokens{value: 1 ether}(
            1,
            path,
            user,
            block.timestamp + 1000
        );

        uint balanceBAfter = tokenB.balanceOf(user);
        assertGt(balanceBAfter, balanceBBefore, "User B balance should increase");

        vm.stopPrank();
    }

    function testSwapETHForExactTokens() public {
        vm.startPrank(user);
        tokenB.approve(address(router), type(uint).max);

        // Add initial TokenB/WETH liquidity
        router.addLiquidityETH{value: 10 ether}(
            address(tokenB),
            1000 ether,
            900 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );

        uint balanceBBefore = tokenB.balanceOf(user);

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenB);

        uint[] memory amounts = router.swapETHForExactTokens{value: 2 ether}(
            100 ether,
            path,
            user,
            block.timestamp + 1000
        );

        assertEq(amounts[1], 100 ether, "Did not get exact TokenB");
        assertLe(amounts[0], 2 ether, "Spent too many ETH");

        uint balanceBAfter = tokenB.balanceOf(user);
        assertEq(balanceBAfter, balanceBBefore + 100 ether, "User B balance mismatch");

        vm.stopPrank();
    }

    // Negative test cases
    function testSwapRevertInvalidPath() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);

        address[] memory path = new address[](1);
        path[0] = address(tokenA);

        vm.expectRevert(); 
        router.swapExactTokensForTokens(100 ether, 1, path, user, block.timestamp + 1000);

        vm.stopPrank();
    }

    function testSwapRevertDeadlineExpired() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.expectRevert(); 
        router.swapExactTokensForTokens(100 ether, 1, path, user, block.timestamp - 1);

        vm.stopPrank();
    }
}