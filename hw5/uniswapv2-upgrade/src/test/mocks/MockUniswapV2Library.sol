// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library MockUniswapV2Library {
    function getAmountsOut(
        address factory,
        uint amountIn,
        address[] memory path
    ) internal pure returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i = 1; i < path.length; i++) {
            amounts[i] = amounts[i-1] * 98 / 100; // Mock 2% slippage
        }
    }

    function getAmountsIn(
        address factory,
        uint amountOut,
        address[] memory path
    ) internal pure returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[path.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            amounts[i-1] = amounts[i] * 102 / 100; // Mock 2% premium
        }
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}