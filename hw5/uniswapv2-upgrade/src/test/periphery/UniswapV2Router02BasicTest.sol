// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "lib/forge-std/src/Test.sol";
import "src/periphery/UniswapV2Router02.sol";
import "src/test/mocks/UniswapV2FactoryMock.sol";
import "src/test/mocks/UniswapV2WETH9Mock.sol";
import "src/test/mocks/UniswapV2ERC20Mock.sol";

contract UniswapV2Router02BasicTest is Test {
    UniswapV2Router02 public router;
    UniswapV2FactoryMock public factory;
    UniswapV2WETH9Mock public weth;
    UniswapV2ERC20Mock public tokenA;
    UniswapV2ERC20Mock public tokenB;

    function setUp() public {
        // Deploy mocks
        factory = new UniswapV2FactoryMock();
        weth = new UniswapV2WETH9Mock();
        tokenA = new UniswapV2ERC20Mock();
        tokenB = new UniswapV2ERC20Mock();

        // Deploy router
        router = new UniswapV2Router02(address(factory), address(weth));
    }

    function testConstructor() public {
        assertEq(router.factory(), address(factory));
        assertEq(router.WETH(), address(weth));
    }

    function testReceive() public {
        // Test receiving ETH from WETH
        vm.deal(address(weth), 1 ether);
        vm.prank(address(weth));
        payable(address(router)).transfer(1 ether);
        
        // Test receiving ETH from other address should fail
        vm.deal(address(this), 1 ether);
        vm.expectRevert();
        payable(address(router)).transfer(1 ether);
    }

    function testQuote() public {
        assertEq(router.quote(100, 200, 400), 200);
        assertEq(router.quote(200, 200, 400), 400);
        assertEq(router.quote(400, 200, 400), 800);
    }

    function testGetAmountOut() public {
        assertEq(router.getAmountOut(100, 1000, 2000), 198);
        vm.expectRevert();
        router.getAmountOut(0, 1000, 2000);
        vm.expectRevert();
        router.getAmountOut(100, 0, 2000);
        vm.expectRevert();
        router.getAmountOut(100, 1000, 0);
    }

    function testGetAmountIn() public {
        assertEq(router.getAmountIn(100, 1000, 2000), 51);
        vm.expectRevert();
        router.getAmountIn(0, 1000, 2000);
        vm.expectRevert();
        router.getAmountIn(100, 0, 2000);
        vm.expectRevert();
        router.getAmountIn(100, 1000, 0);
    }

    function testEnsureModifier() public {
        // Test with expired deadline
        uint256 expiredDeadline = block.timestamp - 1;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.expectRevert("UniswapV2Router: EXPIRED");
        router.swapExactTokensForTokens(100, 90, path, address(this), expiredDeadline);

        // Test with valid deadline
        uint256 validDeadline = block.timestamp + 1;
        tokenA.mint(address(this), 100);
        tokenA.approve(address(router), 100);
        router.swapExactTokensForTokens(100, 90, path, address(this), validDeadline);
    }
}