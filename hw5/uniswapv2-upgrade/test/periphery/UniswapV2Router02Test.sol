// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "lib/forge-std/src/Test.sol";

import 'src/periphery/UniswapV2Router02.sol';
import 'src/core/UniswapV2Factory.sol';
import 'src/core/UniswapV2Pair.sol';
import 'src/periphery/interfaces/IWETH.sol';
import 'src/core/interfaces/IERC20.sol';
import 'src/libraries/TransferHelper.sol';

// Mock contracts for testing
// import {ERC20Mock} from "./mocks/ERC20Mock.sol";
// import {WETHMock} from "./mocks/WETHMock.sol";
// import {UniswapV2CalleeMock} from "./mocks/UniswapV2CalleeMock.sol";

contract UniswapV2Router02Test is Test {
    // Contracts
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;
    WETHMock public weth;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    ERC20Mock public tokenC;
    UniswapV2CalleeMock public calleeMock;

    // Test accounts
    address public owner = address(this);
    address public feeTo = address(0xFEE);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
    // Constants
    uint256 public constant INITIAL_MINT_AMOUNT = 1000 ether;
    uint256 public constant DEADLINE = block.timestamp + 1 days;

    function setUp() public {
        // Deploy tokens
        weth = new WETHMock();
        tokenA = new ERC20Mock("Token A", "TKA", 18);
        tokenB = new ERC20Mock("Token B", "TKB", 18);
        tokenC = new ERC20Mock("Token C", "TKC", 18);
        calleeMock = new UniswapV2CalleeMock();

        // Deploy factory and router
        factory = new UniswapV2Factory(owner);
        router = new UniswapV2Router02(address(factory), address(weth));
        
        // Mint tokens to test accounts
        tokenA.mint(owner, INITIAL_MINT_AMOUNT);
        tokenB.mint(owner, INITIAL_MINT_AMOUNT);
        tokenC.mint(owner, INITIAL_MINT_AMOUNT);
        tokenA.mint(user1, INITIAL_MINT_AMOUNT);
        tokenB.mint(user1, INITIAL_MINT_AMOUNT);
        tokenC.mint(user1, INITIAL_MINT_AMOUNT);
        
        // Approve router to spend tokens
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        tokenC.approve(address(router), type(uint256).max);
        
        vm.startPrank(user1);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        tokenC.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    // Test constructor and receive function
    function testConstructor() public {
        assertEq(router.factory(), address(factory));
        assertEq(router.WETH(), address(weth));
    }

    function testReceive() public {
        vm.deal(address(weth), 1 ether);
        vm.prank(address(weth));
        (bool success, ) = address(router).call{value: 1 ether}("");
        assertTrue(success);
        
        // Test receive fails when not from WETH
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert();
        (success, ) = address(router).call{value: 1 ether}("");
    }

    // Test ensure modifier
    function testEnsureModifier() public {
        vm.warp(DEADLINE + 1);
        vm.expectRevert("UniswapV2Router: EXPIRED");
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            0,
            0,
            owner,
            DEADLINE
        );
    }

    // Test add liquidity
    function testAddLiquidity() public {
        // Create pair and add initial liquidity
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 ether,
            10 ether,
            9 ether,
            9 ether,
            owner,
            DEADLINE
        );
        
        assertEq(amountA, 10 ether);
        assertEq(amountB, 10 ether);
        assertTrue(liquidity > 0);
        
        // Get pair address
        address pair = factory.getPair(address(tokenA), address(tokenB));
        assertTrue(pair != address(0));
        
        // Check reserves
        (uint112 reserve0, uint112 reserve1, ) = UniswapV2Pair(pair).getReserves();
        assertTrue(reserve0 > 0);
        assertTrue(reserve1 > 0);
    }

    function testAddLiquidityOptimalB() public {
        // First add some liquidity with different ratio (2:1)
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            20 ether,
            10 ether,
            0,
            0,
            owner,
            DEADLINE
        );
        
        // Now add more with amountBDesired higher than optimal
        (uint amountA, uint amountB, ) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 ether,
            10 ether,  // Will be reduced to optimal
            9 ether,
            0,         // No min B amount
            owner,
            DEADLINE
        );
        
        assertEq(amountA, 10 ether);
        assertEq(amountB, 5 ether);  // Should be half of amountA based on 2:1 ratio
    }
    
    function testAddLiquidityOptimalA() public {
        // First add some liquidity with different ratio (1:2)
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 ether,
            20 ether,
            0,
            0,
            owner,
            DEADLINE
        );
        
        // Now add more with amountADesired higher than optimal
        (uint amountA, uint amountB, ) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 ether,  // Will be reduced to optimal
            10 ether,
            0,         // No min A amount
            9 ether,
            owner,
            DEADLINE
        );
        
        assertEq(amountA, 5 ether);  // Should be half of amountB based on 1:2 ratio
        assertEq(amountB, 10 ether);
    }
    
    function testAddLiquidityInsufficientAmount() public {
        // First add some liquidity with ratio 1:1
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 ether,
            10 ether,
            0,
            0,
            owner,
            DEADLINE
        );
        
        // Now try to add with amountBMin higher than optimal
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_B_AMOUNT");
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 ether,
            5 ether,   // Not enough based on 1:1 ratio
            9 ether,
            10 ether,  // This min is too high for the provided amountA
            owner,
            DEADLINE
        );
        
        // Now try to add with amountAMin higher than optimal
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            5 ether,   // Not enough based on 1:1 ratio
            10 ether,
            10 ether,  // This min is too high for the provided amountB
            9 ether,
            owner,
            DEADLINE
        );
    }

    // Test add liquidity ETH
    function testAddLiquidityETH() public {
        vm.deal(owner, 10 ether);
        
        (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            10 ether,
            9 ether,
            9 ether,
            owner,
            DEADLINE
        );
        
        assertEq(amountToken, 10 ether);
        assertEq(amountETH, 10 ether);
        assertTrue(liquidity > 0);
        
        // Check the pair was created
        address pair = factory.getPair(address(tokenA), address(weth));
        assertTrue(pair != address(0));
    }
    
    function testAddLiquidityETHWithExcessETH() public {
        vm.deal(owner, 15 ether);
        uint initialBalance = owner.balance;
        
        router.addLiquidityETH{value: 15 ether}(
            address(tokenA),
            10 ether,
            9 ether,
            9 ether,
            owner,
            DEADLINE
        );
        
        // Should refund 5 ETH
        assertEq(owner.balance, initialBalance - 10 ether);
    }

    // Test remove liquidity
    function testRemoveLiquidity() public {
        // First add liquidity
        (,, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 ether,
            10 ether,
            0,
            0,
            owner,
            DEADLINE
        );
        
        // Get pair and approve for liquidity removal
        address pair = factory.getPair(address(tokenA), address(tokenB));
        IERC20(pair).approve(address(router), liquidity);
        
        // Remove liquidity
        (uint amountA, uint amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            1,  // min amounts
            1,
            owner,
            DEADLINE
        );
        
        assertTrue(amountA > 0);
        assertTrue(amountB > 0);
    }
    
    function testRemoveLiquidityInsufficientAmount() public {
        // First add liquidity
        (,, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 ether,
            10 ether,
            0,
            0,
            owner,
            DEADLINE
        );
        
        // Get pair and approve for liquidity removal
        address pair = factory.getPair(address(tokenA), address(tokenB));
        IERC20(pair).approve(address(router), liquidity);
        
        // Try to remove with high min amounts
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            100 ether,  // Unreasonably high min amount
            1,
            owner,
            DEADLINE
        );
        
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_B_AMOUNT");
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            1,
            100 ether,  // Unreasonably high min amount
            owner,
            DEADLINE
        );
    }

    // Test remove liquidity ETH
    function testRemoveLiquidityETH() public {
        vm.deal(owner, 10 ether);
        
        // First add liquidity ETH
        (,, uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            10 ether,
            0,
            0,
            owner,
            DEADLINE
        );
        
        // Get pair and approve for liquidity removal
        address pair = factory.getPair(address(tokenA), address(weth));
        IERC20(pair).approve(address(router), liquidity);
        
        uint initialETHBalance = owner.balance;
        uint initialTokenBalance = tokenA.balanceOf(owner);
        
        // Remove liquidity ETH
        (uint amountToken, uint amountETH) = router.removeLiquidityETH(
            address(tokenA),
            liquidity,
            1,  // min amounts
            1,
            owner,
            DEADLINE
        );
        
        assertTrue(amountToken > 0);
        assertTrue(amountETH > 0);
        
        // Check balances were updated
        assertEq(owner.balance, initialETHBalance + amountETH);
        assertEq(tokenA.balanceOf(owner), initialTokenBalance + amountToken);
    }

    // Test remove liquidity with permit
    function testRemoveLiquidityWithPermit() public {
        vm.startPrank(user1);
        
        // Add liquidity
        (,, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 ether,
            10 ether,
            0,
            0,
            user1,
            DEADLINE
        );
        
        // Get pair
        address pair = factory.getPair(address(tokenA), address(tokenB));
        
        // Create permit signature
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            user1,
            address(router),
            liquidity,
            DEADLINE,
            UniswapV2Pair(pair)
        );
        
        // Remove liquidity with permit
        (uint amountA, uint amountB) = router.removeLiquidityWithPermit(
            address(tokenA),
            address(tokenB),
            liquidity,
            1,
            1,
            user1,
            DEADLINE,
            false,
            v, r, s
        );
        
        assertTrue(amountA > 0);
        assertTrue(amountB > 0);
        
        vm.stopPrank();
    }
    
    function testRemoveLiquidityETHWithPermit() public {
        vm.deal(user1, 10 ether);
        vm.startPrank(user1);
        
        // Add liquidity ETH
        (,, uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            10 ether,
            0,
            0,
            user1,
            DEADLINE
        );
        
        // Get pair
        address pair = factory.getPair(address(tokenA), address(weth));
        
        // Create permit signature
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            user1,
            address(router),
            liquidity,
            DEADLINE,
            UniswapV2Pair(pair)
        );
        
        // Remove liquidity ETH with permit
        (uint amountToken, uint amountETH) = router.removeLiquidityETHWithPermit(
            address(tokenA),
            liquidity,
            1,
            1,
            user1,
            DEADLINE,
            false,
            v, r, s
        );
        
        assertTrue(amountToken > 0);
        assertTrue(amountETH > 0);
        
        vm.stopPrank();
    }

    // Test remove liquidity ETH supporting fee on transfer tokens
    function testRemoveLiquidityETHSupportingFeeOnTransferTokens() public {
        // Create a fee on transfer token
        FeeOnTransferToken feeToken = new FeeOnTransferToken("Fee Token", "FEE", 18);
        feeToken.mint(owner, INITIAL_MINT_AMOUNT);
        feeToken.approve(address(router), type(uint256).max);
        
        vm.deal(owner, 10 ether);
        
        // Add liquidity ETH with fee token
        (,, uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(feeToken),
            10 ether,
            0,
            0,
            owner,
            DEADLINE
        );
        
        // Get pair and approve for liquidity removal
        address pair = factory.getPair(address(feeToken), address(weth));
        IERC20(pair).approve(address(router), liquidity);
        
        uint initialETHBalance = owner.balance;
        uint initialTokenBalance = feeToken.balanceOf(owner);
        
        // Remove liquidity ETH supporting fee
        uint amountETH = router.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(feeToken),
            liquidity,
            1,  // min amounts
            1,
            owner,
            DEADLINE
        );
        
        assertTrue(amountETH > 0);
        
        // Check balances were updated
        assertEq(owner.balance, initialETHBalance + amountETH);
        assertTrue(feeToken.balanceOf(owner) > initialTokenBalance);
    }
    
    function testRemoveLiquidityETHWithPermitSupportingFeeOnTransferTokens() public {
        // Create a fee on transfer token
        FeeOnTransferToken feeToken = new FeeOnTransferToken("Fee Token", "FEE", 18);
        feeToken.mint(user1, INITIAL_MINT_AMOUNT);
        
        vm.deal(user1, 10 ether);
        vm.startPrank(user1);
        
        feeToken.approve(address(router), type(uint256).max);
        
        // Add liquidity ETH with fee token
        (,, uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(feeToken),
            10 ether,
            0,
            0,
            user1,
            DEADLINE
        );
        
        // Get pair
        address pair = factory.getPair(address(feeToken), address(weth));
        
        // Create permit signature
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            user1,
            address(router),
            liquidity,
            DEADLINE,
            UniswapV2Pair(pair)
        );
        
        uint initialETHBalance = user1.balance;
        
        // Remove liquidity ETH with permit supporting fee
        uint amountETH = router.removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
            address(feeToken),
            liquidity,
            1,
            1,
            user1,
            DEADLINE,
            false,
            v, r, s
        );
        
        assertTrue(amountETH > 0);
        assertEq(user1.balance, initialETHBalance + amountETH);
        
        vm.stopPrank();
    }

    // Test swap exact tokens for tokens
    function testSwapExactTokensForTokens() public {
        // Setup the pairs
        _setupPairAB(10 ether, 10 ether);
        
        // Swap 1 token A for token B
        uint amountIn = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            0,  // Any amount out
            path,
            owner,
            DEADLINE
        );
        
        assertTrue(amounts.length == 2);
        assertEq(amounts[0], amountIn);
        assertTrue(amounts[1] > 0);
    }
    
    function testSwapTokensForExactTokens() public {
        // Setup the pairs
        _setupPairAB(10 ether, 10 ether);
        
        // Swap tokens to get exact 1 token B
        uint amountOut = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint[] memory amounts = router.swapTokensForExactTokens(
            amountOut,
            10 ether,  // Max amount in
            path,
            owner,
            DEADLINE
        );
        
        assertTrue(amounts.length == it2);
        assertTrue(amounts[0] > 0);
        assertEq(amounts[1], amountOut);
    }
    
    function testSwapExactETHForTokens() public {
        // Setup the pairs
        vm.deal(owner, 10 ether);
        _setupPairWETHB(10 ether, 10 ether);
        
        // Swap 1 ETH for token B
        uint amountIn = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenB);
        
        uint[] memory amounts = router.swapExactETHForTokens{value: amountIn}(
            0,  // Any amount out
            path,
            owner,
            DEADLINE
        );
        
        assertTrue(amounts.length == 2);
        assertEq(amounts[0], amountIn);
        assertTrue(amounts[1] > 0);
    }
    
    function testSwapTokensForExactETH() public {
        // Setup the pairs
        vm.deal(owner, 10 ether);
        _setupPairWETHB(10 ether, 10 ether);
        
        // Swap tokens to get exact 1 ETH
        uint amountOut = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(tokenB);
        path[1] = address(weth);
        
        uint[] memory amounts = router.swapTokensForExactETH(
            amountOut,
            10 ether,  // Max amount in
            path,
            owner,
            DEADLINE
        );
        
        assertTrue(amounts.length == 2);
        assertTrue(amounts[0] > 0);
        assertEq(amounts[1], amountOut);
    }
    
    function testSwapExactTokensForETH() public {
        // Setup the pairs
        vm.deal(owner, 10 ether);
        _setupPairWETHB(10 ether, 10 ether);
        
        // Swap 1 token B for ETH
        uint amountIn = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(tokenB);
        path[1] = address(weth);
        
        uint initialETHBalance = owner.balance;
        
        uint[] memory amounts = router.swapExactTokensForETH(
            amountIn,
            0,  // Any amount out
            path,
            owner,
            DEADLINE
        );
        
        assertTrue(amounts.length == 2);
        assertEq(amounts[0], amountIn);
        assertTrue(amounts[1] > 0);
        assertEq(owner.balance, initialETHBalance + amounts[1]);
    }
    
    function testSwapETHForExactTokens() public {
        // Setup the pairs
        vm.deal(owner, 10 ether);
        _setupPairWETHB(10 ether, 10 ether);
        
        // Swap ETH to get exact 1 token B
        uint amountOut = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenB);
        
        uint initialETHBalance = owner.balance;
        
        uint[] memory amounts = router.swapETHForExactTokens{value: 2 ether}(
            amountOut,
            path,
            owner,
            DEADLINE
        );
        
        assertTrue(amounts.length == 2);
        assertTrue(amounts[0] > 0);
        assertEq(amounts[1], amountOut);
        
        // Should refund excess ETH
        assertEq(owner.balance, initialETHBalance - amounts[0]);
    }

    // Test swaps with fee on transfer tokens
    function testSwapExactTokensForTokensSupportingFeeOnTransferTokens() public {
        // Create a fee on transfer token
        FeeOnTransferToken feeToken = new FeeOnTransferToken("Fee Token", "FEE", 18);
        feeToken.mint(owner, INITIAL_MINT_AMOUNT);
        feeToken.approve(address(router), type(uint256).max);
        
        // Setup the pair
        _setupPair(address(feeToken), address(tokenB), 10 ether, 10 ether);
        
        // Swap 1 fee token for token B
        uint amountIn = 1 ether;
        uint initialBalance = tokenB.balanceOf(owner);
        
        address[] memory path = new address[](2);
        path[0] = address(feeToken);
        path[1] = address(tokenB);
        
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            0,  // Any amount out
            path,
            owner,
            DEADLINE
        );
        
        // Should receive some token B
        assertTrue(tokenB.balanceOf(owner) > initialBalance);
    }
    
    function testSwapExactETHForTokensSupportingFeeOnTransferTokens() public {
        // Create a fee on transfer token
        FeeOnTransferToken feeToken = new FeeOnTransferToken("Fee Token", "FEE", 18);
        feeToken.mint(address(this), INITIAL_MINT_AMOUNT);
        feeToken.approve(address(router), type(uint256).max);
        
        vm.deal(owner, 10 ether);
        
        // Setup the pair
        _setupPair(address(weth), address(feeToken), 10 ether, 10 ether);
        
        // Swap 1 ETH for fee token
        uint amountIn = 1 ether;
        uint initialBalance = feeToken.balanceOf(owner);
        
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(feeToken);
        
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountIn}(
            0,  // Any amount out
            path,
            owner,
            DEADLINE
        );
        
        // Should receive some fee token
        assertTrue(feeToken.balanceOf(owner) > initialBalance);
    }
    
    function testSwapExactTokensForETHSupportingFeeOnTransferTokens() public {
        // Create a fee on transfer token
        FeeOnTransferToken feeToken = new FeeOnTransferToken("Fee Token", "FEE", 18);
        feeToken.mint(owner, INITIAL_MINT_AMOUNT);
        feeToken.approve(address(router), type(uint256).max);
        
        vm.deal(address(this), 10 ether);
        
        // Setup the pair
        _setupPair(address(feeToken), address(weth), 10 ether, 10 ether);
        
        // Swap 1 fee token for ETH
        uint amountIn = 1 ether;
        uint initialETHBalance = owner.balance;
        
        address[] memory path = new address[](2);
        path[0] = address(feeToken);
        path[1] = address(weth);
        
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn,
            0,  // Any amount out
            path,
            owner,
            DEADLINE
        );
        
        // Should receive some ETH
        assertTrue(owner.balance > initialETHBalance);
    }

    // Test multi-hop swaps
    function testMultiHopSwap() public {
        // Setup the pairs
        _setupPairAB(10 ether, 10 ether);
        _setupPair(address(tokenB), address(tokenC), 10 ether, 10 ether);
        
        // Multi-hop swap: tokenA -> tokenB -> tokenC
        uint amountIn = 1 ether;
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        
        uint[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            0,  // Any amount out
            path,
            owner,
            DEADLINE
        );
        
        assertTrue(amounts.length == 3);
        assertEq(amounts[0], amountIn);
        assertTrue(amounts[1] > 0);
        assertTrue(amounts[2] > 0);
    }

    // Test library functions
    function testQuote() public {
        uint amountA = 1 ether;
        uint reserveA = 10 ether;
        uint reserveB = 5 ether;
        
        uint amountB = router.quote(amountA, reserveA, reserveB);
        assertEq(amountB, 0.5 ether);
    }
    
    function testGetAmountOut() public {
        uint amountIn = 1 ether;
        uint reserveIn = 10 ether;
        uint reserveOut = 10 ether;
        
        uint amountOut = router.getAmountOut(amountIn, reserveIn, reserveOut);
        assertTrue(amountOut > 0);
        assertTrue(amountOut < amountIn);  // Should be less due to fee
    }
    
    function testGetAmountIn() public {
        uint amountOut = 1 ether;
        uint reserveIn = 10 ether;
        uint reserveOut = 10 ether;
        
        uint amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut);
        assertTrue(amountIn > amountOut);  // Should be more due to fee
    }
    
    function testGetAmountsOut() public {
        // Setup the pairs
        _setupPairAB(10 ether, 10 ether);
        
        uint amountIn = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint[] memory amounts = router.getAmountsOut(amountIn, path);
        
        assertTrue(amounts.length == 2);
        assertEq(amounts[0], amountIn);
        assertTrue(amounts[1] > 0);
    }
    
    function testGetAmountsIn() public {
        // Setup the pairs
        _setupPairAB(10 ether, 10 ether);
        
        uint amountOut = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint[] memory amounts = router.getAmountsIn(amountOut, path);
        
        assertTrue(amounts.length == 2);
        assertTrue(amounts[0] > 0);
        assertEq(amounts[1], amountOut);
    }

    // Test error cases
    function testInvalidPathForETHSwaps() public {
        vm.deal(owner, 1 ether);
        
        // Invalid path for swapExactETHForTokens
        address[] memory path = new address[](2);
        path[0] = address(tokenA); // Should be WETH
        path[1] = address(tokenB);
        
        vm.expectRevert("UniswapV2Router: INVALID_PATH");
        router.swapExactETHForTokens{value: 1 ether}(
            0,
            path,
            owner,
            DEADLINE
        );
        
        // Invalid path for swapETHForExactTokens
        vm.expectRevert("UniswapV2Router: INVALID_PATH");
        router.swapETHForExactTokens{value: 1 ether}(
            1 ether,
            path,
            owner,
            DEADLINE
        );
        
        // Invalid path for swapTokensForExactETH
        path[0] = address(tokenA);
        path[1] = address(tokenB); // Should be WETH
        
        vm.expectRevert("UniswapV2Router: INVALID_PATH");
        router.swapTokensForExactETH(
            1 ether,
            10 ether,
            path,
            owner,
            DEADLINE
        );
        
        // Invalid path for swapExactTokensForETH
        vm.expectRevert("UniswapV2Router: INVALID_PATH");
        router.swapExactTokensForETH(
            1 ether,
            0,
            path,
            owner,
            DEADLINE
        );
    }
    
    function testInsufficientOutputAmount() public {
        // Setup the pairs
        _setupPairAB(10 ether, 10 ether);
        
        // Swap with high minAmountOut
        uint amountIn = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        router.swapExactTokensForTokens(
            amountIn,
            1000 ether, // Unreasonably high min amount out
            path,
            owner,
            DEADLINE
        );
    }
    
    function testExcessiveInputAmount() public {
        // Setup the pairs
        _setupPairAB(10 ether, 10 ether);
        
        // Swap with low maxAmountIn
        uint amountOut = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        vm.expectRevert("UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        router.swapTokensForExactTokens(
            amountOut,
            0.001 ether, // Unreasonably low max amount in
            path,
            owner,
            DEADLINE
        );
    }

    // Helper functions
    function _setupPairAB(uint amountA, uint amountB) internal {
        _setupPair(address(tokenA), address(tokenB), amountA, amountB);
    }
    
    function _setupPairWETHB(uint amountWETH, uint amountB) internal {
        _setupPair(address(weth), address(tokenB), amountWETH, amountB);
    }
    
    function _setupPair(address token0, address token1, uint amount0, uint amount1) internal {
        // Add liquidity to create the pair
        if (token0 == address(weth)) {
            vm.deal(owner, amount0);
            router.addLiquidityETH{value: amount0}(
                token1,
                amount1,
                0,
                0,
                owner,
                DEADLINE
            );
        } else if (token1 == address(weth)) {
            vm.deal(owner, amount1);
            router.addLiquidityETH{value: amount1}(
                token0,
                amount0,
                0,
                0,
                owner,
                DEADLINE
            );
        } else {
            router.addLiquidity(
                token0,
                token1,
                amount0,
                amount1,
                0,
                0,
                owner,
                DEADLINE
            );
        }
    }
    
    function _createPermitSignature(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        UniswapV2Pair pair
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 DOMAIN_SEPARATOR = pair.get_DOMAIN_SEPARATOR();
        bytes32 PERMIT_TYPEHASH = pair.get_PERMIT_TYPEHASH();
        uint256 nonce = pair.get_nonces(owner);
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline))
            )
        );
        
        (v, r, s) = vm.sign(uint256(keccak256(abi.encodePacked(owner))), digest);
        return (v, r, s);
    }
}

