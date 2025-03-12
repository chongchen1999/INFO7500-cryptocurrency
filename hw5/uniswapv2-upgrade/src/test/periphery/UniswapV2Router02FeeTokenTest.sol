// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "lib/forge-std/src/Test.sol";
import "src/periphery/UniswapV2Router02.sol";
import "src/test/mocks/UniswapV2FactoryMock.sol";
import "src/test/mocks/UniswapV2WETH9Mock.sol";
import "src/test/mocks/UniswapV2ERC20Mock.sol";
import "src/test/mocks/UniswapV2PairMock.sol";

contract UniswapV2Router02FeeTokenTest is Test {
    UniswapV2Router02 public router;
    UniswapV2FactoryMock public factory;
    UniswapV2WETH9Mock public weth;
    UniswapV2ERC20Mock public feeToken;
    uint constant INITIAL_AMOUNT = 1000 ether;
    uint constant DEADLINE = block.timestamp + 1;

    function setUp() public {
        // Deploy contracts
        factory = new UniswapV2FactoryMock();
        weth = new UniswapV2WETH9Mock();
        feeToken = new UniswapV2ERC20Mock();
        router = new UniswapV2Router02(address(factory), address(weth));

        // Mint initial tokens
        feeToken.mint(address(this), INITIAL_AMOUNT);
        
        // Approve router
        feeToken.approve(address(router), type(uint256).max);

        // Create pair and add initial liquidity
        _createPairWithLiquidity(address(feeToken), address(weth), 100 ether, 1 ether);
    }

    function _createPairWithLiquidity(address token0, address token1, uint amount0, uint amount1) internal {
        address pair = factory.createPair(token0, token1);
        UniswapV2PairMock(pair).setReserves(uint112(amount0), uint112(amount1));
    }

    function testRemoveLiquidityETHSupportingFeeOnTransferTokens() public {
        // First add liquidity ETH
        uint amountTokenDesired = 100 ether;
        uint amountETH = 1 ether;
        
        vm.deal(address(this), amountETH);
        (,,uint liquidity) = router.addLiquidityETH{value: amountETH}(
            address(feeToken),
            amountTokenDesired,
            0,
            0,
            address(this),
            DEADLINE
        );

        // Remove liquidity with fee-on-transfer support
        uint amountETHOut = router.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(feeToken),
            liquidity,
            0,
            0,
            address(this),
            DEADLINE
        );

        assertGt(amountETHOut, 0, "No ETH returned");
    }

    function testRemoveLiquidityETHWithPermitSupportingFeeOnTransferTokens() public {
        // First add liquidity ETH
        uint amountTokenDesired = 100 ether;
        uint amountETH = 1 ether;
        
        vm.deal(address(this), amountETH);
        (,,uint liquidity) = router.addLiquidityETH{value: amountETH}(
            address(feeToken),
            amountTokenDesired,
            0,
            0,
            address(this),
            DEADLINE
        );

        // Remove liquidity with permit and fee-on-transfer support
        uint amountETHOut = router.removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
            address(feeToken),
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

        assertGt(amountETHOut, 0, "No ETH returned");
    }

    function testSwapExactTokensForTokensSupportingFeeOnTransferTokens() public {
        address[] memory path = new address[](2);
        path[0] = address(feeToken);
        path[1] = address(weth);

        uint amountIn = 1 ether;
        uint balanceBefore = weth.balanceOf(address(this));

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            0, // amountOutMin
            path,
            address(this),
            DEADLINE
        );

        assertGt(weth.balanceOf(address(this)) - balanceBefore, 0, "No tokens received");
    }

    function testSwapExactETHForTokensSupportingFeeOnTransferTokens() public {
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(feeToken);

        uint amountIn = 1 ether;
        vm.deal(address(this), amountIn);
        uint balanceBefore = feeToken.balanceOf(address(this));

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountIn}(
            0, // amountOutMin
            path,
            address(this),
            DEADLINE
        );

        assertGt(feeToken.balanceOf(address(this)) - balanceBefore, 0, "No tokens received");
    }

    function testSwapExactTokensForETHSupportingFeeOnTransferTokens() public {
        address[] memory path = new address[](2);
        path[0] = address(feeToken);
        path[1] = address(weth);

        uint amountIn = 1 ether;
        uint balanceBefore = address(this).balance;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn,
            0, // amountOutMin
            path,
            address(this),
            DEADLINE
        );

        assertGt(address(this).balance - balanceBefore, 0, "No ETH received");
    }

    receive() external payable {}
}