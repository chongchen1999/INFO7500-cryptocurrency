// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.28;

// import "lib/forge-std/src/Test.sol";
// import "src/periphery/UniswapV2Router02.sol";
// import "src/test/mocks/MockERC20.sol";
// import "src/test/mocks/MockWETH.sol";
// import "src/core/interfaces/IUniswapV2Factory.sol";
// import "src/core/interfaces/IUniswapV2Pair.sol";
// import "src/libraries/UniswapV2Library.sol";

// contract UniswapV2Router02SwapTest is Test {
//     UniswapV2Router02 public router;
//     MockERC20 public tokenA;
//     MockERC20 public tokenB;
//     MockERC20 public tokenC;
//     MockWETH public weth;
//     address public factory;
//     address public mockPair;

//     address public alice = makeAddr("alice");
//     uint256 constant INITIAL_AMOUNT = 1000000 ether;
//     uint256 constant SWAP_AMOUNT = 1000 ether;

//     bytes4 constant AMOUNTS_OUT_SELECTOR = bytes4(keccak256("getAmountsOut(address,uint256,address[])"));
//     bytes4 constant AMOUNTS_IN_SELECTOR = bytes4(keccak256("getAmountsIn(address,uint256,address[])"));

//     function setUp() public {
//         // Deploy mock tokens
//         tokenA = new MockERC20("Token A", "TKA", 18);
//         tokenB = new MockERC20("Token B", "TKB", 18);
//         tokenC = new MockERC20("Token C", "TKC", 18);
//         weth = new MockWETH();
        
//         // Setup factory and mock pair
//         factory = makeAddr("factory");
//         mockPair = makeAddr("pair");
        
//         // Deploy router
//         router = new UniswapV2Router02(factory, address(weth));

//         // Setup test account
//         vm.startPrank(alice);
//         tokenA.mint(alice, INITIAL_AMOUNT);
//         tokenB.mint(alice, INITIAL_AMOUNT);
//         tokenC.mint(alice, INITIAL_AMOUNT);
//         tokenA.approve(address(router), type(uint256).max);
//         tokenB.approve(address(router), type(uint256).max);
//         tokenC.approve(address(router), type(uint256).max);
//         vm.stopPrank();
//     }

//     function test_swapExactTokensForTokens() public {
//         vm.startPrank(alice);

//         address[] memory path = new address[](2);
//         path[0] = address(tokenA);
//         path[1] = address(tokenB);

//         uint[] memory amounts = new uint[](2);
//         amounts[0] = SWAP_AMOUNT;
//         amounts[1] = SWAP_AMOUNT * 98 / 100;

//         // Mock getPair
//         vm.mockCall(
//             factory,
//             abi.encodeWithSelector(IUniswapV2Factory.getPair.selector),
//             abi.encode(mockPair)
//         );

//         // Mock transferFrom
//         vm.mockCall(
//             address(tokenA),
//             abi.encodeWithSelector(IERC20.transferFrom.selector),
//             abi.encode(true)
//         );

//         // Mock getAmountsOut library call
//         bytes memory amountsOutData = abi.encode(amounts);
//         vm.mockCall(
//             address(UniswapV2Library),
//             abi.encodeWithSelector(AMOUNTS_OUT_SELECTOR, factory, SWAP_AMOUNT, path),
//             amountsOutData
//         );

//         // Mock swap
//         vm.mockCall(
//             mockPair,
//             abi.encodeWithSelector(IUniswapV2Pair.swap.selector),
//             abi.encode()
//         );

//         uint[] memory result = router.swapExactTokensForTokens(
//             SWAP_AMOUNT,
//             SWAP_AMOUNT * 97 / 100,
//             path,
//             alice,
//             block.timestamp + 15
//         );

//         assertEq(result[0], SWAP_AMOUNT);
//         assertEq(result[1], SWAP_AMOUNT * 98 / 100);

//         vm.stopPrank();
//     }

//     function test_swapTokensForExactTokens() public {
//         vm.startPrank(alice);

//         address[] memory path = new address[](2);
//         path[0] = address(tokenA);
//         path[1] = address(tokenB);

//         uint[] memory amounts = new uint[](2);
//         amounts[0] = SWAP_AMOUNT * 102 / 100;
//         amounts[1] = SWAP_AMOUNT;

//         // Mock getPair
//         vm.mockCall(
//             factory,
//             abi.encodeWithSelector(IUniswapV2Factory.getPair.selector),
//             abi.encode(mockPair)
//         );

//         // Mock transferFrom
//         vm.mockCall(
//             address(tokenA),
//             abi.encodeWithSelector(IERC20.transferFrom.selector),
//             abi.encode(true)
//         );

//         // Mock getAmountsIn library call
//         bytes memory amountsInData = abi.encode(amounts);
//         vm.mockCall(
//             address(UniswapV2Library),
//             abi.encodeWithSelector(AMOUNTS_IN_SELECTOR, factory, SWAP_AMOUNT, path),
//             amountsInData
//         );

