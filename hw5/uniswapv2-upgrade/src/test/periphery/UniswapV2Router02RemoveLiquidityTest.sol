// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.28;

// import "./UniswapV2Router02BasicTest.sol";

// contract UniswapV2Router02RemoveLiquidityTest is UniswapV2Router02BasicTest {
//     IUniswapV2Pair public pair;
//     uint public liquidity;
    
//     function setUp() public override {
//         super.setUp();
        
//         // Create pair and add initial liquidity
//         pair = IUniswapV2Pair(factory.createPair(address(tokenA), address(tokenB)));
        
//         (, , liquidity) = router.addLiquidity(
//             address(tokenA),
//             address(tokenB),
//             100 ether,
//             100 ether,
//             0,
//             0,
//             owner,
//             block.timestamp + 1
//         );
        
//         // Approve router to spend LP tokens
//         pair.approve(address(router), type(uint256).max);
//     }
    
//     function testRemoveLiquidity() public {
//         uint amountAMin = 1 ether;
//         uint amountBMin = 1 ether;
        
//         // Remove all liquidity
//         (uint amountA, uint amountB) = router.removeLiquidity(
//             address(tokenA),
//             address(tokenB),
//             liquidity,
//             amountAMin,
//             amountBMin,
//             owner,
//             block.timestamp + 1
//         );
        
//         // Verify amounts received
//         assertGt(amountA, amountAMin, "Insufficient token A returned");
//         assertGt(amountB, amountBMin, "Insufficient token B returned");
        
//         // Verify reserves are now 0
//         (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
//         assertEq(uint(reserve0), 0, "Reserve0 not zero");
//         assertEq(uint(reserve1), 0, "Reserve1 not zero");
//     }
    
//     function testRemoveLiquidityETH() public {
//         // First add liquidity with ETH
//         (,, uint ethLiquidity) = router.addLiquidityETH{value: 1 ether}(
//             address(tokenA),
//             100 ether,
//             0,
//             0,
//             owner,
//             block.timestamp + 1
//         );
        
//         // Approve router for WETH pair
//         address wethPair = factory.getPair(address(tokenA), address(weth));
//         IUniswapV2Pair(wethPair).approve(address(router), type(uint256).max);
        
//         // Remove liquidity
//         (uint amountToken, uint amountETH) = router.removeLiquidityETH(
//             address(tokenA),
//             ethLiquidity,
//             0,
//             0,
//             owner,
//             block.timestamp + 1
//         );
        
//         // Verify amounts
//         assertGt(amountToken, 0, "No tokens returned");
//         assertGt(amountETH, 0, "No ETH returned");
//     }

//     function testRemoveLiquidityWithPermit() public {
//         uint deadline = block.timestamp + 1;
        
//         // Generate permit signature
//         bytes32 digest = keccak256(
//             abi.encodePacked(
//                 "\x19\x01",
//                 pair.DOMAIN_SEPARATOR(),
//                 keccak256(abi.encode(
//                     pair.PERMIT_TYPEHASH(),
//                     owner,
//                     address(router),
//                     liquidity,
//                     0, // nonce
//                     deadline
//                 ))
//             )
//         );
        
//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest); // Use private key 1 for signing
        
//         // Remove liquidity with permit
//         (uint amountA, uint amountB) = router.removeLiquidityWithPermit(
//             address(tokenA),
//             address(tokenB),
//             liquidity,
//             0,
//             0,
//             owner,
//             deadline,
//             true, // approveMax
//             v,
//             r,
//             s
//         );
        
//         assertGt(amountA, 0, "No token A returned");
//         assertGt(amountB, 0, "No token B returned");
//     }

//     function testRemoveLiquidityETHWithPermitSupportingFeeOnTransferTokens() public {
//         // Setup WETH pair with liquidity first
//         (,, uint ethLiquidity) = router.addLiquidityETH{value: 1 ether}(
//             address(tokenA),
//             100 ether,
//             0,
//             0,
//             owner,
//             block.timestamp + 1
//         );
        
//         address wethPair = factory.getPair(address(tokenA), address(weth));
//         uint deadline = block.timestamp + 1;
        
//         // Generate permit signature for WETH pair
//         bytes32 digest = keccak256(
//             abi.encodePacked(
//                 "\x19\x01",
//                 IUniswapV2Pair(wethPair).DOMAIN_SEPARATOR(),
//                 keccak256(abi.encode(
//                     IUniswapV2Pair(wethPair).PERMIT_TYPEHASH(),
//                     owner,
//                     address(router),
//                     ethLiquidity,
//                     0, // nonce
//                     deadline
//                 ))
//             )
//         );
        
//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        
//         uint amountETH = router.removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
//             address(tokenA),
//             ethLiquidity,
//             0,
//             0,
//             owner,
//             deadline,
//             true, // approveMax
//             v,
//             r,
//             s
//         );
        
//         assertGt(amountETH, 0, "No ETH returned");
//     }
// }
