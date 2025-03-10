// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IUniswapV2Pair {
    // Events
    // event Approval(address indexed owner, address indexed spender, uint256 value);
    // event Transfer(address indexed from, address indexed to, uint256 value);

    // event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    // event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    // event Swap(
    //     address indexed sender,
    //     uint256 amount0In,
    //     uint256 amount1In,
    //     uint256 amount0Out,
    //     uint256 amount1Out,
    //     address indexed to
    // );
    // event Sync(uint112 reserve0, uint112 reserve1);

    // Constants
    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    // Metadata
    // function name() external pure returns (string memory);
    // function getName() external pure returns (string memory);

    // function symbol() external pure returns (string memory);
    // function getSymbol() external pure returns (string memory);

    // function decimals() external pure returns (uint8);
    // function getDecimals() external pure returns (uint8);

    // ERC20-like Functions
    // function totalSupply() external view returns (uint256);
    // function getTotalSupply() external view returns (uint256);

    // function balanceOf(address owner) external view returns (uint256);
    // function getBalanceOf(address owner) external view returns (uint256);

    // function allowance(address owner, address spender) external view returns (uint256);
    // function getAllowance(address owner, address spender) external view returns (uint256);

    // function approve(address spender, uint256 value) external returns (bool);
    // function getApproval(address spender, uint256 value) external returns (bool);

    // function transfer(address to, uint256 value) external returns (bool);
    // function getTransfer(address to, uint256 value) external returns (bool);

    // function transferFrom(address from, address to, uint256 value) external returns (bool);
    // function getTransferFrom(address from, address to, uint256 value) external returns (bool);

    // Permit (EIP-2612)
    // function DOMAIN_SEPARATOR() external view returns (bytes32);
    // function getDomainSeparator() external view returns (bytes32);

    // function PERMIT_TYPEHASH() external pure returns (bytes32);
    // function getPermitTypeHash() external pure returns (bytes32);

    // function nonces(address owner) external view returns (uint256);
    // function getNonces(address owner) external view returns (uint256);

    // function permit(
    //     address owner,
    //     address spender,
    //     uint256 value,
    //     uint256 deadline,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) external;
    // function getPermit(
    //     address owner,
    //     address spender,
    //     uint256 value,
    //     uint256 deadline,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) external;

    // AMM Functions
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address token0, address token1) external;


}