// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "src/periphery/UniswapV2Router02.sol";
import "src/test/mocks/MockWETH.sol";
import "src/test/mocks/MockFactory.sol";

contract UniswapV2Router02LibraryTest is Test {
    UniswapV2Router02 public router;
    MockWETH public weth;
    MockFactory public factory;

    function setUp() public {
        weth = new MockWETH();
        factory = new MockFactory();
        router = new UniswapV2Router02(address(factory), address(weth));
    }

    function testQuote() public {
        // Test basic quote calculation
        uint amountA = 100;
        uint reserveA = 1000;
        uint reserveB = 2000;
        
        uint amountB = router.quote(amountA, reserveA, reserveB);
        assertEq(amountB, 200, "Quote calculation incorrect");
        
        // Test quote with zero amount
        vm.expectRevert("UniswapV2Library: INSUFFICIENT_AMOUNT");
        router.quote(0, reserveA, reserveB);
        
        // Test quote with zero reserves
        vm.expectRevert("UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        router.quote(amountA, 0, reserveB);
        
        vm.expectRevert("UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        router.quote(amountA, reserveA, 0);
    }

    function testGetAmountOut() public {
        uint amountIn = 100;
        uint reserveIn = 1000;
        uint reserveOut = 2000;
        
        // Test basic amount out calculation
        uint amountOut = router.getAmountOut(amountIn, reserveIn, reserveOut);
        assertTrue(amountOut > 0, "Amount out should be greater than 0");
        
        // Test with zero amount in
        vm.expectRevert("UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        router.getAmountOut(0, reserveIn, reserveOut);
        
        // Test with zero reserves
        vm.expectRevert("UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        router.getAmountOut(amountIn, 0, reserveOut);
        
        vm.expectRevert("UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        router.getAmountOut(amountIn, reserveIn, 0);
    }

    function testGetAmountIn() public {
        uint amountOut = 100;
        uint reserveIn = 2000;
        uint reserveOut = 1000;
        
        // Test basic amount in calculation
        uint amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut);
        assertTrue(amountIn > 0, "Amount in should be greater than 0");
        
        // Test with zero amount out
        vm.expectRevert("UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        router.getAmountIn(0, reserveIn, reserveOut);
        
        // Test with zero reserves
        vm.expectRevert("UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        router.getAmountIn(amountOut, 0, reserveOut);
        
        vm.expectRevert("UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        router.getAmountIn(amountOut, reserveIn, 0);
    }
}