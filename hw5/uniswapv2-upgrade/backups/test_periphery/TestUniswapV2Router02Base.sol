// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "src/core/UniswapV2Factory.sol";
import "src/periphery/UniswapV2Router02.sol";
import "src/test/mocks/ERC20Mintable.sol";
import "src/test/mocks/WETH9.sol";
import "./ERC20FeeOnTransfer.sol";

contract TestUniswapV2Router02Base is Test {
    UniswapV2Factory factory;
    UniswapV2Router02 router;
    ERC20Mintable tokenA;
    ERC20Mintable tokenB;
    WETH9 weth;
    ERC20FeeOnTransfer feeToken;

    address user = address(0x999);
    address otherUser = address(0x888);

    uint8 v;
    bytes32 r;
    bytes32 s;

    function setUp() public virtual {
        factory = new UniswapV2Factory(address(this));
        weth = new WETH9();
        router = new UniswapV2Router02(address(factory), address(weth));

        tokenA = new ERC20Mintable("TokenA", "TKA");
        tokenB = new ERC20Mintable("TokenB", "TKB");
        feeToken = new ERC20FeeOnTransfer("FeeToken", "FEE", 10);

        tokenA.mint(user, 1_000_000 ether);
        tokenB.mint(user, 1_000_000 ether);
        feeToken.mint(user, 1_000_000 ether);

        tokenA.mint(otherUser, 1_000_000 ether);
        tokenB.mint(otherUser, 1_000_000 ether);
        feeToken.mint(otherUser, 1_000_000 ether);

        vm.deal(user, 100 ether);
        vm.deal(otherUser, 100 ether);
    }
}