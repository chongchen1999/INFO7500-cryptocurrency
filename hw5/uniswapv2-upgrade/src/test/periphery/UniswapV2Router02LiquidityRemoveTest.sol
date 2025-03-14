// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "src/periphery/UniswapV2Router02.sol";
import "src/core/interfaces/IUniswapV2Factory.sol";
import "src/core/interfaces/IUniswapV2Pair.sol";
import "src/test/mocks/MockFeeOnTransferToken.sol";
import "src/periphery/interfaces/IWETH.sol";

contract UniswapV2Router02RemoveLiquidityTest is Test {
    UniswapV2Router02 public router;
    IUniswapV2Factory public factory;
    IWETH public weth;
    MockFeeOnTransferToken public feeToken;
    
    address public constant FACTORY_ADDRESS = address(0x1000);
    address public constant WETH_ADDRESS = address(0x2000);
    address public constant USER = address(0x3000);
    uint256 public constant INITIAL_LIQUIDITY = 1000 ether;
    uint256 public constant INITIAL_ETH = 100 ether;
    
    function setUp() public {
        // Deploy mock contracts
        factory = IUniswapV2Factory(FACTORY_ADDRESS);
        weth = IWETH(WETH_ADDRESS);
        feeToken = new MockFeeOnTransferToken(INITIAL_LIQUIDITY * 2);
        
        // Deploy router
        router = new UniswapV2Router02(FACTORY_ADDRESS, WETH_ADDRESS);
        
        // Setup initial balances and approvals
        vm.deal(USER, INITIAL_ETH);
        feeToken.transfer(USER, INITIAL_LIQUIDITY);
        
        vm.startPrank(USER);
        feeToken.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }
    
    // function testRemoveLiquidityETHSupportingFeeOnTransferTokens() public {
    //     uint256 tokenAmount = 10 ether;
    //     uint256 ethAmount = 1 ether;
    //     uint256 liquidity = 5 ether;
    //     address pair = address(0x4000);
        
    //     // Mock the pair address
    //     vm.mockCall(
    //         FACTORY_ADDRESS,
    //         abi.encodeWithSelector(IUniswapV2Factory.getPair.selector, address(feeToken), WETH_ADDRESS),
    //         abi.encode(pair)
    //     );
        
    //     // Mock pair transferFrom
    //     vm.mockCall(
    //         pair,
    //         abi.encodeWithSelector(IUniswapV2Pair.get_transferFrom.selector, USER, pair, liquidity),
    //         abi.encode(true)
    //     );
        
    //     // Mock pair burn
    //     vm.mockCall(
    //         pair,
    //         abi.encodeWithSelector(IUniswapV2Pair.burn.selector, router),
    //         abi.encode(tokenAmount, ethAmount)
    //     );
        
    //     // Mock WETH withdrawal
    //     vm.mockCall(
    //         WETH_ADDRESS,
    //         abi.encodeWithSelector(IWETH.withdraw.selector, ethAmount),
    //         abi.encode()
    //     );
        
    //     // Mock token balance check and transfer
    //     vm.mockCall(
    //         address(feeToken),
    //         abi.encodeWithSelector(IERC20.balanceOf.selector, address(router)),
    //         abi.encode(tokenAmount)
    //     );
        
    //     vm.mockCall(
    //         address(feeToken),
    //         abi.encodeWithSelector(IERC20.transfer.selector, USER, tokenAmount),
    //         abi.encode(true)
    //     );
        
    //     // Mock ETH transfer (using deal to simulate)
    //     vm.deal(address(router), ethAmount);
        
    //     vm.startPrank(USER);
        
    //     uint256 deadline = block.timestamp + 1 days;
    //     uint256 amountETH = router.removeLiquidityETHSupportingFeeOnTransferTokens(
    //         address(feeToken),
    //         liquidity,
    //         1 ether, // minTokenAmount
    //         0.1 ether, // minETHAmount
    //         USER,
    //         deadline
    //     );
        
    //     assertEq(amountETH, ethAmount, "Incorrect ETH amount returned");
        
    //     vm.stopPrank();
    // }
    
    // function testRemoveLiquidityETHWithPermitSupportingFeeOnTransferTokens() public {
    //     uint256 tokenAmount = 10 ether;
    //     uint256 ethAmount = 1 ether;
    //     uint256 liquidity = 5 ether;
    //     address pair = address(0x4000);
    //     uint256 deadline = block.timestamp + 1 days;
    //     bool approveMax = true;
    //     uint8 v = 27;
    //     bytes32 r = bytes32(uint256(1));
    //     bytes32 s = bytes32(uint256(2));
        
    //     // Mock the pair address
    //     vm.mockCall(
    //         FACTORY_ADDRESS,
    //         abi.encodeWithSelector(IUniswapV2Factory.getPair.selector, address(feeToken), WETH_ADDRESS),
    //         abi.encode(pair)
    //     );
        
    //     // Mock permit
    //     uint256 value = approveMax ? type(uint256).max : liquidity;
    //     vm.mockCall(
    //         pair,
    //         abi.encodeWithSelector(IUniswapV2Pair.get_permit.selector, USER, address(router), value, deadline, v, r, s),
    //         abi.encode()
    //     );
        
    //     // Mock pair transferFrom
    //     vm.mockCall(
    //         pair,
    //         abi.encodeWithSelector(IUniswapV2Pair.get_transferFrom.selector, USER, pair, liquidity),
    //         abi.encode(true)
    //     );
        
    //     // Mock pair burn
    //     vm.mockCall(
    //         pair,
    //         abi.encodeWithSelector(IUniswapV2Pair.burn.selector, router),
    //         abi.encode(tokenAmount, ethAmount)
    //     );
        
    //     // Mock WETH withdrawal
    //     vm.mockCall(
    //         WETH_ADDRESS,
    //         abi.encodeWithSelector(IWETH.withdraw.selector, ethAmount),
    //         abi.encode()
    //     );
        
    //     // Mock token balance check and transfer
    //     vm.mockCall(
    //         address(feeToken),
    //         abi.encodeWithSelector(IERC20.balanceOf.selector, address(router)),
    //         abi.encode(tokenAmount)
    //     );
        
    //     vm.mockCall(
    //         address(feeToken),
    //         abi.encodeWithSelector(IERC20.transfer.selector, USER, tokenAmount),
    //         abi.encode(true)
    //     );
        
    //     // Mock ETH transfer (using deal to simulate)
    //     vm.deal(address(router), ethAmount);
        
    //     vm.startPrank(USER);
        
    //     uint256 amountETH = router.removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
    //         address(feeToken),
    //         liquidity,
    //         1 ether, // minTokenAmount
    //         0.1 ether, // minETHAmount
    //         USER,
    //         deadline,
    //         approveMax,
    //         v,
    //         r,
    //         s
    //     );
        
    //     assertEq(amountETH, ethAmount, "Incorrect ETH amount returned");
        
    //     vm.stopPrank();
    // }
    
    function testRemoveLiquidityETHSupportingFeeOnTransferTokens_PairNotFound() public {
        // Mock the pair address as zero address
        vm.mockCall(
            FACTORY_ADDRESS,
            abi.encodeWithSelector(IUniswapV2Factory.getPair.selector, address(feeToken), WETH_ADDRESS),
            abi.encode(address(0))
        );
        
        vm.startPrank(USER);
        
        vm.expectRevert("UniswapV2Router: PAIR_NOT_FOUND");
        router.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(feeToken),
            1 ether,
            0,
            0,
            USER,
            block.timestamp + 1 days
        );
        
        vm.stopPrank();
    }
    
    // function testRemoveLiquidityETHSupportingFeeOnTransferTokens_ExpiredDeadline() public {
    //     vm.startPrank(USER);
        
    //     vm.expectRevert("UniswapV2Router: EXPIRED");
    //     router.removeLiquidityETHSupportingFeeOnTransferTokens(
    //         address(feeToken),
    //         1 ether,
    //         0,
    //         0,
    //         USER,
    //         block.timestamp - 1 // Expired deadline
    //     );
        
    //     vm.stopPrank();
    // }
}