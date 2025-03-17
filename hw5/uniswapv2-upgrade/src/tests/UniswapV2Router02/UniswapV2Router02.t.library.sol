// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./UniswapV2Router02.t.base.sol";

contract TestUniswapV2RouterLibrary is UniswapV2RouterTestBase {
    function testQuote() public view {
        uint amountB = router.quote(100, 1000, 2000);
        assertEq(amountB, 200, "quote mismatch");
    }

    function testQuoteRevert_ReserveAZero() public {
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.quote(100, 0, 2000);
    }

    function testGetAmountOut() public view {
        uint out = router.getAmountOut(100, 1000, 2000);
        assertEq(out, 181, "getAmountOut mismatch");
    }

    function testGetAmountOutRevert_ZeroAmountIn() public {
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT"));
        router.getAmountOut(0, 1000, 2000);
    }

    function testGetAmountOutRevert_ZeroReserves() public {
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.getAmountOut(100, 0, 2000);

        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.getAmountOut(100, 1000, 0);
    }

    function testGetAmountIn() public view {
        uint inAmt = router.getAmountIn(200, 1000, 2000);
        assertEq(inAmt, 112, "getAmountIn mismatch");
    }

    function testGetAmountInRevert_ZeroAmountOut() public {
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT"));
        router.getAmountIn(0, 1000, 2000);
    }

    function testGetAmountInRevert_ZeroReserves() public {
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.getAmountIn(200, 0, 2000);

        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.getAmountIn(200, 1000, 0);
    }

    function testGetAmountsOut_SingleHop() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            2000 ether,
            900 ether,
            1800 ether,
            user,
            block.timestamp + 1000
        );
        vm.stopPrank();

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint[] memory amounts = router.getAmountsOut(100 ether, path);
        assertEq(amounts[0], 100 ether, "input mismatch");
        assertGt(amounts[1], 0, "output should be > 0");
    }

    function testGetAmountsOut_MultiHop() public {
        // Add A-WETH, WETH-B liquidity
        vm.startPrank(user);

        // 1) First deposit native ETH into WETH
        //    For example, need about 20~30 ETH for liquidity, estimate yourself
        weth.deposit{value: 20 ether}();

        // 2) approve
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);
        weth.approve(address(router), type(uint).max);

        // 3) Add A-WETH liquidity
        //    Don't write 1000 ether, it's too large, user only has 20 WETH
        router.addLiquidity(
            address(tokenA),
            address(weth),
            10 ether,   // amountTokenDesired
            10 ether,   // amountWETHDesired
            9 ether,    // amountTokenMin
            9 ether,    // amountWETHMin
            user,
            block.timestamp + 1000
        );

        // 4) Add WETH-B liquidity
        router.addLiquidity(
            address(weth),
            address(tokenB),
            10 ether,   // amountWETHDesired
            20 ether,   // amountBDesired
            9 ether,
            18 ether,
            user,
            block.timestamp + 1000
        );

        vm.stopPrank();

        // 5) Construct multi-hop path A->WETH->B, then
        //    router.getAmountsOut(1 ether, path) etc.
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(weth);
        path[2] = address(tokenB);

        uint[] memory amounts = router.getAmountsOut(1 ether, path);
        assertEq(amounts.length, 3, "length mismatch");
        assertEq(amounts[0], 1e18 , "input mismatch");
        assertGt(amounts[2], 0, "final output > 0");
    }

    function testGetAmountsOutRevert_InvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = address(tokenA);

        vm.expectRevert();
        router.getAmountsOut(100, path);
    }

    function testGetAmountsIn_SingleHop() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            2000 ether,
            900 ether,
            1800 ether,
            user,
            block.timestamp + 1000
        );
        vm.stopPrank();

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint[] memory amounts = router.getAmountsIn(500 ether, path);
        assertEq(amounts[1], 500 ether, "final output mismatch");
        assertGt(amounts[0], 0, "input A should be > 0");
    }

    function testGetAmountsIn_MultiHop() public {
        vm.deal(user, 100 ether);
        vm.startPrank(user);

        weth.deposit{value: 20 ether}();

        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);
        weth.approve(address(router), type(uint).max);

        router.addLiquidity(
            address(tokenA),
            address(weth),
            10 ether,
            10 ether,
            9 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );

        router.addLiquidity(
            address(weth),
            address(tokenB),
            10 ether,
            2000 ether,
            9 ether,
            1800 ether,
            user,
            block.timestamp + 1000
        );

        vm.stopPrank();

        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(weth);
        path[2] = address(tokenB);

        uint[] memory amounts = router.getAmountsIn(500 ether, path);
        assertEq(amounts.length, 3, "length mismatch");
        assertEq(amounts[2], 500 ether, "final output mismatch");
        assertGt(amounts[0], 0, "input A should be > 0");
    }

    function testGetAmountsInRevert_InvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = address(tokenA);

        vm.expectRevert();
        router.getAmountsIn(100, path);
    }
}