// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./UniswapV2Router02.t.base.sol";


// Fee token implementation
contract MockERC20WithFee is MockERC20 {
    constructor(string memory name_, string memory symbol_) 
        MockERC20(name_, symbol_) {}

    function transfer(address to, uint256 amount) external virtual override returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        // Apply a 1% fee
        uint256 fee = amount / 100;
        uint256 netAmount = amount - fee;
        
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += netAmount;
        totalSupply -= fee; // burn the fee
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external virtual override returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        // Apply a 1% fee
        uint256 fee = amount / 100;
        uint256 netAmount = amount - fee;
        
        balanceOf[from] -= amount;
        balanceOf[to] += netAmount;
        allowance[from][msg.sender] -= amount;
        totalSupply -= fee; // burn the fee
        return true;
    }
}

contract TestUniswapV2RouterSwapEdgeCases is UniswapV2RouterTestBase {
    MockERC20 public tokenC;
    MockERC20WithFee public tokenD;

    function setUp() public override {
        super.setUp();
        
        // Deploy additional test tokens
        tokenC = new MockERC20("Token C", "TC");
        tokenD = new MockERC20WithFee("Token D", "TD");
        
        // Mint tokens to user
        tokenC.mint(user, 10000 ether);
        tokenD.mint(user, 10000 ether);
    }

    function testMultiHopSwapWithMissingPair() public {
        vm.startPrank(user);
        
        // Only create A-B pair, but not B-C pair
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);
        tokenC.approve(address(router), type(uint).max);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            1000 ether,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );

        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        // Should revert because B-C pair doesn't exist
        vm.expectRevert("UniswapV2Library: PAIR_DOES_NOT_EXIST");
        router.swapExactTokensForTokens(
            100 ether,
            1,
            path,
            user,
            block.timestamp + 1000
        );

        vm.stopPrank();
    }

    function testMultiHopSwapWithFeeTokens() public {
        vm.startPrank(user);
        
        // Setup all necessary pairs
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);
        tokenC.approve(address(router), type(uint).max);
        tokenD.approve(address(router), type(uint).max);

        // Add liquidity for A-B pair
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            1000 ether,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );

        // Add liquidity for B-C pair
        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            1000 ether,
            1000 ether,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );

        // Add liquidity for C-D pair
        router.addLiquidity(
            address(tokenC),
            address(tokenD),
            1000 ether,
            1000 ether,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );

        // Create path A -> B -> C -> D
        address[] memory path = new address[](4);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        path[3] = address(tokenD);

        uint balanceDBefore = tokenD.balanceOf(user);

        // This will test the intermediate routing with fee tokens
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100 ether,
            1,
            path,
            user,
            block.timestamp + 1000
        );

        uint balanceDAfter = tokenD.balanceOf(user);
        assertGt(balanceDAfter, balanceDBefore, "User D balance should increase");

        vm.stopPrank();
    }

    function testMultiHopSwapSuccess() public {
        vm.startPrank(user);
        
        // Setup all pairs
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);
        tokenC.approve(address(router), type(uint).max);

        // Add liquidity for A-B pair
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            1000 ether,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );

        // Add liquidity for B-C pair
        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            1000 ether,
            1000 ether,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );

        uint balanceCBefore = tokenC.balanceOf(user);

        // Create path A -> B -> C
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        // This should succeed and test the intermediate routing
        router.swapExactTokensForTokens(
            100 ether,
            1,
            path,
            user,
            block.timestamp + 1000
        );

        uint balanceCAfter = tokenC.balanceOf(user);
        assertGt(balanceCAfter, balanceCBefore, "User C balance should increase");

        vm.stopPrank();
    }

    function testMultiHopSwapWithInvalidIntermediatePair() public {
        vm.startPrank(user);
        
        // Setup only first and last pairs, missing middle pair
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);
        tokenC.approve(address(router), type(uint).max);
        tokenD.approve(address(router), type(uint).max);

        // Add liquidity for A-B pair
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            1000 ether,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );

        // Add liquidity for C-D pair
        router.addLiquidity(
            address(tokenC),
            address(tokenD),
            1000 ether,
            1000 ether,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );

        // Create path A -> B -> C -> D
        address[] memory path = new address[](4);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        path[3] = address(tokenD);

        // Should revert because B-C pair doesn't exist
        vm.expectRevert("UniswapV2Library: PAIR_DOES_NOT_EXIST");
        router.swapExactTokensForTokens(
            100 ether,
            1,
            path,
            user,
            block.timestamp + 1000
        );

        vm.stopPrank();
    }
}
