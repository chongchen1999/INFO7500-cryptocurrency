// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/core/interfaces/IUniswapV2Factory.sol";
import "../src/core/interfaces/IUniswapV2Pair.sol";
import "../src/UniswapV2Router02.sol";
import "../src/libraries/UniswapV2Library.sol";
import "../src/interfaces/IERC20.sol";
import "../src/interfaces/IWETH.sol";

contract MockERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint256 initialSupply) {
        name = _name;
        symbol = _symbol;
        _mint(msg.sender, initialSupply);
    }

    function _mint(address to, uint256 value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
}

contract MockWETH is MockERC20, IWETH {
    constructor() MockERC20("Wrapped Ether", "WETH", 0) {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
        emit Transfer(msg.sender, address(0), amount);
    }
}

contract DeflatingERC20 is MockERC20 {
    uint256 public fee = 1; // 1% fee

    constructor(uint256 initialSupply) MockERC20("Deflating Token", "DTT", initialSupply) {}

    function _transfer(address from, address to, uint256 value) internal override {
        uint256 feeAmount = (value * fee) / 100;
        uint256 transferAmount = value - feeAmount;
        
        balanceOf[from] -= value;
        balanceOf[to] += transferAmount;
        totalSupply -= feeAmount; // Burn the fee
        
        emit Transfer(from, to, transferAmount);
        emit Transfer(from, address(0), feeAmount);
    }
}

contract MockUniswapV2Factory is IUniswapV2Factory {
    address public feeTo;
    address public feeToSetter;
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    mapping(address => bool) public isPair;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2Factory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Factory: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2Factory: PAIR_EXISTS');
        
        // Create a mock pair with a predetermined address
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        pair = address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", address(this), salt, hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f")))));
        
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        isPair[pair] = true;
        
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2Factory: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2Factory: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}

