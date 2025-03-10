// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import "forge-std/Test.sol";
// import "../../src/core/UniswapV2Factory.sol";
// import "../../src/core/UniswapV2Pair.sol";
// import "../mocks/ERC20Mock.sol";

// contract UniswapV2FactoryTest is Test {
//     UniswapV2Factory factory;
//     ERC20Mock tokenA;
//     ERC20Mock tokenB;
//     ERC20Mock tokenC;
//     address owner = address(1);
//     address feeTo = address(2);
    
//     function setUp() public {
//         // Deploy factory with owner
//         factory = new UniswapV2Factory(owner);
        
//         // Deploy test tokens
//         tokenA = new ERC20Mock("Token A", "TKNA");
//         tokenB = new ERC20Mock("Token B", "TKNB");
//         tokenC = new ERC20Mock("Token C", "TKNC");
//     }
    
//     function testInitialState() public {
//         assertEq(factory.owner(), owner);
//         assertEq(factory.feeTo(), address(0));
//         assertEq(factory.allPairsLength(), 0);
//     }
    
//     function testCreatePair() public {
//         address expectedPair = factory.createPair(address(tokenA), address(tokenB));
        
//         // Verify pair was created
//         assertEq(factory.allPairsLength(), 1);
//         assertEq(factory.allPairs(0), expectedPair);
//         assertEq(factory.getPair(address(tokenA), address(tokenB)), expectedPair);
//         assertEq(factory.getPair(address(tokenB), address(tokenA)), expectedPair);
        
//         // Verify pair state
//         UniswapV2Pair pair = UniswapV2Pair(expectedPair);
//         assertEq(pair.factory(), address(factory));
//         assertEq(pair.token0(), address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB));
//         assertEq(pair.token1(), address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA));
//     }
    
//     function testCreatePairReversed() public {
//         address expectedPair = factory.createPair(address(tokenB), address(tokenA));
        
//         // Verify pair can be retrieved regardless of token order
//         assertEq(factory.getPair(address(tokenA), address(tokenB)), expectedPair);
//         assertEq(factory.getPair(address(tokenB), address(tokenA)), expectedPair);
//     }
    
//     function testCannotCreatePairWithSameTokens() public {
//         vm.expectRevert(bytes("UniswapV2: IDENTICAL_ADDRESSES"));
//         factory.createPair(address(tokenA), address(tokenA));
//     }
    
//     function testCannotCreatePairWithZeroAddress() public {
//         vm.expectRevert(bytes("UniswapV2: ZERO_ADDRESS"));
//         factory.createPair(address(tokenA), address(0));
        
//         vm.expectRevert(bytes("UniswapV2: ZERO_ADDRESS"));
//         factory.createPair(address(0), address(tokenA));
//     }
    
//     function testCannotCreateExistingPair() public {
//         factory.createPair(address(tokenA), address(tokenB));
        
//         vm.expectRevert(bytes("UniswapV2: PAIR_EXISTS"));
//         factory.createPair(address(tokenA), address(tokenB));
        
//         vm.expectRevert(bytes("UniswapV2: PAIR_EXISTS"));
//         factory.createPair(address(tokenB), address(tokenA));
//     }
    
//     function testMultiplePairs() public {
//         address pair1 = factory.createPair(address(tokenA), address(tokenB));
//         address pair2 = factory.createPair(address(tokenA), address(tokenC));
//         address pair3 = factory.createPair(address(tokenB), address(tokenC));
        
//         assertEq(factory.allPairsLength(), 3);
//         assertEq(factory.allPairs(0), pair1);
//         assertEq(factory.allPairs(1), pair2);
//         assertEq(factory.allPairs(2), pair3);
//     }
    
//     function testSetFeeTo() public {
//         // Only owner can set feeTo
//         vm.prank(owner);
//         factory.setFeeTo(feeTo);
        
//         assertEq(factory.feeTo(), feeTo);
//     }
    
//     function testCannotSetFeeToUnlessOwner() public {
//         vm.prank(address(3)); // Not the owner
//         vm.expectRevert(bytes("UniswapV2: FORBIDDEN"));
//         factory.setFeeTo(feeTo);
//     }
    
//     function testSetOwner() public {
//         address newOwner = address(3);
        
//         vm.prank(owner);
//         factory.setOwner(newOwner);
        
//         assertEq(factory.owner(), newOwner);
//     }
    
//     function testCannotSetOwnerUnlessOwner() public {
//         address newOwner = address(3);
        
//         vm.prank(address(4)); // Not the owner
//         vm.expectRevert(bytes("UniswapV2: FORBIDDEN"));
//         factory.setOwner(newOwner);
//     }
// }