// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// a library for performing various math operations

library Math {
    function safeAdd(uint x, uint y) public pure returns (uint) {
        return x + y; // 自动检查溢出
    }

    function safeSub(uint x, uint y) public pure returns (uint) {
        return x - y; // 自动检查下溢
    }

    function safeMul(uint x, uint y) public pure returns (uint) {
        return x * y; // 自动检查溢出
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }
    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
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
