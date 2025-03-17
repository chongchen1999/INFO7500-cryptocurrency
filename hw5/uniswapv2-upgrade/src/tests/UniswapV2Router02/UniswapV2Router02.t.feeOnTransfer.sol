// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./UniswapV2Router02.t.base.sol";

contract TestUniswapV2RouterFeeOnTransfer is UniswapV2RouterTestBase {
    function testSwapExactTokensForTokensSupportingFeeOnTransferTokens() public {
        vm.startPrank(user);
        feeToken.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        // Add initial liquidity for feeToken/tokenB
        router.addLiquidity(
            address(feeToken),
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
        path[0] = address(feeToken);
        path[1] = address(tokenB);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100 ether,
            1,
            path,
            user,
            block.timestamp + 1000
        );

        uint balanceBAfter = tokenB.balanceOf(user);
        assertGt(balanceBAfter, balanceBBefore, "User B balance should increase after fee swap");

        vm.stopPrank();
    }

    function testSwapExactETHForTokensSupportingFeeOnTransferTokens() public {
        vm.startPrank(user);
        feeToken.approve(address(router), type(uint).max);

        // Add initial feeToken/WETH liquidity
        router.addLiquidityETH{value: 10 ether}(
            address(feeToken),
            1000 ether,
            900 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(feeToken);

        uint balanceBefore = feeToken.balanceOf(user);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1 ether}(
            1,
            path,
            user,
            block.timestamp + 1000
        );

        uint balanceAfter = feeToken.balanceOf(user);
        assertGt(balanceAfter, balanceBefore, "User's FeeToken should increase");

        vm.stopPrank();
    }

    function testSwapExactTokensForETHSupportingFeeOnTransferTokens() public {
        vm.startPrank(user);
        feeToken.approve(address(router), type(uint).max);

        // Add initial feeToken/WETH liquidity
        router.addLiquidityETH{value: 5 ether}(
            address(feeToken),
            1000 ether,
            900 ether,
            4 ether,
            user,
            block.timestamp + 1000
        );

        address[] memory path = new address[](2);
        path[0] = address(feeToken);
        path[1] = address(weth);

        uint balanceETHBefore = user.balance;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            100 ether,
            1,
            path,
            user,
            block.timestamp + 1000
        );

        uint balanceETHAfter = user.balance;
        assertGt(balanceETHAfter, balanceETHBefore, "User's ETH should increase");

        vm.stopPrank();
    }
}