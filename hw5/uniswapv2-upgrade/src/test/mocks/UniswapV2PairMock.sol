// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "src/core/interfaces/IUniswapV2Pair.sol";
import "src/core/interfaces/IERC20.sol";

contract UniswapV2PairMock is IUniswapV2Pair {
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;
    
    uint public override price0CumulativeLast;
    uint public override price1CumulativeLast;
    uint public override kLast;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    event Sync(uint112 reserve0, uint112 reserve1);
    event Skim(address indexed to);
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );

    function getReserves() public view override returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = uint32(block.timestamp);
    }

    function setReserves(uint112 _reserve0, uint112 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        blockTimestampLast = uint32(block.timestamp);
    }

    function mint(address to) external override returns (uint liquidity) {
        require(to != address(0), "UniswapV2: ZERO_ADDRESS");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        
        if (_reserve0 == 0 && _reserve1 == 0) {
            liquidity = 100;  // Initial liquidity
        } else {
            liquidity = 50;   // Subsequent liquidity
        }
        
        emit Mint(msg.sender, liquidity, liquidity);
        return liquidity;
    }

    function burn(address to) external override returns (uint amount0, uint amount1) {
        amount0 = 50;
        amount1 = 50;
        emit Burn(msg.sender, amount0, amount1, to);
        return (amount0, amount1);
    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external override {
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');
        
        if(amount0Out > 0) IERC20(address(this)).transfer(to, amount0Out);
        if(amount1Out > 0) IERC20(address(this)).transfer(to, amount1Out);
        
        emit Swap(msg.sender, amount0Out, amount1Out, to);
    }

    function skim(address to) external override {
        emit Skim(to);
    }

    function sync() external override {
        emit Sync(reserve0, reserve1);
    }

    function initialize(address, address) external override {
        // Implementation not needed for testing
    }

    function get_permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external override {
        emit Approval(owner, spender, value);
    }

    function get_transferFrom(address from, address to, uint value) external override returns (bool) {
        emit Transfer(from, to, value);
        return true;
    }
}