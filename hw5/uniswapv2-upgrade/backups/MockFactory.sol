// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "src/interfaces/IUniswapV2Factory.sol";

contract MockFactory is IUniswapV2Factory {
    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;

    function setPair(address tokenA, address tokenB, address pair) external {
        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair; // Set both directions
        allPairs.push(pair);
    }

    function getPair(address tokenA, address tokenB) external view override returns (address) {
        return pairs[tokenA][tokenB];
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        require(tokenA != address(0) && tokenB != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(pairs[tokenA][tokenB] == address(0), 'UniswapV2: PAIR_EXISTS');
        
        // For testing, we just return a dummy address
        pairs[tokenA][tokenB] = address(uint160(uint(keccak256(abi.encodePacked(tokenA, tokenB)))));
        pairs[tokenB][tokenA] = pairs[tokenA][tokenB];
        allPairs.push(pairs[tokenA][tokenB]);
        
        return pairs[tokenA][tokenB];
    }

    function setFeeTo(address) external override {}
    function setFeeToSetter(address) external override {}
    function feeTo() external pure override returns (address) { return address(0); }
    function feeToSetter() external pure override returns (address) { return address(0); }
}