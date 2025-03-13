// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "lib/forge-std/src/Test.sol";
import "src/periphery/UniswapV2Router02.sol";
import "src/test/mocks/MockERC20.sol";
import "src/test/mocks/MockWETH.sol";
import "src/core/interfaces/IUniswapV2Factory.sol";
import "src/core/interfaces/IUniswapV2Pair.sol";

contract UniswapV2Router02LiquidityTest is Test {
    UniswapV2Router02 public router;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockWETH public weth;
    IUniswapV2Factory public factory;
    address public pair;

    address public alice = makeAddr("alice");
    uint256 constant INITIAL_AMOUNT = 1000000 ether;
    uint256 constant LIQUIDITY_AMOUNT = 1000 ether;

    function setUp() public {
        // Deploy mock tokens
        tokenA = new MockERC20("Token A", "TKA", 18);
        tokenB = new MockERC20("Token B", "TKB", 18);
        weth = new MockWETH();
        
        // Deploy factory and router
        factory = IUniswapV2Factory(makeAddr("factory"));
        router = new UniswapV2Router02(address(factory), address(weth));

        // Mock factory functions
        vm.mockCall(
            address(factory),
            abi.encodeWithSelector(IUniswapV2Factory.createPair.selector),
            abi.encode(makeAddr("pair"))
        );
        vm.mockCall(
            address(factory),
            abi.encodeWithSelector(IUniswapV2Factory.getPair.selector),
            abi.encode(makeAddr("pair"))
        );

        // Setup test account
        vm.startPrank(alice);
        tokenA.mint(alice, INITIAL_AMOUNT);
        tokenB.mint(alice, INITIAL_AMOUNT);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        vm.deal(alice, INITIAL_AMOUNT);
        vm.stopPrank();
    }

    function test_addLiquidity() public {
        vm.startPrank(alice);

        uint256 amountADesired = LIQUIDITY_AMOUNT;
        uint256 amountBDesired = LIQUIDITY_AMOUNT;
        uint256 amountAMin = LIQUIDITY_AMOUNT * 95 / 100;
        uint256 amountBMin = LIQUIDITY_AMOUNT * 95 / 100;
        uint256 deadline = block.timestamp + 15;

        // Mock pair functions
        address mockPair = makeAddr("pair");
        vm.mockCall(
            mockPair,
            abi.encodeWithSelector(IUniswapV2Pair.getReserves.selector),
            abi.encode(uint112(0), uint112(0), uint32(block.timestamp))
        );
        vm.mockCall(
            mockPair,
            abi.encodeWithSelector(IUniswapV2Pair.mint.selector),
            abi.encode(LIQUIDITY_AMOUNT)
        );

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            alice,
            deadline
        );

        assertEq(amountA, LIQUIDITY_AMOUNT, "Incorrect token A amount");
        assertEq(amountB, LIQUIDITY_AMOUNT, "Incorrect token B amount");
        assertEq(liquidity, LIQUIDITY_AMOUNT, "Incorrect liquidity amount");

        vm.stopPrank();
    }

    function test_addLiquidityETH() public {
        vm.startPrank(alice);

        uint256 amountTokenDesired = LIQUIDITY_AMOUNT;
        uint256 amountTokenMin = LIQUIDITY_AMOUNT * 95 / 100;
        uint256 amountETHMin = LIQUIDITY_AMOUNT * 95 / 100;
        uint256 deadline = block.timestamp + 15;

        // Mock pair functions
        address mockPair = makeAddr("pair");
        vm.mockCall(
            mockPair,
            abi.encodeWithSelector(IUniswapV2Pair.getReserves.selector),
            abi.encode(uint112(0), uint112(0), uint32(block.timestamp))
        );
        vm.mockCall(
            mockPair,
            abi.encodeWithSelector(IUniswapV2Pair.mint.selector),
            abi.encode(LIQUIDITY_AMOUNT)
        );

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{
            value: LIQUIDITY_AMOUNT
        }(
            address(tokenA),
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            alice,
            deadline
        );

        assertEq(amountToken, LIQUIDITY_AMOUNT, "Incorrect token amount");
        assertEq(amountETH, LIQUIDITY_AMOUNT, "Incorrect ETH amount");
        assertEq(liquidity, LIQUIDITY_AMOUNT, "Incorrect liquidity amount");

        vm.stopPrank();
    }

    function test_RevertWhen_addLiquidity_Expired() public {
        vm.startPrank(alice);
        
        uint256 deadline = block.timestamp - 1;
        
        vm.expectRevert("UniswapV2Router: EXPIRED");
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            deadline
        );

        vm.stopPrank();
    }

    function test_RevertWhen_addLiquidityETH_Expired() public {
        vm.startPrank(alice);
        
        uint256 deadline = block.timestamp - 1;
        
        vm.expectRevert("UniswapV2Router: EXPIRED");
        router.addLiquidityETH{value: LIQUIDITY_AMOUNT}(
            address(tokenA),
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            deadline
        );

        vm.stopPrank();
    }

    function test_RevertWhen_addLiquidity_InsufficientAAmount() public {
        vm.startPrank(alice);

        address mockPair = makeAddr("pair");
        vm.mockCall(
            mockPair,
            abi.encodeWithSelector(IUniswapV2Pair.getReserves.selector),
            abi.encode(uint112(2000 ether), uint112(1000 ether), uint32(block.timestamp))
        );

        vm.expectRevert("UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            alice,
            block.timestamp + 15
        );

        vm.stopPrank();
    }

    function test_RevertWhen_addLiquidity_InsufficientBAmount() public {
        vm.startPrank(alice);

        address mockPair = makeAddr("pair");
        vm.mockCall(
            mockPair,
            abi.encodeWithSelector(IUniswapV2Pair.getReserves.selector),
            abi.encode(uint112(1000 ether), uint112(2000 ether), uint32(block.timestamp))
        );

        vm.expectRevert("UniswapV2Router: INSUFFICIENT_B_AMOUNT");
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            LIQUIDITY_AMOUNT,
            alice,
            block.timestamp + 15
        );

        vm.stopPrank();
    }
}