// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "lib/forge-std/src/Test.sol";
import "src/periphery/UniswapV2Router02.sol";
import "src/core/UniswapV2Factory.sol";
import "src/core/UniswapV2Pair.sol";
import "src/periphery/libraries/UniswapV2Library.sol";
import "src/periphery/interfaces/IWETH.sol";

// Test ERC20 token implementation
contract TestERC20 is IERC20 {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    bool public transferFee; // Flag to simulate fee-on-transfer tokens
    
    constructor(string memory _name, string memory _symbol, uint256 initialSupply) {
        name = _name;
        symbol = _symbol;
        _mint(msg.sender, initialSupply);
    }
    
    function setTransferFee(bool _transferFee) external {
        transferFee = _transferFee;
    }
    
    function _mint(address to, uint256 value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }
    
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transfer(address to, uint256 value) external returns (bool) {
        uint256 transferAmount = value;
        
        // Simulate fee-on-transfer if enabled (5% fee)
        if (transferFee) {
            transferAmount = value * 95 / 100;
        }
        
        balanceOf[msg.sender] -= value; // Deduct full amount from sender
        balanceOf[to] += transferAmount; // Add reduced amount to receiver
        
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= value;
        }
        
        uint256 transferAmount = value;
        
        // Simulate fee-on-transfer if enabled (5% fee)
        if (transferFee) {
            transferAmount = value * 95 / 100;
        }
        
        balanceOf[from] -= value; // Deduct full amount from sender
        balanceOf[to] += transferAmount; // Add reduced amount to receiver
        
        emit Transfer(from, to, value);
        return true;
    }
}

// Mock WETH implementation
contract WETH is IWETH {
    string public name = "Wrapped ETH";
    string public symbol = "WETH";
    uint8 public decimals = 18;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    
    receive() external payable {
        deposit();
    }
    
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Transfer(address(0), msg.sender, msg.value);
    }
    
    function withdraw(uint256 amount) public {
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Transfer(msg.sender, address(0), amount);
    }
    
    function totalSupply() external view returns (uint256) {
        return address(this).balance;
    }
    
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= value;
        }
        
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
}

// Helper interface for IUniswapV2Pair functions we need to mock
interface IUniswapV2PairExt {
    function get_transferFrom(address from, address to, uint value) external;
    function get_permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}

