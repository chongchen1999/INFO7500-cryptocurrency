// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./UniswapV2Router02BasicTest.sol";

contract UniswapV2Router02SwapTest is UniswapV2Router02BasicTest {
    address public pair;
    ERC20Mock public tokenC;
    
    function setUp() public override {
        super.setUp();
        
        // Add initial liquidity for token pair A-B
        uint256 amountA = 1000 ether;
        uint256 amountB = 1000 ether;
        uint256 deadline = block.timestamp + 1 hours;
        
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            owner,
            deadline
        );
        
        pair = factory.getPair(address(tokenA), address(tokenB));
        
        // Add initial liquidity for ETH pair
        vm.deal(owner, 100 ether);
        router.addLiquidityETH{value: 50 ether}(
            address(tokenA),
            500 ether,
            0,
            0,
            owner,
            deadline
        );
        
        // Create third token for multi-hop tests
        tokenC = new ERC20Mock("Token C", "TKC", INITIAL_SUPPLY);
        tokenC.approve(address(router), type(uint256).max);
        
        // Add liquidity for B-C pair
        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            amountB,
            1000 ether,
            0,
            0,
            owner,
            deadline
        );
    }
    
    function testSwapExactTokensForTokens() public {
        uint256 amountIn = 10 ether;
        uint256 amountOutMin = 1;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        uint256 deadline = block.timestamp + 1 hours;
        
        // Check balances before
        uint256 tokenABalanceBefore = tokenA.balanceOf(owner);
        uint256 tokenBBalanceBefore = tokenB.balanceOf(owner);
        
        // Get expected amount out
        uint256[] memory amountsOut = router.getAmountsOut(amountIn, path);
        
        // Swap tokens
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            owner,
            deadline
        );
        
        // Verify balances after
        assertEq(tokenA.balanceOf(owner), tokenABalanceBefore - amountIn, "TokenA amount incorrect");
        assertEq(tokenB.balanceOf(owner), tokenBBalanceBefore + amounts[1], "TokenB amount incorrect");
        assertEq(amounts[0], amountIn, "Input amount incorrect");
        assertEq(amounts[1], amountsOut[1], "Output amount incorrect");
        
        // Test with insufficient output
        uint256 highAmountOutMin = 1000 ether;
        
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        router.swapExactTokensForTokens(
            amountIn,
            highAmountOutMin,
            path,
            owner,
            deadline
        );
        
        // Test multi-hop swap
        address[] memory multiPath = new address[](3);
        multiPath[0] = address(tokenA);
        multiPath[1] = address(tokenB);
        multiPath[2] = address(tokenC);
        
        uint256 tokenCBalanceBefore = tokenC.balanceOf(owner);
        
        // Get expected amounts
        uint256[] memory multiAmountsOut = router.getAmountsOut(amountIn, multiPath);
        
        // Execute multi-hop swap
        uint256[] memory multiAmounts = router.swapExactTokensForTokens(
            amountIn,
            1,
            multiPath,
            owner,
            deadline
        );
        
        // Verify balances
        assertEq(tokenA.balanceOf(owner), tokenABalanceBefore - amountIn * 2, "TokenA amount incorrect after multi-hop");
        assertEq(tokenC.balanceOf(owner), tokenCBalanceBefore + multiAmounts[2], "TokenC amount incorrect");
        assertEq(multiAmounts[0], amountIn, "Input amount incorrect");
        assertEq(multiAmounts[2], multiAmountsOut[2], "Output amount incorrect");
    }
    
    function testSwapTokensForExactTokens() public {
        uint256 amountOut = 5 ether;
        uint256 amountInMax = 10 ether;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        uint256 deadline = block.timestamp + 1 hours;
        
        // Check balances before
        uint256 tokenABalanceBefore = tokenA.balanceOf(owner);
        uint256 tokenBBalanceBefore = tokenB.balanceOf(owner);
        
        // Get expected amount in
        uint256[] memory amountsIn = router.getAmountsIn(amountOut, path);
        
        // Swap tokens
        uint256[] memory amounts = router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            owner,
            deadline
        );
        
        // Verify balances after
        assertEq(tokenA.balanceOf(owner), tokenABalanceBefore - amounts[0], "TokenA amount incorrect");
        assertEq(tokenB.balanceOf(owner), tokenBBalanceBefore + amountOut, "TokenB amount incorrect");
        assertEq(amounts[1], amountOut, "Output amount incorrect");
        assertEq(amounts[0], amountsIn[0], "Input amount incorrect");
        
        // Test with excessive input amount
        uint256 lowAmountInMax = 1; // Very low maximum
        
        vm.expectRevert("UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        router.swapTokensForExactTokens(
            amountOut,
            lowAmountInMax,
            path,
            owner,
            deadline
        );
        
        // Test multi-hop swap
        address[] memory multiPath = new address[](3);
        multiPath[0] = address(tokenA);
        multiPath[1] = address(tokenB);
        multiPath[2] = address(tokenC);
        
        uint256 tokenCBalanceBefore = tokenC.balanceOf(owner);
        
        // Execute multi-hop swap
        amounts = router.swapTokensForExactTokens(
            amountOut,
            amountInMax * 2,
            multiPath,
            owner,
            deadline
        );
        
        // Verify output
        assertEq(tokenC.balanceOf(owner), tokenCBalanceBefore + amountOut, "TokenC amount incorrect after multi-hop");
    }
    
    function testSwapExactETHForTokens() public {
        uint256 ethAmount = 1 ether;
        uint256 amountOutMin = 1;
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);
        uint256 deadline = block.timestamp + 1 hours;
        
        // Check balances before
        uint256 tokenABalanceBefore = tokenA.balanceOf(owner);
        uint256 ethBalanceBefore = address(owner).balance;
        
        // Deal ETH to owner
        vm.deal(owner, ethAmount + ethBalanceBefore);
        
        // Get expected amount out
        uint256[] memory amountsOut = router.getAmountsOut(ethAmount, path);
        
        // Swap ETH for tokens
        uint256[] memory amounts = router.swapExactETHForTokens{value: ethAmount}(
            amountOutMin,
            path,
            owner,
            deadline
        );
        
        // Verify balances after
        assertEq(tokenA.balanceOf(owner), tokenABalanceBefore + amounts[1], "TokenA amount incorrect");
        assertEq(address(owner).balance, ethBalanceBefore, "ETH amount incorrect");
        assertEq(amounts[0], ethAmount, "Input amount incorrect");
        assertEq(amounts[1], amountsOut[1], "Output amount incorrect");
        
        // Test with invalid path
        path[0] = address(tokenA); // Should be WETH
        
        vm.expectRevert("UniswapV2Router: INVALID_PATH");
        router.swapExactETHForTokens{value: ethAmount}(
            amountOutMin,
            path,
            owner,
            deadline
        );
    }
    
    function testSwapTokensForExactETH() public {
        uint256 ethAmountOut = 1 ether;
        uint256 amountInMax = 20 ether;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);
        uint256 deadline = block.timestamp + 1 hours;
        
        // Check balances before
        uint256 tokenABalanceBefore = tokenA.balanceOf(owner);
        uint256 ethBalanceBefore = address(owner).balance;
        
        // Get expected amount in
        uint256[] memory amountsIn = router.getAmountsIn(ethAmountOut, path);
        
        // Swap tokens for ETH
        uint256[] memory amounts = router.swapTokensForExactETH(
            ethAmountOut,
            amountInMax,
            path,
            owner,
            deadline
        );
        
        // Verify balances after
        assertEq(tokenA.balanceOf(owner), tokenABalanceBefore - amounts[0], "TokenA amount incorrect");
        assertEq(address(owner).balance, ethBalanceBefore + ethAmountOut, "ETH amount incorrect");
        assertEq(amounts[1], ethAmountOut, "Output amount incorrect");
        assertEq(amounts[0], amountsIn[0], "Input amount incorrect");
        
        // Test with invalid path
        path[1] = address(tokenB); // Should end with WETH
        
        vm.expectRevert("UniswapV2Router: INVALID_PATH");
        router.swapTokensForExactETH(
            ethAmountOut,
            amountInMax,
            path,
            owner,
            deadline
        );
    }
    
    function testSwapExactTokensForETH() public {
        uint256 amountIn = 10 ether;
        uint256 amountOutMin = 1;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);
        uint256 deadline = block.timestamp + 1 hours;
        
        // Check balances before
        uint256 tokenABalanceBefore = tokenA.balanceOf(owner);
        uint256 ethBalanceBefore = address(owner).balance;
        
        // Get expected amount out
        uint256[] memory amountsOut = router.getAmountsOut(amountIn, path);
        
        // Swap tokens for ETH
        uint256[] memory amounts = router.swapExactTokensForETH(
            amountIn,
            amountOutMin,
            path,
            owner,
            deadline
        );
        
        // Verify balances after
        assertEq(tokenA.balanceOf(owner), tokenABalanceBefore - amountIn, "TokenA amount incorrect");
        assertEq(address(owner).balance, ethBalanceBefore + amounts[1], "ETH amount incorrect");
        assertEq(amounts[0], amountIn, "Input amount incorrect");
        assertEq(amounts[1], amountsOut[1], "Output amount incorrect");
        
        // Test with invalid path
        path[1] = address(tokenB); // Should end with WETH
        
        vm.expectRevert("UniswapV2Router: INVALID_PATH");
        router.swapExactTokensForETH(
            amountIn,
            amountOutMin,
            path,
            owner,
            deadline
        );
    }
    
    function testSwapETHForExactTokens() public {
        uint256 amountOut = 5 ether;
        uint256 ethAmountIn = 2 ether;
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);
        uint256 deadline = block.timestamp + 1 hours;
        
        // Check balances before
        uint256 tokenABalanceBefore = tokenA.balanceOf(owner);
        uint256 ethBalanceBefore = address(owner).balance;
        
        // Deal ETH to owner
        vm.deal(owner, ethAmountIn * 2 + ethBalanceBefore);
        
        // Get expected amount in
        uint256[] memory amountsIn = router.getAmountsIn(amountOut, path);
        
        // Swap ETH for exact tokens
        uint256[] memory amounts = router.swapETHForExactTokens{value: ethAmountIn}(
            amountOut,
            path,
            owner,
            deadline
        );
        
        // Verify balances after
        assertEq(tokenA.balanceOf(owner), tokenABalanceBefore + amountOut, "TokenA amount incorrect");
        // ETH balance will be: original + deal - used + refund
        assertEq(address(owner).balance, ethBalanceBefore + ethAmountIn * 2 - amounts[0], "ETH amount incorrect");
        assertEq(amounts[1], amountOut, "Output amount incorrect");
        assertEq(amounts[0], amountsIn[0], "Input amount incorrect");
        
        // Test with insufficient input
        uint256 lowEthAmount = 0.0001 ether;
        
        vm.expectRevert("UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        router.swapETHForExactTokens{value: lowEthAmount}(
            amountOut,
            path,
            owner,
            deadline
        );
        
        // Test with invalid path
        path[0] = address(tokenA); // Should be WETH
        
        vm.expectRevert("UniswapV2Router: INVALID_PATH");
        router.swapETHForExactTokens{value: ethAmountIn}(
            amountOut,
            path,
            owner,
            deadline
        );
    }
}