// Mock contracts
contract ERC20Mock is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function mint(address to, uint amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function approve(address spender, uint value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transfer(address to, uint value) external returns (bool) {
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint).max) {
            allowance[from][msg.sender] -= value;
        }
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
}

contract WETHMock is IWETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public decimals = 18;
    
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);
    
    receive() external payable {
        deposit();
    }
    
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    function withdraw(uint amount) external {
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }
    
    function transfer(address to, uint value) external returns (bool) {
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function approve(address spender, uint value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint).max) {
            allowance[from][msg.sender] -= value;
        }
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
}

// Mock contract that simulates a token with fee on transfer
contract FeeOnTransferToken is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    
    uint public constant FEE_PERCENT = 5; // 5% fee
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function mint(address to, uint amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function approve(address spender, uint value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    // Implements fee on transfer
    function transfer(address to, uint value) external returns (bool) {
        uint fee = (value * FEE_PERCENT) / 100;
        uint transferAmount = value - fee;
        
        balanceOf[msg.sender] -= value;
        balanceOf[to] += transferAmount;
        // Fee is burned by not adding it to any address
        totalSupply -= fee;
        
        emit Transfer(msg.sender, to, transferAmount);
        emit Transfer(msg.sender, address(0), fee);
        return true;
    }
    
    // Implements fee on transfer
    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint).max) {
            allowance[from][msg.sender] -= value;
        }
        
        uint fee = (value * FEE_PERCENT) / 100;
        uint transferAmount = value - fee;
        
        balanceOf[from] -= value;
        balanceOf[to] += transferAmount;
        // Fee is burned by not adding it to any address
        totalSupply -= fee;
        
        emit Transfer(from, to, transferAmount);
        emit Transfer(from, address(0), fee);
        return true;
    }
}

contract UniswapV2CalleeMock is IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external override {
        // Do nothing, just implement the interface
    }
}