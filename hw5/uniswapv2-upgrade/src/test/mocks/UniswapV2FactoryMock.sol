// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "src/core/interfaces/IUniswapV2Factory.sol";
import "src/test/mocks/UniswapV2PairMock.sol";

contract UniswapV2FactoryMock is IUniswapV2Factory {
    mapping(address => mapping(address => address)) public override getPair;
    address[] public allPairs;
    
    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS');
        
        UniswapV2PairMock pairMock = new UniswapV2PairMock();
        pair = address(pairMock);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }
}
