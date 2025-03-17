// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "lib/forge-std/src/Test.sol";

// ============ Mock Contracts ============
import "src/contracts/UniswapV2Factory.sol";
import "src/contracts/UniswapV2Router02.sol";
import "src/tests/mocks/MockERC20.sol";
import "src/tests/mocks/MockWETH9.sol";

// The fee on transfer token implementation
contract ERC20FeeOnTransfer is MockERC20 {
    uint256 public feePercentage;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _feePercentage
    ) MockERC20(_name, _symbol) {
        feePercentage = _feePercentage;
    }
}

contract UniswapV2RouterTestBase is Test {
    UniswapV2Factory factory;
    UniswapV2Router02 router;
    MockERC20 tokenA;
    MockERC20 tokenB;
    MockWETH9 weth;
    ERC20FeeOnTransfer feeToken;

    address user = address(0x999);
    address otherUser = address(0x888);

    uint8 v;
    bytes32 r;
    bytes32 s;

    function setUp() public virtual {
        // Deploy contracts
        factory = new UniswapV2Factory(address(this));
        weth = new MockWETH9();
        router = new UniswapV2Router02(address(factory), address(weth));

        // Deploy tokens
        tokenA = new MockERC20("TokenA", "TKA");
        tokenB = new MockERC20("TokenB", "TKB");
        feeToken = new ERC20FeeOnTransfer("FeeToken", "FEE", 10); // 1% transfer tax

        // Mint tokens to users
        tokenA.mint(user, 1_000_000 ether);
        tokenB.mint(user, 1_000_000 ether);
        feeToken.mint(user, 1_000_000 ether);

        tokenA.mint(otherUser, 1_000_000 ether);
        tokenB.mint(otherUser, 1_000_000 ether);
        feeToken.mint(otherUser, 1_000_000 ether);

        // Give ETH to users
        vm.deal(user, 100 ether);
        vm.deal(otherUser, 100 ether);
    }
}