//         // Mock swap
//         vm.mockCall(
//             mockPair,
//             abi.encodeWithSelector(IUniswapV2Pair.swap.selector),
//             abi.encode()
//         );

//         uint[] memory result = router.swapTokensForExactTokens(
//             SWAP_AMOUNT,
//             SWAP_AMOUNT * 103 / 100,
//             path,
//             alice,
//             block.timestamp + 15
//         );

//         assertEq(result[0], SWAP_AMOUNT * 102 / 100);
//         assertEq(result[1], SWAP_AMOUNT);

//         vm.stopPrank();
//     }

//     function test_RevertWhen_SwapExpired() public {
//         vm.startPrank(alice);
        
//         address[] memory path = new address[](2);
//         path[0] = address(tokenA);
//         path[1] = address(tokenB);
        
//         vm.expectRevert(bytes("UniswapV2Router: EXPIRED"));
//         router.swapExactTokensForTokens(
//             SWAP_AMOUNT,
//             0,
//             path,
//             alice,
//             block.timestamp - 1
//         );

//         vm.stopPrank();
//     }

//     function test_RevertWhen_InvalidPath() public {
//         vm.startPrank(alice);

//         address[] memory path = new address[](1);
//         path[0] = address(tokenA);

//         vm.expectRevert(bytes("UniswapV2Router: INVALID_PATH"));
//         router.swapExactTokensForTokens(
//             SWAP_AMOUNT,
//             0,
//             path,
//             alice,
//             block.timestamp + 15
//         );

//         vm.stopPrank();
//     }

//     function test_RevertWhen_InsufficientOutputAmount() public {
//         vm.startPrank(alice);

//         address[] memory path = new address[](2);
//         path[0] = address(tokenA);
//         path[1] = address(tokenB);

//         uint[] memory amounts = new uint[](2);
//         amounts[0] = SWAP_AMOUNT;
//         amounts[1] = SWAP_AMOUNT * 98 / 100;

//         // Mock getAmountsOut library call
//         bytes memory amountsOutData = abi.encode(amounts);
//         vm.mockCall(
//             address(UniswapV2Library),
//             abi.encodeWithSelector(AMOUNTS_OUT_SELECTOR, factory, SWAP_AMOUNT, path),
//             amountsOutData
//         );

//         vm.expectRevert(bytes("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"));
//         router.swapExactTokensForTokens(
//             SWAP_AMOUNT,
//             SWAP_AMOUNT * 99 / 100,
//             path,
//             alice,
//             block.timestamp + 15
//         );

//         vm.stopPrank();
//     }

//     function test_RevertWhen_ExcessiveInputAmount() public {
//         vm.startPrank(alice);

//         address[] memory path = new address[](2);
//         path[0] = address(tokenA);
//         path[1] = address(tokenB);

//         uint[] memory amounts = new uint[](2);
//         amounts[0] = SWAP_AMOUNT * 102 / 100;
//         amounts[1] = SWAP_AMOUNT;

//         // Mock getAmountsIn library call
//         bytes memory amountsInData = abi.encode(amounts);
//         vm.mockCall(
//             address(UniswapV2Library),
//             abi.encodeWithSelector(AMOUNTS_IN_SELECTOR, factory, SWAP_AMOUNT, path),
//             amountsInData
//         );

//         vm.expectRevert(bytes("UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"));
//         router.swapTokensForExactTokens(
//             SWAP_AMOUNT,
//             SWAP_AMOUNT * 101 / 100,
//             path,
//             alice,
//             block.timestamp + 15
//         );

//         vm.stopPrank();
//     }

//     function test_RevertWhen_PairNotFound() public {
//         vm.startPrank(alice);

//         address[] memory path = new address[](2);
//         path[0] = address(tokenA);
//         path[1] = address(tokenB);

//         uint[] memory amounts = new uint[](2);
//         amounts[0] = SWAP_AMOUNT;
//         amounts[1] = SWAP_AMOUNT * 98 / 100;

//         // Mock getAmountsOut library call
//         bytes memory amountsOutData = abi.encode(amounts);
//         vm.mockCall(
//             address(UniswapV2Library),
//             abi.encodeWithSelector(AMOUNTS_OUT_SELECTOR, factory, SWAP_AMOUNT, path),
//             amountsOutData
//         );

//         // Mock getPair to return zero address
//         vm.mockCall(
//             factory,
//             abi.encodeWithSelector(IUniswapV2Factory.getPair.selector),
//             abi.encode(address(0))
//         );

//         vm.expectRevert(bytes("UniswapV2Router: PAIR_NOT_FOUND"));
//         router.swapExactTokensForTokens(
//             SWAP_AMOUNT,
//             0,
//             path,
//             alice,
//             block.timestamp + 15
//         );

//         vm.stopPrank();
//     }
// }