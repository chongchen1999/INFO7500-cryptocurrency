// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.28;

// import "forge-std/Test.sol";
// import "src/periphery/UniswapV2Router02.sol";
// import "src/test/mocks/MockWETH.sol";
// import "src/test/mocks/MockFactory.sol";
// import "src/test/mocks/MockERC20.sol";
// import "src/test/mocks/MockPair.sol";
// import "src/libraries/UniswapV2Library.sol";

// contract UniswapV2Router02AmountsTest is Test {
//     UniswapV2Router02 public router;
//     MockWETH public weth;
//     MockFactory public factory;
//     MockERC20 public tokenA;
//     MockERC20 public tokenB;
//     MockERC20 public tokenC;
//     MockPair public pairAB;
//     MockPair public pairBC;

//     // Constants for testing
//     uint constant INITIAL_RESERVE_A = 1000000e18;
//     uint constant INITIAL_RESERVE_B = 2000000e18;
//     uint constant INITIAL_RESERVE_C = 3000000e18;
//     uint constant TEST_AMOUNT = 1000e18;

//     function setUp() public {
//         weth = new MockWETH();
//         factory = new MockFactory();
//         router = new UniswapV2Router02(address(factory), address(weth));
        
//         // Setup mock tokens with 18 decimals
//         tokenA = new MockERC20("Token A", "TKNA", 18);
//         tokenB = new MockERC20("Token B", "TKNB", 18);
//         tokenC = new MockERC20("Token C", "TKNC", 18);

//         // Calculate pair addresses the same way UniswapV2Library does
//         address pairABAddress = calculatePairAddress(address(tokenA), address(tokenB));
//         address pairBCAddress = calculatePairAddress(address(tokenB), address(tokenC));

//         console.log("Expected PairAB address:", pairABAddress);
//         console.log("Expected PairBC address:", pairBCAddress);

//         // Deploy pairs at the calculated addresses
//         vm.etch(pairABAddress, address(new MockPair()).code);
//         vm.etch(pairBCAddress, address(new MockPair()).code);

//         // Now we can interact with the pairs at those addresses
//         pairAB = MockPair(pairABAddress);
//         pairBC = MockPair(pairBCAddress);

//         // Set up pairs with tokens in sorted order
//         (address token0AB, address token1AB) = address(tokenA) < address(tokenB) 
//             ? (address(tokenA), address(tokenB)) 
//             : (address(tokenB), address(tokenA));
        
//         (address token0BC, address token1BC) = address(tokenB) < address(tokenC) 
//             ? (address(tokenB), address(tokenC)) 
//             : (address(tokenC), address(tokenB));

//         // Set tokens and reserves
//         pairAB.setTokens(token0AB, token1AB);
//         pairBC.setTokens(token0BC, token1BC);

//         if (address(tokenA) < address(tokenB)) {
//             pairAB.setReserves(uint112(INITIAL_RESERVE_A), uint112(INITIAL_RESERVE_B));
//         } else {
//             pairAB.setReserves(uint112(INITIAL_RESERVE_B), uint112(INITIAL_RESERVE_A));
//         }

//         if (address(tokenB) < address(tokenC)) {
//             pairBC.setReserves(uint112(INITIAL_RESERVE_B), uint112(INITIAL_RESERVE_C));
//         } else {
//             pairBC.setReserves(uint112(INITIAL_RESERVE_C), uint112(INITIAL_RESERVE_B));
//         }

//         // Set up factory to return these pairs
//         factory.setPair(address(tokenA), address(tokenB), pairABAddress);
//         factory.setPair(address(tokenB), address(tokenC), pairBCAddress);

//         // Verify setup
//         address factoryPairAB = factory.getPair(address(tokenA), address(tokenB));
//         address factoryPairBC = factory.getPair(address(tokenB), address(tokenC));
//         require(factoryPairAB == pairABAddress, "PairAB address mismatch");
//         require(factoryPairBC == pairBCAddress, "PairBC address mismatch");