contract MockUniswapV2Pair is IUniswapV2Pair {
    address public factory;
    address public token0;
    address public token1;
    
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;
    
    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast;
    
    uint private unlocked = 1;
    
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    uint public totalSupply;
    
    // Event declarations
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    
    constructor(address _token0, address _token1) {
        factory = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }
    
    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN');
        token0 = _token0;
        token1 = _token1;
    }
    
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }
    
    function _update(uint balance0, uint balance1) private {
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }
    
    function mint(address to) external returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;
        
        // Calculate liquidity
        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - 1000; // MINIMUM_LIQUIDITY
            _mint(address(0), 1000); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0 * totalSupply / _reserve0, amount1 * totalSupply / _reserve1);
        }
        
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);
        
        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
        return liquidity;
    }
    
    function burn(address to) external returns (uint amount0, uint amount1) {
        uint liquidity = balanceOf[address(this)];
        
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        
        amount0 = liquidity * balance0 / totalSupply;
        amount1 = liquidity * balance1 / totalSupply;
        
        require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        
        _burn(address(this), liquidity);
        
        IERC20(_token0).transfer(to, amount0);
        IERC20(_token1).transfer(to, amount1);
        
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        
        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);
        
        return (amount0, amount1);
    }
    
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external {
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');
        
        uint balance0;
        uint balance1;
        {
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
            
            if (amount0Out > 0) IERC20(_token0).transfer(to, amount0Out);
            if (amount1Out > 0) IERC20(_token1).transfer(to, amount1Out);
            
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        
        _update(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }
    
    function skim(address to) external {
        address _token0 = token0;
        address _token1 = token1;
        IERC20(_token0).transfer(to, IERC20(_token0).balanceOf(address(this)) - reserve0);
        IERC20(_token1).transfer(to, IERC20(_token1).balanceOf(address(this)) - reserve1);
    }
    
    function sync() external {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }
    
    // Custom functions for testing
    function get_transferFrom(address from, address to, uint value) external returns (bool) {
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
    
    function get_permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
    
    function _mint(address to, uint value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }
    
    function _burn(address from, uint value) internal {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }
    
    function nonces(address owner) external view returns (uint) {
        return 0; // Mock implementation
    }
    
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return keccak256("UniswapV2Pair");
    }
    
    function PERMIT_TYPEHASH() external view returns (bytes32) {
        return keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    }
}

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

contract UniswapV2RouterTest is Test {
    address public factory;
    address public WETH;
    UniswapV2Router02 public router;
    
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockERC20 public tokenC;
    DeflatingERC20 public DTT;
    
    address public owner = address(this);
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    uint256 constant INITIAL_SUPPLY = 1000000 * 1e18;
    uint256 constant TEST_AMOUNT = 1000 * 1e18;
    uint256 constant MAX_UINT = type(uint256).max;
    
    function setUp() public {
        // Deploy tokens
        tokenA = new MockERC20("Token A", "TKA", INITIAL_SUPPLY);
        tokenB = new MockERC20("Token B", "TKB", INITIAL_SUPPLY);
        tokenC = new MockERC20("Token C", "TKC", INITIAL_SUPPLY);
        DTT = new DeflatingERC20(INITIAL_SUPPLY);
        
        // Deploy WETH
        MockWETH weth = new MockWETH();
        WETH = address(weth);
        
        // Deploy factory
        MockUniswapV2Factory factoryContract = new MockUniswapV2Factory(owner);
        factory = address(factoryContract);
        
        // Deploy router
        router = new UniswapV2Router02(factory, WETH);
        
        // Fund users
        tokenA.transfer(user1, TEST_AMOUNT);
        tokenB.transfer(user1, TEST_AMOUNT);
        tokenC.transfer(user1, TEST_AMOUNT);
        DTT.transfer(user1, TEST_AMOUNT);
        
        tokenA.transfer(user2, TEST_AMOUNT);
        tokenB.transfer(user2, TEST_AMOUNT);
        
        // Approve router
        tokenA.approve(address(router), MAX_UINT);
        tokenB.approve(address(router), MAX_UINT);
        tokenC.approve(address(router), MAX_UINT);
        DTT.approve(address(router), MAX_UINT);
        
        vm.startPrank(user1);
        tokenA.approve(address(router), MAX_UINT);
        tokenB.approve(address(router), MAX_UINT);
        tokenC.approve(address(router), MAX_UINT);
        DTT.approve(address(router), MAX_UINT);
        vm.stopPrank();
        
        vm.startPrank(user2);
        tokenA.approve(address(router), MAX_UINT);
        tokenB.approve(address(router), MAX_UINT);
        vm.stopPrank();
        
        // Make sure we have ETH
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }
    
    // Test the constructor
    function testConstructor() public {
        assertEq(router.factory(), factory);
        assertEq(router.WETH(), WETH);
    }
    
    // Test deadline modifier
    function testEnsureModifier() public {
        vm.expectRevert("UniswapV2Router: EXPIRED");
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1e18,
            1e18,
            0,
            0,
            owner,
            block.timestamp - 1 // Expired deadline
        );
    }
    
    // Test receive function
    function testReceive() public {
        // Should only accept ETH from WETH
        vm.expectRevert(); // assert triggered in receive()
        (bool success, ) = address(router).call{value: 1 ether}("");
        assertFalse(success);
        
        // Workaround to test the receive function
        // This would normally happen when WETH sends ETH to the router
        vm.prank(WETH);
        (success, ) = address(router).call{value: 1 ether}("");
        assertTrue(success);
    }
    
    // Test addLiquidity - first liquidity
    function testAddLiquidity_FirstLiquidity() public {
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 * 1e18,
            10 * 1e18,
            9 * 1e18,
            9 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        assertEq(amountA, 10 * 1e18);
        assertEq(amountB, 10 * 1e18);
        assertTrue(liquidity > 0);
    }
    
    // Test addLiquidity - subsequent liquidity
    function testAddLiquidity_Subsequent() public {
        // First add initial liquidity
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 * 1e18,
            10 * 1e18,
            9 * 1e18,
            9 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        // Then add more
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            5 * 1e18,
            5 * 1e18,
            4 * 1e18,
            4 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        assertEq(amountA, 5 * 1e18);
        assertEq(amountB, 5 * 1e18);
        assertTrue(liquidity > 0);
    }
    
    // Test addLiquidity - optimal amounts case 1
    function testAddLiquidity_OptimalAmounts1() public {
        // First add with specific ratio
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 * 1e18,
            5 * 1e18,
            9 * 1e18,
            4 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        // Then add with amounts that need adjustment (B is limiting)
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 * 1e18, // Desired A
            2 * 1e18,  // Desired B
            1 * 1e18,  // Min A
            2 * 1e18,  // Min B
            owner,
            block.timestamp + 1
        );
        
        // Should use all of B and calculate optimal A
        assertEq(amountB, 2 * 1e18);
        assertTrue(amountA < 10 * 1e18); // A should be adjusted down
        assertTrue(liquidity > 0);
    }
    
    // Test addLiquidity - optimal amounts case 2
    function testAddLiquidity_OptimalAmounts2() public {
        // First add with specific ratio
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            5 * 1e18,
            10 * 1e18,
            4 * 1e18,
            9 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        // Then add with amounts that need adjustment (A is limiting)
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            2 * 1e18,  // Desired A
            10 * 1e18, // Desired B
            2 * 1e18,  // Min A
            1 * 1e18,  // Min B
            owner,
            block.timestamp + 1
        );
        
        // Should use all of A and calculate optimal B
        assertEq(amountA, 2 * 1e18);
        assertTrue(amountB < 10 * 1e18); // B should be adjusted down
        assertTrue(liquidity > 0);
    }
    
    // Test addLiquidity - optimal amount fail (insufficient A)
    function testAddLiquidity_InsufficientA() public {
        // First add with specific ratio
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            5 * 1e18,
            10 * 1e18,
            4 * 1e18,
            9 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        // Then try with amounts that need adjustment but will fail on min
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            2 * 1e18,  // Desired A
            10 * 1e18, // Desired B
            2 * 1e18,  // Min A - this will fail because optimal A will be < 2
            1 * 1e18,  // Min B
            owner,
            block.timestamp + 1
        );
    }
    
    // Test addLiquidity - optimal amount fail (insufficient B)
    function testAddLiquidity_InsufficientB() public {
        // First add with specific ratio
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 * 1e18,
            5 * 1e18,
            9 * 1e18,
            4 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        // Then try with amounts that need adjustment but will fail on min
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_B_AMOUNT");
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 * 1e18, // Desired A
            2 * 1e18,  // Desired B
            1 * 1e18,  // Min A
            2.5 * 1e18, // Min B - this will fail because optimal B will be < 2.5
            owner,
            block.timestamp + 1
        );
    }
    
    // Test addLiquidityETH
    function testAddLiquidityETH() public {
        (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{value: 5 * 1e18}(
            address(tokenA),
            10 * 1e18,
            9 * 1e18,
            4 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        assertEq(amountToken, 10 * 1e18);
        assertEq(amountETH, 5 * 1e18);
        assertTrue(liquidity > 0);
    }
    
    // Test addLiquidityETH with refund
    function testAddLiquidityETH_Refund() public {
        uint initialBalance = address(this).balance;
        
        // First add initial liquidity to set the ratio
        router.addLiquidityETH{value: 5 * 1e18}(
            address(tokenA),
            10 * 1e18,
            9 * 1e18,
            4 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        // Now add more, sending excess ETH
        router.addLiquidityETH{value: 3 * 1e18}(
            address(tokenA),
            5 * 1e18,
            4 * 1e18,
            1 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        // Should get a refund if we sent too much ETH
        assertTrue(address(this).balance > initialBalance - 8 * 1e18);
    }
    
    // Test removeLiquidity
    function testRemoveLiquidity() public {
        // First add liquidity
        (,,uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 * 1e18,
            10 * 1e18,
            9 * 1e18,
            9 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        // Get the pair address
        address pair = UniswapV2Library.pairFor(factory, address(tokenA), address(tokenB));
        
        // Approve router to spend LP tokens
        IERC20(pair).approve(address(router), liquidity);
        
        // Remove half the liquidity
        (uint amountA, uint amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity / 2,
            4 * 1e18,
            4 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        assertTrue(amountA >= 4 * 1e18);
        assertTrue(amountB >= 4 * 1e18);
    }
    
    // Test removeLiquidityETH
    function testRemoveLiquidityETH() public {
        // First add liquidity
        (,, uint liquidity) = router.addLiquidityETH{value: 10 * 1e18}(
            address(tokenA),
            10 * 1e18,
            9 * 1e18,
            9 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        // Get the pair address
        address pair = UniswapV2Library.pairFor(factory, address(tokenA), WETH);
        
        // Approve router to spend LP tokens
        IERC20(pair).approve(address(router), liquidity);
        
        uint balanceBefore = address(this).balance;
        
        // Remove half the liquidity
        (uint amountToken, uint amountETH) = router.removeLiquidityETH(
            address(tokenA),
            liquidity / 2,
            4 * 1e18,
            4 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        assertTrue(amountToken >= 4 * 1e18);
        assertTrue(amountETH >= 4 * 1e18);
        assertTrue(address(this).balance > balanceBefore);
    }
    
    // Test removeLiquidityWithPermit
    function testRemoveLiquidityWithPermit() public {
        // First add liquidity
        (,,uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10 * 1e18,
            10 * 1e18,
            9 * 1e18,
            9 * 1e18,
            owner,
            block.timestamp + 1
        );
        
        // Get the pair address
        address pair = UniswapV2Library.pairFor(factory, address(tokenA), address(tokenB));
        
        // Mock values for permit
        uint8 v = 27;
        bytes32 r = bytes32(uint256(1));
        bytes32 s = bytes32(uint256(2));
        
        // Remove liquidity with permit
        (uint amountA, uint amountB) = router.removeLiquidityWithPermit(
            address(tokenA),
            address(tokenB),
            liquidity / 2,
            4 * 1e18,
            4 * 1e18,
            owner,
            block.timestamp + 1,
            false, // not approveMax
            v,
            r,
            s
        );
        
        assertTrue(amountA >= 4 * 1e18);
        assertTrue(amountB >= 4 * 1e18);
    }
    
    // Test removeLiquidityETHWithPermit
    function testRemoveLiquidityETHWithPermit() public {
        // First add liquidity
        (,, uint liquidity) = router.addLiquidityETH{value: 10 * 1e18}(
            address(tokenA),
            10 * 1e18,