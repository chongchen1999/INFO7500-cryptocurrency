// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;


// A library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
// Range: [0, 2**112 - 1]
// Resolution: 1 / 2**112

library UQ112x112 {
    uint224 constant Q112 = 2**112;

    // Encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224) {
        return uint224(y) * Q112; // Never overflows
    }

    // Divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224) {
        require(y > 0, "UQ112x112: DIV_BY_ZERO");
        return x / uint224(y);
    }
}