//         (uint112 reserve0, uint112 reserve1,) = pairAB.getReserves();
//         require(reserve0 > 0 && reserve1 > 0, "PairAB reserves not set");
//         (reserve0, reserve1,) = pairBC.getReserves();
//         require(reserve0 > 0 && reserve1 > 0, "PairBC reserves not set");
//     }

//     // Helper function to calculate pair address the same way UniswapV2Library does
//     function calculatePairAddress(address tokenA, address tokenB) public view returns (address) {
//         (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
//         bytes32 salt = keccak256(abi.encodePacked(token0, token1));
//         bytes32 hash = keccak256(
//             abi.encodePacked(
//                 bytes1(0xff),
//                 address(factory),
//                 salt,
//                 keccak256(type(MockPair).creationCode)
//             )
//         );
//         return address(uint160(uint256(hash)));
//     }

//     function testGetAmountsOut() public {
//         console.log("TokenA address:", address(tokenA));
//         console.log("TokenB address:", address(tokenB));
//         console.log("TokenC address:", address(tokenC));
//         console.log("PairAB address:", address(pairAB));
//         console.log("PairBC address:", address(pairBC));

//         address[] memory path = new address[](3);
//         path[0] = address(tokenA);
//         path[1] = address(tokenB);
//         path[2] = address(tokenC);
        
//         uint amountIn = TEST_AMOUNT;

//         // Log pair addresses from factory
//         console.log("Factory PairAB:", factory.getPair(address(tokenA), address(tokenB)));
//         console.log("Factory PairBC:", factory.getPair(address(tokenB), address(tokenC)));

//         // Log reserves before test
//         (uint112 reserve0, uint112 reserve1,) = pairAB.getReserves();
//         console.log("PairAB reserves:", uint256(reserve0), uint256(reserve1));
//         (reserve0, reserve1,) = pairBC.getReserves();
//         console.log("PairBC reserves:", uint256(reserve0), uint256(reserve1));
        
//         // Test getAmountsOut with valid path
//         uint[] memory amounts = router.getAmountsOut(amountIn, path);
//         assertEq(amounts.length, 3, "Should return amounts for all path steps");
//         assertEq(amounts[0], amountIn, "First amount should be input amount");
//         assertTrue(amounts[1] > 0, "Intermediate amount should be greater than 0");
//         assertTrue(amounts[2] > 0, "Final amount should be greater than 0");
        
//         console.log("Amount In:", amounts[0]);
//         console.log("Intermediate Amount:", amounts[1]);
//         console.log("Final Amount:", amounts[2]);
//     }

//     function testGetAmountsIn() public {
//         console.log("TokenA address:", address(tokenA));
//         console.log("TokenB address:", address(tokenB));
//         console.log("TokenC address:", address(tokenC));
//         console.log("PairAB address:", address(pairAB));
//         console.log("PairBC address:", address(pairBC));

//         address[] memory path = new address[](3);
//         path[0] = address(tokenA);
//         path[1] = address(tokenB);
//         path[2] = address(tokenC);
        
//         uint amountOut = TEST_AMOUNT;

//         // Log pair addresses from factory
//         console.log("Factory PairAB:", factory.getPair(address(tokenA), address(tokenB)));
//         console.log("Factory PairBC:", factory.getPair(address(tokenB), address(tokenC)));

//         // Log reserves before test
//         (uint112 reserve0, uint112 reserve1,) = pairAB.getReserves();
//         console.log("PairAB reserves:", uint256(reserve0), uint256(reserve1));
//         (reserve0, reserve1,) = pairBC.getReserves();
//         console.log("PairBC reserves:", uint256(reserve0), uint256(reserve1));
        
//         // Test getAmountsIn with valid path
//         uint[] memory amounts = router.getAmountsIn(amountOut, path);
//         assertEq(amounts.length, 3, "Should return amounts for all path steps");
//         assertTrue(amounts[0] > 0, "Initial amount should be greater than 0");
//         assertTrue(amounts[1] > 0, "Intermediate amount should be greater than 0");
//         assertEq(amounts[2], amountOut, "Final amount should be output amount");
        
//         console.log("Initial Amount:", amounts[0]);
//         console.log("Intermediate Amount:", amounts[1]);
//         console.log("Final Amount:", amounts[2]);
//     }
// }