// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// A library for performing various math operations
library Math {
    function safeAdd(uint x, uint y) public pure returns (uint) {
        return x + y; 
    }

    function safeSub(uint x, uint y) public pure returns (uint) {
        return x - y; 
    }

    function safeMul(uint x, uint y) public pure returns (uint) {
        return x * y; 
    }

    function min(uint x, uint y) internal pure returns (uint) {
        return x < y ? x : y;
    }

    // Babylonian method for computing square roots
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

