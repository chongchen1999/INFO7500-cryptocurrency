// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "src/core/interfaces/IUniswapV2Factory.sol";

contract MockFactory is IUniswapV2Factory {
    address public override feeTo;
    address public override feeToSetter;
    mapping(address => mapping(address => address)) private pairs;
    address[] public override allPairs;

    function getPair(address tokenA, address tokenB) external view override returns (address) {
        // Ensure tokens are ordered correctly
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return pairs[token0][token1];
    }

    function setPair(address tokenA, address tokenB, address pair) external {
        // Ensure tokens are ordered correctly
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair; // Add reverse mapping as well
        
        // Only add to allPairs if it doesn't exist
        bool exists = false;
        for (uint i = 0; i < allPairs.length; i++) {
            if (allPairs[i] == pair) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            allPairs.push(pair);
        }
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address) {
        require(tokenA != tokenB, 'UniswapV2Factory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Factory: ZERO_ADDRESS');
        require(pairs[token0][token1] == address(0), 'UniswapV2Factory: PAIR_EXISTS');
        
        // For testing purposes, we return a deterministic address
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        address pair = address(uint160(uint(salt)));
        
        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;
        allPairs.push(pair);
        
        return pair;
    }

    function setFeeTo(address _feeTo) external override {
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        feeToSetter = _feeToSetter;
    }
}