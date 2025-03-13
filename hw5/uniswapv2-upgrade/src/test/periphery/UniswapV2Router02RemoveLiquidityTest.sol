// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "lib/forge-std/src/Test.sol";
import "src/periphery/UniswapV2Router02.sol";
import "src/test/mocks/MockERC20.sol";
import "src/test/mocks/MockWETH.sol";
import "src/core/interfaces/IUniswapV2Factory.sol";
import "src/core/interfaces/IUniswapV2Pair.sol";

contract UniswapV2Router02RemoveLiquidityTest is Test {
    UniswapV2Router02 public router;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockWETH public weth;
    IUniswapV2Factory public factory;

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

        // Setup test account
        vm.startPrank(alice);
        tokenA.mint(alice, INITIAL_AMOUNT);
        tokenB.mint(alice, INITIAL_AMOUNT);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        vm.deal(alice, INITIAL_AMOUNT);
        vm.stopPrank();
    }

    function mockBasicPairFunctions(address mockPair) internal {
        // Mock get_transferFrom
        vm.mockCall(
            mockPair,
            abi.encodeWithSelector(IUniswapV2Pair.get_transferFrom.selector),
            abi.encode(true)
        );

        // Mock burn
        vm.mockCall(
            mockPair,
            abi.encodeWithSelector(IUniswapV2Pair.burn.selector),
            abi.encode(LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT)
        );

        // Mock WETH transfer
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );

        // Mock token transfer
        vm.mockCall(
            address(tokenA),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );
    }

    function test_removeLiquidity() public {
        vm.startPrank(alice);

        address mockPair = makeAddr("pair");
        
        // Mock factory function
        vm.mockCall(
            address(factory),
            abi.encodeWithSelector(IUniswapV2Factory.getPair.selector),
            abi.encode(mockPair)
        );

        mockBasicPairFunctions(mockPair);

        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp + 15
        );

        assertEq(amountA, LIQUIDITY_AMOUNT, "Incorrect token A amount");
        assertEq(amountB, LIQUIDITY_AMOUNT, "Incorrect token B amount");

        vm.stopPrank();
    }

    function test_removeLiquidityETH() public {
        vm.startPrank(alice);

        // Provide ETH to the router contract
        vm.deal(address(router), LIQUIDITY_AMOUNT);

        address mockPair = makeAddr("pair");
        
        // Mock factory function
        vm.mockCall(
            address(factory),
            abi.encodeWithSelector(IUniswapV2Factory.getPair.selector),
            abi.encode(mockPair)
        );

        mockBasicPairFunctions(mockPair);

        // Mock WETH withdraw
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IWETH.withdraw.selector),
            abi.encode()
        );

        // Mock WETH balance
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.balanceOf.selector),
            abi.encode(LIQUIDITY_AMOUNT)
        );

        (uint256 amountToken, uint256 amountETH) = router.removeLiquidityETH(
            address(tokenA),
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp + 15
        );

        assertEq(amountToken, LIQUIDITY_AMOUNT, "Incorrect token amount");
        assertEq(amountETH, LIQUIDITY_AMOUNT, "Incorrect ETH amount");

        vm.stopPrank();
    }

    function test_removeLiquidityWithPermit() public {
        vm.startPrank(alice);

        address mockPair = makeAddr("pair");
        
        // Mock factory function
        vm.mockCall(
            address(factory),
            abi.encodeWithSelector(IUniswapV2Factory.getPair.selector),
            abi.encode(mockPair)
        );

        mockBasicPairFunctions(mockPair);

        // Mock permit call
        vm.mockCall(
            mockPair,
            abi.encodeWithSelector(IUniswapV2Pair.get_permit.selector),
            abi.encode()
        );

        (uint256 amountA, uint256 amountB) = router.removeLiquidityWithPermit(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp + 15,
            true,
            27,
            bytes32(0),
            bytes32(0)
        );

        assertEq(amountA, LIQUIDITY_AMOUNT, "Incorrect token A amount");
        assertEq(amountB, LIQUIDITY_AMOUNT, "Incorrect token B amount");

        vm.stopPrank();
    }

    function test_removeLiquidityETHWithPermit() public {
        vm.startPrank(alice);

        // Provide ETH to the router contract
        vm.deal(address(router), LIQUIDITY_AMOUNT);

        address mockPair = makeAddr("pair");
        
        // Mock factory function
        vm.mockCall(
            address(factory),
            abi.encodeWithSelector(IUniswapV2Factory.getPair.selector),
            abi.encode(mockPair)
        );

        mockBasicPairFunctions(mockPair);

        // Mock permit call
        vm.mockCall(
            mockPair,
            abi.encodeWithSelector(IUniswapV2Pair.get_permit.selector),
            abi.encode()
        );

        // Mock WETH withdraw
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IWETH.withdraw.selector),
            abi.encode()
        );

        // Mock WETH balance
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.balanceOf.selector),
            abi.encode(LIQUIDITY_AMOUNT)
        );

        (uint256 amountToken, uint256 amountETH) = router.removeLiquidityETHWithPermit(
            address(tokenA),
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp + 15,
            true,
            27,
            bytes32(0),
            bytes32(0)
        );

        assertEq(amountToken, LIQUIDITY_AMOUNT, "Incorrect token amount");
        assertEq(amountETH, LIQUIDITY_AMOUNT, "Incorrect ETH amount");

        vm.stopPrank();
    }

    function test_RevertWhen_removeLiquidity_Expired() public {
        vm.startPrank(alice);
        
        vm.expectRevert("UniswapV2Router: EXPIRED");
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp - 1
        );

        vm.stopPrank();
    }

    function test_RevertWhen_removeLiquidityETH_Expired() public {
        vm.startPrank(alice);
        
        vm.expectRevert("UniswapV2Router: EXPIRED");
        router.removeLiquidityETH(
            address(tokenA),
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp - 1
        );

        vm.stopPrank();
    }

    function test_RevertWhen_removeLiquidity_InsufficientAAmount() public {
        vm.startPrank(alice);

        address mockPair = makeAddr("pair");
        
        // Mock getPair
        vm.mockCall(
            address(factory),
            abi.encodeWithSelector(IUniswapV2Factory.getPair.selector),
            abi.encode(mockPair)
        );

        // Mock get_transferFrom
        vm.mockCall(
            mockPair,
            abi.encodeWithSelector(IUniswapV2Pair.get_transferFrom.selector),
            abi.encode(true)
        );

        // Get token order
        (address token0,) = UniswapV2Library.sortTokens(address(tokenA), address(tokenB));
        bool isTokenAFirst = address(tokenA) == token0;

        // Mock burn with insufficient amount A in correct order
        if (isTokenAFirst) {
            vm.mockCall(
                mockPair,
                abi.encodeWithSelector(IUniswapV2Pair.burn.selector),
                abi.encode(LIQUIDITY_AMOUNT / 2, LIQUIDITY_AMOUNT)
            );
        } else {
            vm.mockCall(
                mockPair,
                abi.encodeWithSelector(IUniswapV2Pair.burn.selector),
                abi.encode(LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT / 2)
            );
        }

        vm.expectRevert("UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            alice,
            block.timestamp + 15
        );

        vm.stopPrank();
    }

    function test_RevertWhen_removeLiquidity_InsufficientBAmount() public {
        vm.startPrank(alice);

        address mockPair = makeAddr("pair");
        
        // Mock getPair
        vm.mockCall(
            address(factory),
            abi.encodeWithSelector(IUniswapV2Factory.getPair.selector),
            abi.encode(mockPair)
        );

        // Mock get_transferFrom
        vm.mockCall(
            mockPair,
            abi.encodeWithSelector(IUniswapV2Pair.get_transferFrom.selector),
            abi.encode(true)
        );

        // Get token order
        (address token0,) = UniswapV2Library.sortTokens(address(tokenA), address(tokenB));
        bool isTokenAFirst = address(tokenA) == token0;

        // Mock burn with insufficient amount B in correct order
        if (isTokenAFirst) {
            vm.mockCall(
                mockPair,
                abi.encodeWithSelector(IUniswapV2Pair.burn.selector),
                abi.encode(LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT / 2)
            );
        } else {
            vm.mockCall(
                mockPair,
                abi.encodeWithSelector(IUniswapV2Pair.burn.selector),
                abi.encode(LIQUIDITY_AMOUNT / 2, LIQUIDITY_AMOUNT)
            );
        }

        vm.expectRevert("UniswapV2Router: INSUFFICIENT_B_AMOUNT");
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            0,
            LIQUIDITY_AMOUNT,
            alice,
            block.timestamp + 15
        );

        vm.stopPrank();
    }

    function test_RevertWhen_removeLiquidity_PairNotFound() public {
        vm.startPrank(alice);

        // Mock factory to return zero address for pair
        vm.mockCall(
            address(factory),
            abi.encodeWithSelector(IUniswapV2Factory.getPair.selector),
            abi.encode(address(0))
        );

        vm.expectRevert("UniswapV2Router: PAIR_NOT_FOUND");
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp + 15
        );

        vm.stopPrank();
    }
}