// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "src/core/interfaces/IUniswapV2Pair.sol";

contract MockPair is IUniswapV2Pair {
    address public token0;
    address public token1;
    address public factory_;
    uint112 private reserve0;
    uint112 private reserve1;
    uint32  private blockTimestampLast;
    
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    uint256 private totalSupply_;
    
    function initialize(address _token0, address _token1) external {
        token0 = _token0;
        token1 = _token1;
    }
    
    function setFactory(address _factory) external {
        factory_ = _factory;
    }

    function MINIMUM_LIQUIDITY() external pure returns (uint256) {
        return 1000;
    }

    function factory() external view returns (address) {
        return factory_;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function get_DOMAIN_SEPARATOR() external pure returns (bytes32) {
        return bytes32(0);
    }

    function get_PERMIT_TYPEHASH() external pure returns (bytes32) {
        return bytes32(0);
    }

    function get_name() external pure returns (string memory) {
        return "Uniswap V2";
    }

    function get_symbol() external pure returns (string memory) {
        return "UNI-V2";
    }

    function get_decimals() external pure returns (uint8) {
        return 18;
    }

    function get_totalSupply() external view returns (uint256) {
        return totalSupply_;
    }

    function get_balanceOf(address owner) external view returns (uint256) {
        return balances[owner];
    }

    function get_allowance(address owner, address spender) external view returns (uint256) {
        return allowances[owner][spender];
    }

    function get_approve(address spender, uint256 value) external returns (bool) {
        allowances[msg.sender][spender] = value;
        return true;
    }

    function get_transfer(address to, uint256 value) external returns (bool) {
        balances[msg.sender] -= value;
        balances[to] += value;
        return true;
    }

    function get_transferFrom(address from, address to, uint256 value) external returns (bool) {
        balances[from] -= value;
        balances[to] += value;
        if(allowances[from][msg.sender] != type(uint256).max) {
            allowances[from][msg.sender] -= value;
        }
        return true;
    }

    function get_permit(
        address owner,
        address spender,
        uint value,
        uint /* deadline */,
        uint8 /* v */,
        bytes32 /* r */,
        bytes32 /* s */
    ) external {
        allowances[owner][spender] = value;
    }

    function get_nonces(address /* owner */) external pure returns (uint256) {
        return 0;
    }

    function mint(address to) external returns (uint liquidity) {
        // Set some initial reserves for price calculation
        reserve0 = 1000e18;
        reserve1 = 1000e18;
        
        liquidity = 100e18;
        totalSupply_ += liquidity;
        balances[to] += liquidity;
        return liquidity;
    }

    function burn(address /* to */) external returns (uint amount0, uint amount1) {
        amount0 = reserve0;
        amount1 = reserve1;
        reserve0 = 0;
        reserve1 = 0;
        return (amount0, amount1);
    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata /* data */) external {
        if(amount0Out > 0) {
            _safeTransfer(token0, to, amount0Out);
        }
        if(amount1Out > 0) {
            _safeTransfer(token1, to, amount1Out);
        }
    }

    function skim(address to) external {
        // Mock implementation - do nothing
    }

    function sync() external {
        // Mock implementation - do nothing
    }

    function price0CumulativeLast() external pure returns (uint256) {
        return 0;
    }

    function price1CumulativeLast() external pure returns (uint256) {
        return 0;
    }

    function kLast() external pure returns (uint256) {
        return 0;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Mock: TRANSFER_FAILED');
    }
}