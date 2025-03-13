// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "src/core/interfaces/IUniswapV2Pair.sol";

contract MockPair is IUniswapV2Pair {
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;
    address private _token0;
    address private _token1;

    function setTokens(address token0_, address token1_) external {
        _token0 = token0_;
        _token1 = token1_;
    }

    function setReserves(uint112 _reserve0, uint112 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        blockTimestampLast = uint32(block.timestamp);
    }

    function getReserves() external view override returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function token0() external view override returns (address) {
        return _token0;
    }

    function token1() external view override returns (address) {
        return _token1;
    }

    // Required interface implementations
    function get_name() external pure override returns (string memory) { return "Mock Pair"; }
    function get_symbol() external pure override returns (string memory) { return "MOCK-LP"; }
    function get_decimals() external pure override returns (uint8) { return 18; }
    function get_totalSupply() external view override returns (uint256) { return 0; }
    function get_balanceOf(address) external view override returns (uint256) { return 0; }
    function get_allowance(address, address) external view override returns (uint256) { return 0; }
    function get_approve(address, uint256) external override returns (bool) { return true; }
    function get_transfer(address, uint256) external override returns (bool) { return true; }
    function get_transferFrom(address, address, uint256) external override returns (bool) { return true; }
    function get_DOMAIN_SEPARATOR() external view override returns (bytes32) { return bytes32(0); }
    function get_PERMIT_TYPEHASH() external pure override returns (bytes32) { return bytes32(0); }
    function get_nonces(address) external view override returns (uint256) { return 0; }
    function get_permit(address, address, uint256, uint256, uint8, bytes32, bytes32) external override {}

    // Other required interface functions
    function MINIMUM_LIQUIDITY() external pure override returns (uint) { return 10**3; }
    function factory() external pure override returns (address) { return address(0); }
    function price0CumulativeLast() external pure override returns (uint) { return 0; }
    function price1CumulativeLast() external pure override returns (uint) { return 0; }
    function kLast() external pure override returns (uint) { return 0; }
    function mint(address) external pure override returns (uint) { return 0; }
    function burn(address) external pure override returns (uint, uint) { return (0, 0); }
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external pure override {}
    function skim(address) external pure override {}
    function sync() external pure override {}
    function initialize(address, address) external pure override {}
}