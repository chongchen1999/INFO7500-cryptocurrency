// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "src/core/interfaces/IUniswapV2Factory.sol";
import "./MockPair.sol";

contract MockFactory is IUniswapV2Factory {
    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;
    address public feeTo_;
    address public feeToSetter_;
    
    function feeTo() external view returns (address) {
        return feeTo_;
    }
    
    function feeToSetter() external view returns (address) {
        return feeToSetter_;
    }
    
    function getPair(address tokenA, address tokenB) external view returns (address) {
        return pairs[tokenA][tokenB];
    }
    
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }
    
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2Factory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Factory: ZERO_ADDRESS');
        require(pairs[token0][token1] == address(0), 'UniswapV2Factory: PAIR_EXISTS');
        
        bytes memory bytecode = type(MockPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        MockPair(pair).initialize(token0, token1);
        // Set factory address in pair
        MockPair(pair).setFactory(address(this));
        
        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;
        allPairs.push(pair);
        
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
    
    function setFeeTo(address _feeTo) external {
        feeTo_ = _feeTo;
    }
    
    function setFeeToSetter(address _feeToSetter) external {
        feeToSetter_ = _feeToSetter;
    }
}