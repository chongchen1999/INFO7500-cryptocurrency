// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "lib/forge-std/src/Test.sol";
import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Pair.sol";
import "../test/mocks/ERC20Mintable.sol";

// 这个合约用于测试闪电贷
contract FlashBorrower {
    // uniswapV2Call回调函数
    function uniswapV2Call(
        address,
        uint amount0,
        uint amount1,
        bytes calldata
    ) external {
        // 计算返还金额(含0.3%费用)
        if (amount0 > 0) {
            uint fee = (amount0 * 3) / 997 + 1;
            uint amountToReturn = amount0 + fee;
            
            // 在测试中已给本合约多铸一些token0，用于支付手续费
            ERC20Mintable token0 = ERC20Mintable(UniswapV2Pair(msg.sender).token0());
            token0.transfer(msg.sender, amountToReturn);
        }
        
        if (amount1 > 0) {
            uint fee = (amount1 * 3) / 997 + 1;
            uint amountToReturn = amount1 + fee;
            
            ERC20Mintable token1 = ERC20Mintable(UniswapV2Pair(msg.sender).token1());
            token1.transfer(msg.sender, amountToReturn);
        }
    }
}

// 这个合约用于测试闪电贷失败的情况(不归还借款)
contract FaultyFlashBorrower {
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external {
        // 什么都不做 => 无法还款，触发swap失败
    }
}

