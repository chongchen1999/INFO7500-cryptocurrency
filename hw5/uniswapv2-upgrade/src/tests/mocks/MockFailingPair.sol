// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Mock contract that simulates a pair that fails on getReserves
contract MockFailingPair {
    function getReserves() external pure returns (uint112, uint112, uint32) {
        revert("FORCED_FAILURE");
    }

    function mint(address) external pure returns (uint) {
        return 100; // Return some dummy liquidity value
    }
}

// Mock factory that returns the failing pair
contract MockFailingFactory {
    address public immutable failingPair;

    constructor(address _failingPair) {
        failingPair = _failingPair;
    }

    function getPair(address, address) external view returns (address) {
        return failingPair;
    }

    function createPair(address, address) external pure returns (address) {
        revert("Should not be called");
    }
}