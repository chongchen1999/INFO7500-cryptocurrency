// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "src/core/interfaces/IUniswapV2Pair.sol";
import "src/core/interfaces/IERC20.sol";
import "forge-std/console.sol";

contract MockPair is IUniswapV2Pair {
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;
    address private _token0;
    address private _token1;
    
    // New fields for improved mocking
    bool public swapImplemented = true;
    uint private mockAmountOut;
    uint private mockAmountIn;
    mapping(address => uint) private balances;
    uint256 private _totalSupply;

    function setTokens(address token0_, address token1_) external {
        _token0 = token0_;
        _token1 = token1_;
    }

    function setReserves(uint112 _reserve0, uint112 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        blockTimestampLast = uint32(block.timestamp);
    }

    // Set whether the swap implementation is active
    function setSwapImplementation(bool _implemented) external {
        swapImplemented = _implemented;
    }
    
    // Set mock values for getAmountOut calculations
    function setAmountOut(uint _amountOut) external {
        mockAmountOut = _amountOut;
    }
    
    // Set mock values for getAmountIn calculations
    function setAmountIn(uint _amountIn) external {
        mockAmountIn = _amountIn;
    }

    // Helper function to set balances for testing
    function setBalance(address account, uint amount) external {
        balances[account] = amount;
    }
    
    // Helper function to set total supply for testing
    function setTotalSupply(uint256 amount) external {
        _totalSupply = amount;
    }

    // Helper for the router to calculate amounts
    function getAmountOut(uint amountIn) external view returns (uint) {
        // Return the mock value if set, otherwise calculate based on reserves
        if (mockAmountOut > 0) {
            return mockAmountOut;
        }
        
        // Simple calculation (ignoring fees for simplicity)
        return (amountIn * reserve1) / reserve0;
    }
    
    // Helper for the router to calculate input amounts
    function getAmountIn(uint amountOut) external view returns (uint) {
        // Return the mock value if set, otherwise calculate based on reserves
        if (mockAmountIn > 0) {
            return mockAmountIn;
        }
        
        // Simple calculation (ignoring fees for simplicity)
        return (amountOut * reserve0) / reserve1;
    }

    // Interface implementations with new enhanced functionality
    function getReserves() external view override returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function token0() external view override returns (address) {
        return _token0;
    }

    function token1() external view override returns (address) {
        return _token1;
    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external override {
        require(swapImplemented, "MockPair: swap not implemented");
        
        // Basic validation
        require(amount0Out > 0 || amount1Out > 0, "Insufficient output amount");
        require(to != address(0), "Invalid to address");
        
        // Optionally log for debugging
        console.log("MockPair: swap called with amount0Out=%d, amount1Out=%d", amount0Out, amount1Out);
        
        // Simulate transfers
        if (amount0Out > 0) {
            // Transfer token0 to the 'to' address
            IERC20(_token0).transfer(to, amount0Out);
        }
        
        if (amount1Out > 0) {
            // Transfer token1 to the 'to' address
            IERC20(_token1).transfer(to, amount1Out);
        }
    }

    // Required interface implementations with improved implementations
    function get_name() external pure override returns (string memory) { 
        return "Mock Pair"; 
    }
    
    function get_symbol() external pure override returns (string memory) { 
        return "MOCK-LP"; 
    }
    
    function get_decimals() external pure override returns (uint8) { 
        return 18; 
    }
    
    function get_totalSupply() external view override returns (uint256) { 
        return _totalSupply; 
    }
    
    function get_balanceOf(address account) external view override returns (uint256) { 
        return balances[account]; 
    }
    
    function get_allowance(address, address) external view override returns (uint256) { 
        return type(uint256).max; // Allow unlimited allowance for easier testing
    }
    
    function get_approve(address, uint256) external override returns (bool) { 
        return true; 
    }
    
    function get_transfer(address to, uint256 amount) external override returns (bool) { 
        // Simulate transfer for testing purposes
        address from = msg.sender;
        balances[from] -= amount;
        balances[to] += amount;
        return true; 
    }
    
    function get_transferFrom(address from, address to, uint256 amount) external override returns (bool) { 
        // Simulate transferFrom for testing purposes
        balances[from] -= amount;
        balances[to] += amount;
        return true;
    }
    
    function get_DOMAIN_SEPARATOR() external view override returns (bytes32) { 
        return bytes32(0); 
    }
    
    function get_PERMIT_TYPEHASH() external pure override returns (bytes32) { 
        return bytes32(0); 
    }
    
    function get_nonces(address) external view override returns (uint256) { 
        return 0; 
    }
    
    function get_permit(address, address, uint256, uint256, uint8, bytes32, bytes32) external override {}

    function MINIMUM_LIQUIDITY() external pure override returns (uint) { 
        return 10**3; 
    }
    
    function factory() external pure override returns (address) { 
        return address(0); 
    }
    
    function price0CumulativeLast() external pure override returns (uint) { 
        return 0; 
    }
    
    function price1CumulativeLast() external pure override returns (uint) { 
        return 0; 
    }
    
    function kLast() external pure override returns (uint) { 
        return 0; 
    }
    
    function mint(address) external pure override returns (uint) { 
        return 0; 
    }
    
    function burn(address) external pure override returns (uint, uint) { 
        return (0, 0); 
    }
    
    function skim(address) external pure override {}
    
    function sync() external pure override {}
    
    function initialize(address, address) external pure override {}
}