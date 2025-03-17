// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "src/tests/UniswapV2Router02/UniswapV2Router02.t.base.sol";
import "src/interfaces/IUniswapV2Pair.sol";
import "src/interfaces/IUniswapV2ERC20.sol";

contract TestUniswapV2RouterRemoveLiquidity is UniswapV2RouterTestBase {
    // Use a fixed private key for consistent testing
    uint256 constant PRIVATE_KEY = 0xBEEF;

    function setUp() public override {
        super.setUp();
        // Update user to be derived from our private key
        user = vm.addr(PRIVATE_KEY);
        
        // Reset user's tokens and ETH
        vm.deal(user, 100 ether);
        tokenA.mint(user, 1_000_000 ether);
        tokenB.mint(user, 1_000_000 ether);
        feeToken.mint(user, 1_000_000 ether);
    }

    function testRemoveLiquidity() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        // Add initial liquidity
        (, , uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            1000 ether,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );

        // Get pair address and approve router
        address pair = factory.getPair(address(tokenA), address(tokenB));
        IUniswapV2ERC20(pair).approve(address(router), liquidity);

        (uint amountA, uint amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );

        assertGe(amountA, 900 ether, "amountA not enough");
        assertGe(amountB, 900 ether, "amountB not enough");

        vm.stopPrank();
    }

    function testRemoveLiquidityETH() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);

        // Add initial TokenA/ETH liquidity
        (, , uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            1000 ether,
            900 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );

        // Get pair address and approve router
        address pair = factory.getPair(address(tokenA), address(weth));
        IUniswapV2ERC20(pair).approve(address(router), liquidity);

        (uint amountToken, uint amountETH) = router.removeLiquidityETH(
            address(tokenA),
            liquidity,
            900 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );

        assertGe(amountToken, 900 ether, "amountToken not enough");
        assertGe(amountETH, 9 ether, "amountETH not enough");

        vm.stopPrank();
    }

    function testRemoveLiquidityWithPermit() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        // Add initial liquidity
        (, , uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            1000 ether,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );
        vm.stopPrank();

        // Get pair address and deadline
        address pair = factory.getPair(address(tokenA), address(tokenB));
        uint256 deadline = block.timestamp + 1000;

        // Generate permit signature
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IUniswapV2Pair(pair).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(router),
                        liquidity,
                        IUniswapV2Pair(pair).nonces(user),
                        deadline
                    )
                )
            )
        );

        (v, r, s) = vm.sign(PRIVATE_KEY, permitHash);

        vm.startPrank(user);
        (uint amountA, uint amountB) = router.removeLiquidityWithPermit(
            address(tokenA),
            address(tokenB),
            liquidity,
            900 ether,
            900 ether,
            user,
            deadline,
            false, // not approveMax
            v, r, s
        );

        assertGe(amountA, 900 ether, "amountA not enough");
        assertGe(amountB, 900 ether, "amountB not enough");
        vm.stopPrank();
    }

    function testRemoveLiquidityETHWithPermit() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);

        // Add initial liquidity
        (, , uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            1000 ether,
            900 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );
        vm.stopPrank();

        // Get pair address and deadline
        address pair = factory.getPair(address(tokenA), address(weth));
        uint256 deadline = block.timestamp + 1000;

        // Generate permit signature
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IUniswapV2Pair(pair).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(router),
                        liquidity,
                        IUniswapV2Pair(pair).nonces(user),
                        deadline
                    )
                )
            )
        );

        (v, r, s) = vm.sign(PRIVATE_KEY, permitHash);

        vm.startPrank(user);
        (uint amountToken, uint amountETH) = router.removeLiquidityETHWithPermit(
            address(tokenA),
            liquidity,
            900 ether,
            9 ether,
            user,
            deadline,
            false, // not approveMax
            v, r, s
        );

        assertGe(amountToken, 900 ether, "amountToken not enough");
        assertGe(amountETH, 9 ether, "amountETH not enough");
        vm.stopPrank();
    }

    function testRemoveLiquidityETHWithPermitSupportingFeeOnTransferTokens() public {
        vm.startPrank(user);
        feeToken.approve(address(router), type(uint).max);

        // Add initial liquidity
        (, , uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(feeToken),
            1000 ether,
            900 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );
        vm.stopPrank();

        // Get pair address and deadline
        address pair = factory.getPair(address(feeToken), address(weth));
        uint256 deadline = block.timestamp + 1000;

        // Generate permit signature
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IUniswapV2Pair(pair).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(router),
                        liquidity,
                        IUniswapV2Pair(pair).nonces(user),
                        deadline
                    )
                )
            )
        );

        (v, r, s) = vm.sign(PRIVATE_KEY, permitHash);

        uint256 initialETHBalance = user.balance;
        uint256 initialTokenBalance = feeToken.balanceOf(user);

        vm.startPrank(user);
        uint amountETH = router.removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
            address(feeToken),
            liquidity,
            0, // amountTokenMin
            9 ether, // amountETHMin
            user,
            deadline,
            false, // not approveMax
            v, r, s
        );

        assertGt(amountETH, 9 ether, "amountETH not enough");
        assertGt(feeToken.balanceOf(user), initialTokenBalance, "Should receive fee tokens");
        assertEq(user.balance, initialETHBalance + amountETH, "Should receive correct ETH amount");
        vm.stopPrank();
    }

    function testRemoveLiquidityETHSupportingFeeOnTransferTokens() public {
        vm.startPrank(user);
        feeToken.approve(address(router), type(uint).max);

        // Add initial liquidity with ETH and fee token
        (, , uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(feeToken),
            1000 ether,
            900 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );

        // Get pair address and approve router
        address pair = factory.getPair(address(feeToken), address(weth));
        IUniswapV2ERC20(pair).approve(address(router), liquidity);

        // Record initial balances
        uint256 initialETHBalance = user.balance;
        uint256 initialTokenBalance = feeToken.balanceOf(user);

        // Remove liquidity
        uint amountETH = router.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(feeToken),
            liquidity,
            0, // amountTokenMin (set to 0 since fee will reduce actual received amount)
            9 ether, // amountETHMin
            user,
            block.timestamp + 1000
        );

        // Verify outputs
        assertGt(amountETH, 9 ether, "amountETH not enough");
        assertGt(feeToken.balanceOf(user), initialTokenBalance, "Should receive fee tokens");
        assertEq(user.balance, initialETHBalance + amountETH, "Should receive correct ETH amount");

        vm.stopPrank();
    }
}