// Test contract for UniswapV2Router02
contract UniswapV2Router02Test is Test {
    UniswapV2Factory factory;
    UniswapV2Router02 router;
    WETH weth;
    TestERC20 tokenA;
    TestERC20 tokenB;
    TestERC20 tokenC;
    TestERC20 feeToken; // Token with fee on transfer
    
    address user = address(1);
    address user2 = address(2);
    
    uint256 constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 constant TEST_AMOUNT = 1000 * 10**18;
    
    function setUp() public {
        // Deploy contracts
        weth = new WETH();
        factory = new UniswapV2Factory(address(this));
        router = new UniswapV2Router02(address(factory), address(weth));
        
        // Deploy test tokens
        tokenA = new TestERC20("Token A", "TKNA", INITIAL_SUPPLY);
        tokenB = new TestERC20("Token B", "TKNB", INITIAL_SUPPLY);
        tokenC = new TestERC20("Token C", "TKNC", INITIAL_SUPPLY);
        feeToken = new TestERC20("Fee Token", "FEETK", INITIAL_SUPPLY);
        feeToken.setTransferFee(true);
        
        // Setup user with tokens and ETH
        vm.deal(user, 100 ether);
        tokenA.transfer(user, TEST_AMOUNT);
        tokenB.transfer(user, TEST_AMOUNT);
        tokenC.transfer(user, TEST_AMOUNT);
        feeToken.transfer(user, TEST_AMOUNT);
        
        // Setup user2 with tokens and ETH
        vm.deal(user2, 100 ether);
        tokenA.transfer(user2, TEST_AMOUNT);
        tokenB.transfer(user2, TEST_AMOUNT);
        tokenC.transfer(user2, TEST_AMOUNT);
        feeToken.transfer(user2, TEST_AMOUNT);
        
        // Approve router to spend tokens
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        tokenC.approve(address(router), type(uint256).max);
        feeToken.approve(address(router), type(uint256).max);
        
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        tokenC.approve(address(router), type(uint256).max);
        feeToken.approve(address(router), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(user2);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        tokenC.approve(address(router), type(uint256).max);
        feeToken.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }
    
    // Helper function to create a pair and add liquidity
    function createPairWithLiquidity(
        TestERC20 token0, 
        TestERC20 token1, 
        uint256 amount0, 
        uint256 amount1
    ) internal returns (address pair) {
        factory.createPair(address(token0), address(token1));
        pair = factory.getPair(address(token0), address(token1));
        
        token0.transfer(pair, amount0);
        token1.transfer(pair, amount1);
        
        UniswapV2Pair(pair).mint(address(this));
    }
    
    // ======== TESTS ========
    
    // Test addLiquidity when pair doesn't exist
    function testAddLiquidityNewPair() public {
        uint amountA = 100 * 10**18;
        uint amountB = 200 * 10**18;
        
        // Verify pair doesn't exist yet
        assertEq(factory.getPair(address(tokenA), address(tokenB)), address(0));
        
        (uint actualA, uint actualB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            amountA,
            amountB,
            address(this),
            block.timestamp + 3600
        );
        
        assertEq(actualA, amountA);
        assertEq(actualB, amountB);
        assertGt(liquidity, 0);
        
        // Verify pair was created
        address pair = factory.getPair(address(tokenA), address(tokenB));
        assertNotEq(pair, address(0));
    }
    
    // Test addLiquidity with existing pair
    function testAddLiquidityExistingPair() public {
        // First create pair and add liquidity
        uint amountA1 = 100 * 10**18;
        uint amountB1 = 200 * 10**18;
        
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA1,
            amountB1,
            amountA1,
            amountB1,
            address(this),
            block.timestamp + 3600
        );
        
        // Now add more liquidity
        uint amountA2 = 50 * 10**18;
        uint amountB2 = 100 * 10**18;
        
        (uint actualA, uint actualB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA2,
            amountB2,
            0,
            0,
            address(this),
            block.timestamp + 3600
        );
        
        assertEq(actualA, amountA2);
        assertEq(actualB, amountB2);
        assertGt(liquidity, 0);
    }
    
    // Test addLiquidity with suboptimal amounts
    function testAddLiquiditySuboptimalAmounts() public {
        // First create pair and add liquidity
        uint amountA1 = 100 * 10**18;
        uint amountB1 = 200 * 10**18;
        
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA1,
            amountB1,
            amountA1,
            amountB1,
            address(this),
            block.timestamp + 3600
        );
        
        // Now add more liquidity with unbalanced amounts
        uint amountA2 = 50 * 10**18;
        uint amountB2 = 150 * 10**18; // Unbalanced, should be 100 for optimal
        
        (uint actualA, uint actualB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA2,
            amountB2,
            0,
            0,
            address(this),
            block.timestamp + 3600
        );
        
        // Should use amountA2 and calculate optimal B based on reserves
        assertEq(actualA, amountA2);
        assertEq(actualB, 100 * 10**18); // Should match the ratio of the first addition
        assertGt(liquidity, 0);
    }
    
    // Test addLiquidity with expired deadline
    function testAddLiquidityExpiredDeadline() public {
        uint amountA = 100 * 10**18;
        uint amountB = 200 * 10**18;
        
        // Set deadline in the past
        uint256 deadline = block.timestamp - 1;
        
        vm.expectRevert(bytes("UniswapV2Router: EXPIRED"));
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            amountA,
            amountB,
            address(this),
            deadline
        );
    }
    
    // Test addLiquidityETH
    function testAddLiquidityETH() public {
        uint amountToken = 100 * 10**18;
        uint amountETH = 1 ether;
        
        (uint actualToken, uint actualETH, uint liquidity) = router.addLiquidityETH{value: amountETH}(
            address(tokenA),
            amountToken,
            amountToken,
            amountETH,
            address(this),
            block.timestamp + 3600
        );
        
        assertEq(actualToken, amountToken);
        assertEq(actualETH, amountETH);
        assertGt(liquidity, 0);
        
        address pair = factory.getPair(address(tokenA), address(weth));
        assertNotEq(pair, address(0));
    }
    
    // Test addLiquidityETH with ETH refund
    function testAddLiquidityETHWithRefund() public {
        uint amountToken = 100 * 10**18;
        uint amountETH = 1 ether;
        uint extraETH = 0.5 ether;
        
        uint balanceBefore = address(this).balance;
        
        (uint actualToken, uint actualETH, uint liquidity) = router.addLiquidityETH{value: amountETH + extraETH}(
            address(tokenA),
            amountToken,
            amountToken,
            amountETH,
            address(this),
            block.timestamp + 3600
        );
        
        uint balanceAfter = address(this).balance;
        
        assertEq(actualToken, amountToken);
        assertEq(actualETH, amountETH);
        assertGt(liquidity, 0);
        // Verify refund was received
        assertEq(balanceAfter, balanceBefore - amountETH);
    }
    
    // Test removeLiquidity
    function testRemoveLiquidity() public {
        // First add liquidity
        uint amountA = 100 * 10**18;
        uint amountB = 200 * 10**18;
        
        (,, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            amountA,
            amountB,
            address(this),
            block.timestamp + 3600
        );
        
        address pair = factory.getPair(address(tokenA), address(tokenB));
        
        // Approve router to spend LP tokens
        IERC20(pair).approve(address(router), liquidity);
        
        // Mock transfer call since it's not a real pair in test
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IUniswapV2PairExt.get_transferFrom.selector),
            abi.encode()
        );
        
        (uint amountARemoved, uint amountBRemoved) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            1, // min amount
            1, // min amount
            address(this),
            block.timestamp + 3600
        );
        
        assertGt(amountARemoved, 0);
        assertGt(amountBRemoved, 0);
    }
    
    // Test removeLiquidityETH
    function testRemoveLiquidityETH() public {
        // First add liquidity
        uint amountToken = 100 * 10**18;
        uint amountETH = 1 ether;
        
        (,, uint liquidity) = router.addLiquidityETH{value: amountETH}(
            address(tokenA),
            amountToken,
            amountToken,
            amountETH,
            address(this),
            block.timestamp + 3600
        );
        
        address pair = factory.getPair(address(tokenA), address(weth));
        
        // Approve router to spend LP tokens
        IERC20(pair).approve(address(router), liquidity);
        
        // Mock transfer call since it's not a real pair in test
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IUniswapV2PairExt.get_transferFrom.selector),
            abi.encode()
        );
        
        uint balanceBefore = address(this).balance;
        
        (uint amountTokenRemoved, uint amountETHRemoved) = router.removeLiquidityETH(
            address(tokenA),
            liquidity,
            1, // min token amount
            1, // min ETH amount
            address(this),
            block.timestamp + 3600
        );
        
        uint balanceAfter = address(this).balance;
        
        assertGt(amountTokenRemoved, 0);
        assertGt(amountETHRemoved, 0);
        assertEq(balanceAfter, balanceBefore + amountETHRemoved);
    }
    
    // Test removeLiquidityWithPermit
    function testRemoveLiquidityWithPermit() public {
        // First add liquidity
        uint amountA = 100 * 10**18;
        uint amountB = 200 * 10**18;
        
        (,, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            amountA,
            amountB,
            address(this),
            block.timestamp + 3600
        );
        
        address pair = factory.getPair(address(tokenA), address(tokenB));
        
        // Mock permit call since we can't generate a real signature in the test
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IUniswapV2PairExt.get_permit.selector),
            abi.encode()
        );
        
        (uint amountARemoved, uint amountBRemoved) = router.removeLiquidityWithPermit(
            address(tokenA),
            address(tokenB),
            liquidity,
            1, // min amount
            1, // min amount
            address(this),
            block.timestamp + 3600,
            false, // approveMax
            0, // v
            bytes32(0), // r
            bytes32(0) // s
        );
        
        assertGt(amountARemoved, 0);
        assertGt(amountBRemoved, 0);
    }
    
    // Test removeLiquidityETHWithPermit
    function testRemoveLiquidityETHWithPermit() public {
        // First add liquidity
        uint amountToken = 100 * 10**18;
        uint amountETH = 1 ether;
        
        (,, uint liquidity) = router.addLiquidityETH{value: amountETH}(
            address(tokenA),
            amountToken,
            amountToken,
            amountETH,
            address(this),
            block.timestamp + 3600
        );
        
        address pair = factory.getPair(address(tokenA), address(weth));
        
        // Mock permit call since we can't generate a real signature in the test
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IUniswapV2PairExt.get_permit.selector),
            abi.encode()
        );
        
        (uint amountTokenRemoved, uint amountETHRemoved) = router.removeLiquidityETHWithPermit(
            address(tokenA),
            liquidity,
            1, // min token amount
            1, // min ETH amount
            address(this),
            block.timestamp + 3600,
            false, // approveMax
            0, // v
            bytes32(0), // r
            bytes32(0) // s
        );
        
        assertGt(amountTokenRemoved, 0);
        assertGt(amountETHRemoved, 0);
    }
    
    // Test removeLiquidityETHSupportingFeeOnTransferTokens
    function testRemoveLiquidityETHSupportingFeeOnTransferTokens() public {
        // First add liquidity with fee token
        uint amountToken = 100 * 10**18;
        uint amountETH = 1 ether;
        
        // Temporarily disable fee for adding liquidity
        feeToken.setTransferFee(false);
        
        (,, uint liquidity) = router.addLiquidityETH{value: amountETH}(
            address(feeToken),
            amountToken,
            amountToken,
            amountETH,
            address(this),
            block.timestamp + 3600
        );
        
        // Re-enable fee for removal
        feeToken.setTransferFee(true);
        
        address pair = factory.getPair(address(feeToken), address(weth));
        
        // Approve router to spend LP tokens
        IERC20(pair).approve(address(router), liquidity);
        
        // Mock transfer call since it's not a real pair in test
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IUniswapV2PairExt.get_transferFrom.selector),
            abi.encode()
        );
        
        uint balanceBefore = address(this).balance;
        uint tokenBalanceBefore = feeToken.balanceOf(address(this));
        
        uint amountETHRemoved = router.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(feeToken),
            liquidity,
            1, // min token amount
            1, // min ETH amount
            address(this),
            block.timestamp + 3600
        );
        
        uint balanceAfter = address(this).balance;
        uint tokenBalanceAfter = feeToken.balanceOf(address(this));
        
        assertGt(amountETHRemoved, 0);
        assertGt(tokenBalanceAfter, tokenBalanceBefore);
        assertEq(balanceAfter, balanceBefore + amountETHRemoved);
    }
    
    // Test removeLiquidityETHWithPermitSupportingFeeOnTransferTokens
    function testRemoveLiquidityETHWithPermitSupportingFeeOnTransferTokens() public {
        // First add liquidity with fee token
        uint amountToken = 100 * 10**18;
        uint amountETH = 1 ether;
        
        // Temporarily disable fee for adding liquidity
        feeToken.setTransferFee(false);
        
        (,, uint liquidity) = router.addLiquidityETH{value: amountETH}(
            address(feeToken),
            amountToken,
            amountToken,
            amountETH,
            address(this),
            block.timestamp + 3600
        );
        
        // Re-enable fee for removal
        feeToken.setTransferFee(true);
        
        address pair = factory.getPair(address(feeToken), address(weth));
        
        // Mock permit call since we can't generate a real signature in the test
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IUniswapV2PairExt.get_permit.selector),
            abi.encode()
        );
        
        uint balanceBefore = address(this).balance;
        
        uint amountETHRemoved = router.removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
            address(feeToken),
            liquidity,
            1, // min token amount
            1, // min ETH amount
            address(this),
            block.timestamp + 3600,
            false, // approveMax
            0, // v
            bytes32(0), // r
            bytes32(0) // s
        );
        
        uint balanceAfter = address(this).balance;
        
        assertGt(amountETHRemoved, 0);
        assertEq(balanceAfter, balanceBefore + amountETHRemoved);
    }
    
    // Test swapExactTokensForTokens
    function testSwapExactTokensForTokens() public {
        // Setup pairs
        createPairWithLiquidity(tokenA, tokenB, 1000 * 10**18, 1000 * 10**18);
        createPairWithLiquidity(tokenB, tokenC, 1000 * 10**18, 1000 * 10**18);
        
        uint amountIn = 10 * 10**18;
        uint amountOutMin = 9 * 10**18; // Allowing for some slippage
        
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        
        uint tokenCBefore = tokenC.balanceOf(user);
        
        vm.startPrank(user);
        uint[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            user,
            block.timestamp + 3600
        );
        vm.stopPrank();
        
        uint tokenCAfter = tokenC.balanceOf(user);
        
        assertEq(amounts[0], amountIn);
        assertGt(amounts[2], amountOutMin);
        assertEq(tokenCAfter - tokenCBefore, amounts[2]);
    }
    
    // Test swapTokensForExactTokens
    function testSwapTokensForExactTokens() public {
        // Setup pairs
        createPairWithLiquidity(tokenA, tokenB, 1000 * 10**18, 1000 * 10**18);
        
        uint amountOut = 10 * 10**18;
        uint amountInMax = 11 * 10**18; // Allowing for some slippage
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint tokenABefore = tokenA.balanceOf(user);
        uint tokenBBefore = tokenB.balanceOf(user);
        
        vm.startPrank(user);
        uint[] memory amounts = router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            user,
            block.timestamp + 3600
        );
        vm.stopPrank();
        
        uint tokenAAfter = tokenA.balanceOf(user);
        uint tokenBAfter = tokenB.balanceOf(user);
        
        assertLe(amounts[0], amountInMax);
        assertEq(amounts[1], amountOut);
        assertEq(tokenABefore - tokenAAfter, amounts[0]);
        assertEq(tokenBAfter - tokenBBefore, amountOut);
    }
    
    // Test swapExactETHForTokens
    function testSwapExactETHForTokens() public {
        // Setup WETH-TokenA pair
        weth.deposit{value: 1000 ether}();
        createPairWithLiquidity(weth, tokenA, 1000 * 10**18, 1000 * 10**18);
        
        uint amountIn = 1 ether;
        uint amountOutMin = 0.9 * 10**18; // Allowing for some slippage
        
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);
        
        uint tokenABefore = tokenA.balanceOf(user);
        uint ethBefore = user.balance;
        
        vm.startPrank(user);
        uint[] memory amounts = router.swapExactETHForTokens{value: amountIn}(
            amountOutMin,
            path,
            user,
            block.timestamp + 3600
        );
        vm.stopPrank();
        
        uint tokenAAfter = tokenA.balanceOf(user);
        uint ethAfter = user.balance;
        
        assertEq(amounts[0], amountIn);
        assertGt(amounts[1], amountOutMin);
        assertEq(tokenAAfter - tokenABefore, amounts[1]);
        assertEq(ethBefore - ethAfter, amountIn);
    }
}
    
    // // Test swapTokensForExactETH
    // function testSwapTokensForExactETH() public {
    //     // Setup TokenA-WETH pair
    //     weth.deposit{value: 1000 ether}();
    //     createPairWithLiquidity(tokenA, weth, 1000 * 10**18, 1000 * 10**18);
        
    //     uint amountOut = 1 ether;
    //     uint amountInMax = 1.1 * 10**18; // Allowing for some slippage
        
    //     address[] memory path = new address[](2);
    //     path[0] = address(tokenA);
    //     path[1] = address(weth);
        
    //     uint tokenABefore = tokenA.balanceOf(user);
    //     uint ethBefore = user.balance;
        
    //     vm.startPrank(user);
    //     uint[] memory amounts = router.swapTokensForExactETH(
    //         amountOut,
    //         amountInMax,
    //         path,
    //         user,
    //         block.timestamp + 3600
    //     );
    //     vm.stopPrank();
        
    //     uint tokenAAfter = tokenA.balanceOf(user);
    //     uint ethAfter = user.balance;
        
    //     assertLe(