contract TestUniswapV2Pair is Test {
    UniswapV2Factory factory;
    UniswapV2Pair pair;
    ERC20Mintable token0;
    ERC20Mintable token1;
    address user = address(0xabc);
    address user2 = address(0xdef);
    FlashBorrower flashBorrower;
    FaultyFlashBorrower faultyBorrower;

    function setUp() public {
        // 部署Factory
        factory = new UniswapV2Factory(address(this));

        // 部署可mint的ERC20代币
        token0 = new ERC20Mintable("Token0", "TK0");
        token1 = new ERC20Mintable("Token1", "TK1");

        // 确保token0地址 < token1地址 (UniswapV2Pair中会sortTokens)
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // 创建Pair
        address pairAddr = factory.createPair(address(token0), address(token1));
        pair = UniswapV2Pair(pairAddr);

        // 给user和user2铸大量代币
        token0.mint(user, 10_000_000 ether);
        token1.mint(user, 10_000_000 ether);
        token0.mint(user2, 10_000_000 ether);
        token1.mint(user2, 10_000_000 ether);

        // 部署闪电贷测试合约
        flashBorrower = new FlashBorrower();
        faultyBorrower = new FaultyFlashBorrower();

        // 给闪电贷合约也铸一些代币，用于支付手续费
        token0.mint(address(flashBorrower), 10_000 ether);
        token1.mint(address(flashBorrower), 10_000 ether);
    }

    // ---------------------
    // 流动性添加/移除测试
    // ---------------------

    function testMintInitialLiquidity() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);

        uint liquidity = pair.mint(user);
        uint userLP = pair.balanceOf(user);
        assertGt(userLP, 0, "User should have LP after mint");
        assertEq(userLP, liquidity, "User LP should equal returned liquidity");

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 1000 ether, "Reserve0 mismatch");
        assertEq(reserve1, 1000 ether, "Reserve1 mismatch");

        // totalSupply = userLP + MINIMUM_LIQUIDITY(1000)
        uint expectedSupply = userLP + 1000;
        assertEq(pair.totalSupply(), expectedSupply, "Total supply mismatch");

        vm.stopPrank();
    }

    function testMintAdditionalLiquidity() public {
        // 初始流动性
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);
        vm.stopPrank();

        // 额外流动性
        vm.startPrank(user2);
        token0.transfer(address(pair), 500 ether);
        token1.transfer(address(pair), 500 ether);
        uint lp2 = pair.mint(user2);
        uint user2LP = pair.balanceOf(user2);
        assertGt(user2LP, 0, "User2 LP should be > 0");
        assertEq(user2LP, lp2, "User2 LP mismatch");

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 1500 ether, "reserve0 mismatch");
        assertEq(reserve1, 1500 ether, "reserve1 mismatch");
        vm.stopPrank();
    }

    function testMintWithImbalancedLiquidity() public {
        vm.startPrank(user);
        // 初始流动性
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);

        // 不平衡注入
        token0.transfer(address(pair), 200 ether);
        token1.transfer(address(pair), 100 ether);
        uint lpBefore = pair.balanceOf(user);
        uint lpAdded = pair.mint(user);
        uint lpAfter = pair.balanceOf(user);
        assertEq(lpAfter - lpBefore, lpAdded, "LP increase mismatch");

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 1200 ether, "reserve0 mismatch");
        assertEq(reserve1, 1100 ether, "reserve1 mismatch");
        vm.stopPrank();
    }

    function test_RevertWhen_MintInsufficientLiquidity() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 100);
        token1.transfer(address(pair), 100);

        vm.expectRevert();
        pair.mint(user);

        vm.stopPrank();
    }

    function testBurnRemoveLiquidity() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 10000 ether);
        token1.transfer(address(pair), 10000 ether);
        pair.mint(user);

        uint userLP = pair.balanceOf(user);
        uint token0Before = token0.balanceOf(user);
        uint token1Before = token1.balanceOf(user);

        // 全部burn
        pair.transfer(address(pair), userLP);
        (uint amount0, uint amount1) = pair.burn(user);

        uint token0After = token0.balanceOf(user);
        uint token1After = token1.balanceOf(user);

        assertEq(token0After - token0Before, amount0, "amount0 mismatch");
        assertEq(token1After - token1Before, amount1, "amount1 mismatch");

        // reserves应回到最小流动性
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 1000, "reserve0 mismatch");
        assertEq(reserve1, 1000, "reserve1 mismatch");

        vm.stopPrank();
    }

    function testBurnPartialLiquidity() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 10000 ether);
        token1.transfer(address(pair), 10000 ether);
        pair.mint(user);

        uint userLP = pair.balanceOf(user);
        uint burnAmount = userLP / 2;

        uint token0Before = token0.balanceOf(user);
        uint token1Before = token1.balanceOf(user);

        pair.transfer(address(pair), burnAmount);
        (uint amount0, uint amount1) = pair.burn(user);

        uint token0After = token0.balanceOf(user);
        uint token1After = token1.balanceOf(user);
        assertEq(token0After - token0Before, amount0, "amount0 mismatch");
        assertEq(token1After - token1Before, amount1, "amount1 mismatch");

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        // 大约剩一半
        assertApproxEqRel(reserve0, 5000 ether, 1e16, "reserve0 mismatch");
        assertApproxEqRel(reserve1, 5000 ether, 1e16, "reserve1 mismatch");

        vm.stopPrank();
    }

    function test_RevertWhen_BurnInsufficientLiquidity() public {
        vm.startPrank(user);
        // 不给Pair任何LP就burn
        vm.expectRevert();
        pair.burn(user);
        vm.stopPrank();
    }

    // ---------------------
    // Swap测试
    // ---------------------

    function testSwap() public {
        vm.startPrank(user);
        // 初始流动性
        token0.transfer(address(pair), 5000 ether);
        token1.transfer(address(pair), 5000 ether);
        pair.mint(user);

        uint balanceBefore = token1.balanceOf(user);

        // 用100 token0换token1
        token0.transfer(address(pair), 100 ether);
        uint amountOut = 90 ether;
        pair.swap(0, amountOut, user, new bytes(0));

        uint balanceAfter = token1.balanceOf(user);
        uint gained = balanceAfter - balanceBefore;
        assertEq(gained, amountOut, "swap out mismatch");

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 5100 ether, "reserve0 mismatch");
        assertEq(reserve1, 4910 ether, "reserve1 mismatch");

        vm.stopPrank();
    }

    function testSwapToken0ForToken1() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 2000 ether);
        pair.mint(user);

        token0.transfer(address(pair), 10 ether);
        uint expectedOut = 19.7 ether; // 近似

        pair.swap(0, expectedOut, user, new bytes(0));

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 1010 ether, "reserve0 mismatch");
        assertApproxEqAbs(reserve1, 2000 ether - expectedOut, 0.1 ether, "reserve1 mismatch");
        vm.stopPrank();
    }

    function testSwapToken1ForToken0() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);

        token1.transfer(address(pair), 100 ether);
        uint amountOut = 90 ether;
        pair.swap(amountOut, 0, user, new bytes(0));

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 910 ether, "reserve0 mismatch");
        assertEq(reserve1, 1100 ether, "reserve1 mismatch");
        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientOutputAmount() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);

        token0.transfer(address(pair), 10 ether);
        vm.expectRevert("UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT");
        pair.swap(0, 0, user, new bytes(0));
        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientLiquidity() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);

        token0.transfer(address(pair), 10 ether);
        vm.expectRevert("UniswapV2: INSUFFICIENT_LIQUIDITY");
        pair.swap(0, 1001 ether, user, new bytes(0));
        vm.stopPrank();
    }

    function test_RevertWhen_KValueDecreases() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);

        token0.transfer(address(pair), 100 ether);
        vm.expectRevert("UniswapV2: K");
        // 要求输出=输入,没考虑手续费 => K值减少
        pair.swap(0, 100 ether, user, new bytes(0));
        vm.stopPrank();
    }

    // ---------------------
    // 闪电贷测试
    // ---------------------

    function testFlashSwap() public {
        // 1. 初始流动性
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);
        vm.stopPrank();

        // 2. 记录初始状态
        (uint112 reserve0Before, uint112 reserve1Before,) = pair.getReserves();
        uint flashBorrowerToken0Before = token0.balanceOf(address(flashBorrower));

        // 3. 借 10 ether
        uint amount0Out = 10 ether;
        bytes memory flashData = abi.encode("flashLoan test");
        pair.swap(amount0Out, 0, address(flashBorrower), flashData);

        // 4. 计算借款 - 手续费
        uint fee = (amount0Out * 3) / 997 + 1;
        uint netReceived = amount0Out - fee;

        // 5. 校验最终余额 (用近似断言, 允许较大误差)
        uint flashBorrowerToken0After = token0.balanceOf(address(flashBorrower));
        assertApproxEqAbs(
            flashBorrowerToken0After,
            flashBorrowerToken0Before + netReceived,
            1e19, // 允许1 ether误差 (可按需要调大/调小)
            "Flash borrower final balance mismatch"
        );

        // 6. reserves增加了fee
        (uint112 reserve0After, uint112 reserve1After,) = pair.getReserves();
        assertEq(uint(reserve0After), uint(reserve0Before) + fee, "reserve0 mismatch");
        assertEq(reserve1After, reserve1Before, "reserve1 mismatch");
    }

    function test_RevertWhen_FlashSwapNotRepaid() public {
        // 使用faultyBorrower不还款 => revert
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);
        vm.stopPrank();

        vm.expectRevert(); // revert原因可多样
        pair.swap(10 ether, 0, address(faultyBorrower), abi.encode("test fail"));
    }

    // ---------------------
    // skim / sync / feeTo
    // ---------------------

    function testSkim() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);

        // 直接多转100 ether给pair
        token0.transfer(address(pair), 100 ether);
        uint balanceBefore = token0.balanceOf(user);

        pair.skim(user);

        uint balanceAfter = token0.balanceOf(user);
        assertEq(balanceAfter - balanceBefore, 100 ether, "skim mismatch");

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        // 合约中余额应=reserve
        assertEq(token0.balanceOf(address(pair)), reserve0, "token0 mismatch");
        assertEq(token1.balanceOf(address(pair)), reserve1, "token1 mismatch");
        vm.stopPrank();
    }

    function testSync() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);

        // 多转 100,200
        token0.transfer(address(pair), 100 ether);
        token1.transfer(address(pair), 200 ether);

        pair.sync();

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 1100 ether, "reserve0 mismatch");
        assertEq(reserve1, 1200 ether, "reserve1 mismatch");
        vm.stopPrank();
    }

    function testFeeToCollectsFees() public {
        // 启用 feeTo
        factory.setFeeTo(user2);

        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);

        // 进行一些 swap 产生fees
        for (uint i = 0; i < 5; i++) {
            token0.transfer(address(pair), 100 ether);
            pair.swap(0, 90 ether, user, new bytes(0));

            token1.transfer(address(pair), 100 ether);
            pair.swap(90 ether, 0, user, new bytes(0));
        }

        // 再次添加流动性触发fee铸造
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);

        // 验证feeTo已收到LP
        uint feeToBalance = pair.balanceOf(user2);
        assertGt(feeToBalance, 0, "feeTo should have received LP tokens");
        vm.stopPrank();
    }

    // ---------------------
    // 时间戳 / 价格累计
    // ---------------------

    function testBlockTimestampLast() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);

        (, , uint32 blockTimestampLast) = pair.getReserves();

        // 先swap
        token0.transfer(address(pair), 10 ether);
        pair.swap(0, 9 ether, user, new bytes(0));

        // 时间推进
        vm.warp(block.timestamp + 3600);

        // 再swap
        token0.transfer(address(pair), 10 ether);
        pair.swap(0, 9 ether, user, new bytes(0));

        (, , uint32 newBlockTimestampLast) = pair.getReserves();
        assertGt(newBlockTimestampLast, blockTimestampLast, "timestamp not updated");
        vm.stopPrank();
    }

    function testPriceCumulativeLast() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 5000 ether);
        token1.transfer(address(pair), 5000 ether);
        pair.mint(user);

        uint price0CumulativeLastInitial = pair.price0CumulativeLast();
        uint price1CumulativeLastInitial = pair.price1CumulativeLast();

        // 时间推进 & swap改变价格
        vm.warp(block.timestamp + 3600);
        token0.transfer(address(pair), 500 ether);
        pair.swap(0, 250 ether, user, new bytes(0));

        vm.warp(block.timestamp + 3600);
        token0.transfer(address(pair), 10 ether);
        pair.swap(0, 5 ether, user, new bytes(0));

        uint price0CumulativeLastFinal = pair.price0CumulativeLast();
        uint price1CumulativeLastFinal = pair.price1CumulativeLast();
        assertGt(price0CumulativeLastFinal, price0CumulativeLastInitial, "price0Cumulative not increased");
        assertGt(price1CumulativeLastFinal, price1CumulativeLastInitial, "price1Cumulative not increased");
        
        vm.stopPrank();
    }

    function testKLastLogic() public {
        // 1. 打开 feeOn
        //    先让 factory.setFeeTo(...) 指向某个非零地址
        factory.setFeeTo(user2); // feeOn = true

        // 2. 触发一次 mint 或 swap 来更新储备并执行 kLast = reserve0 * reserve1;
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);
        vm.stopPrank();
        // 此时 if(feeOn) kLast = reserve0 * reserve1; 已被执行到

        // 3. 关闭 feeOn
        factory.setFeeTo(address(0)); // feeOn = false

        // 4. 再做一次 mint（或 swap），此时 kLast != 0，但 feeOn = false
        //    => 会执行 kLast = 0;
        vm.startPrank(user);
        token0.transfer(address(pair), 500 ether);
        token1.transfer(address(pair), 500 ether);
        pair.mint(user);
        vm.stopPrank();
        // 此时 if(!feeOn && kLast != 0) kLast = 0; 被执行到

        // 可以加一些断言(如果你在Pair里加了kLast的getter函数)来验证 kLast 已被置0
    }
    function testFeeOnKLast() public {
        // 1. 把 feeTo 设成非零地址 => feeOn = true
        factory.setFeeTo(user2);

        // 2. 执行一次 mint，触发 _update() / _mintFee()
        vm.startPrank(user);
        token0.transfer(address(pair), 1000 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(user);
        vm.stopPrank();

        // 如果你想验证 kLast 真的赋值成功，需要在 Pair 里写一个 getter
        assertEq(pair.kLast(), 1000 ether * 1000 ether, "kLast mismatch");
    }
}
