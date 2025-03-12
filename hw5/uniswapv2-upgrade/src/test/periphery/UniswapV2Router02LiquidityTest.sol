// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "lib/forge-std/src/Test.sol";
import "src/periphery/UniswapV2Router02.sol";
import "src/test/mocks/UniswapV2FactoryMock.sol";
import "src/test/mocks/UniswapV2WETH9Mock.sol";
import "src/test/mocks/UniswapV2ERC20Mock.sol";
import "src/test/mocks/UniswapV2PairMock.sol";

contract UniswapV2Router02LiquidityTest is Test {
    UniswapV2Router02 public router;
    UniswapV2FactoryMock public factory;
    UniswapV2WETH9Mock public weth;
    UniswapV2ERC20Mock public tokenA;
    UniswapV2ERC20Mock public tokenB;
    uint constant INITIAL_AMOUNT = 1000 ether;
    uint constant DEADLINE = block.timestamp + 1;

    function setUp() public {
        // Deploy contracts
        factory = new UniswapV2FactoryMock();
        weth = new UniswapV2WETH9Mock();
        tokenA = new UniswapV2ERC20Mock();
        tokenB = new UniswapV2ERC20Mock();
        router = new UniswapV2Router02(address(factory), address(weth));

        // Mint initial tokens
        tokenA.mint(address(this), INITIAL_AMOUNT);
        tokenB.mint(address(this), INITIAL_AMOUNT);
        
        // Approve router
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
    }

    function testAddLiquidity() public {
        uint amountADesired = 100 ether;
        uint amountBDesired = 200 ether;
        uint amountAMin = 95 ether;
        uint amountBMin = 195 ether;

        // First add liquidity
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            address(this),
            DEADLINE
        );

        assertEq(amountA, amountADesired, "Incorrect amount A");
        assertEq(amountB, amountBDesired, "Incorrect amount B");
        assertGt(liquidity, 0, "No liquidity minted");

        // Add more liquidity with existing reserves
        address pair = factory.getPair(address(tokenA), address(tokenB));
        UniswapV2PairMock(pair).setReserves(100 ether, 200 ether);

        (amountA, amountB, liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            address(this),
            DEADLINE
        );

        assertEq(amountA, amountADesired, "Incorrect amount A after reserves");
        assertEq(amountB, amountBDesired, "Incorrect amount B after reserves");
        assertGt(liquidity, 0, "No liquidity minted after reserves");
    }

    function testAddLiquidityETH() public {
        uint amountTokenDesired = 100 ether;
        uint amountTokenMin = 95 ether;
        uint amountETHMin = 0.95 ether;
        uint amountETH = 1 ether;

        vm.deal(address(this), amountETH);

        (uint amountToken, uint amountETHOut, uint liquidity) = router.addLiquidityETH{value: amountETH}(
            address(tokenA),
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            address(this),
            DEADLINE
        );

        assertEq(amountToken, amountTokenDesired, "Incorrect token amount");
        assertEq(amountETHOut, amountETH, "Incorrect ETH amount");
        assertGt(liquidity, 0, "No liquidity minted");

        // Test with existing reserves
        address pair = factory.getPair(address(tokenA), address(weth));
        UniswapV2PairMock(pair).setReserves(100 ether, 1 ether);

        vm.deal(address(this), amountETH);
        (amountToken, amountETHOut, liquidity) = router.addLiquidityETH{value: amountETH}(
            address(tokenA),
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            address(this),
            DEADLINE
        );

        assertEq(amountToken, amountTokenDesired, "Incorrect token amount after reserves");
        assertEq(amountETHOut, amountETH, "Incorrect ETH amount after reserves");
        assertGt(liquidity, 0, "No liquidity minted after reserves");
    }

    function testRemoveLiquidity() public {
        // First add liquidity
        uint amountADesired = 100 ether;
        uint amountBDesired = 200 ether;
        
        (,,uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountADesired,
            amountBDesired,
            0,
            0,
            address(this),
            DEADLINE
        );

        // Now remove liquidity
        address pair = factory.getPair(address(tokenA), address(tokenB));
        UniswapV2PairMock(pair).get_permit(address(this), address(router), liquidity, DEADLINE, 0, bytes32(0), bytes32(0));
        
        (uint amountA, uint amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            address(this),
            DEADLINE
        );

        assertGt(amountA, 0, "No token A returned");
        assertGt(amountB, 0, "No token B returned");
    }

    function testRemoveLiquidityETH() public {
        // First add liquidity ETH
        uint amountTokenDesired = 100 ether;
        uint amountETH = 1 ether;
        
        vm.deal(address(this), amountETH);
        (,,uint liquidity) = router.addLiquidityETH{value: amountETH}(
            address(tokenA),
            amountTokenDesired,
            0,
            0,
            address(this),
            DEADLINE
        );

        // Now remove liquidity ETH
        address pair = factory.getPair(address(tokenA), address(weth));
        UniswapV2PairMock(pair).get_permit(address(this), address(router), liquidity, DEADLINE, 0, bytes32(0), bytes32(0));
        
        (uint amountToken, uint amountETHOut) = router.removeLiquidityETH(
            address(tokenA),
            liquidity,
            0,
            0,
            address(this),
            DEADLINE
        );

        assertGt(amountToken, 0, "No token returned");
        assertGt(amountETHOut, 0, "No ETH returned");
    }

    function testRemoveLiquidityWithPermit() public {
        // First add liquidity
        uint amountADesired = 100 ether;
        uint amountBDesired = 200 ether;
        
        (,,uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountADesired,
            amountBDesired,
            0,
            0,
            address(this),
            DEADLINE
        );

        // Remove liquidity with permit
        (uint amountA, uint amountB) = router.removeLiquidityWithPermit(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            address(this),
            DEADLINE,
            true, // approveMax
            0, // v
            bytes32(0), // r
            bytes32(0) // s
        );

        assertGt(amountA, 0, "No token A returned");
        assertGt(amountB, 0, "No token B returned");
    }

    function testRemoveLiquidityETHWithPermit() public {
        // First add liquidity ETH
        uint amountTokenDesired = 100 ether;
        uint amountETH = 1 ether;
        
        vm.deal(address(this), amountETH);
        (,,uint liquidity) = router.addLiquidityETH{value: amountETH}(
            address(tokenA),
            amountTokenDesired,
            0,
            0,
            address(this),
            DEADLINE
        );

        // Remove liquidity ETH with permit
        (uint amountToken, uint amountETHOut) = router.removeLiquidityETHWithPermit(
            address(tokenA),
            liquidity,
            0,
            0,
            address(this),
            DEADLINE,
            true, // approveMax
            0, // v
            bytes32(0), // r
            bytes32(0) // s
        );

        assertGt(amountToken, 0, "No token returned");
        assertGt(amountETHOut, 0, "No ETH returned");
    }
}
