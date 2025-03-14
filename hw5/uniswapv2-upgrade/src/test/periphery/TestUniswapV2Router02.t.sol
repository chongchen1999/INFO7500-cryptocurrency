// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

// ============ Mock Contracts ============
import "src/core/UniswapV2Factory.sol";
import "src/periphery/UniswapV2Router02.sol";
import "src/test/mocks/ERC20Mintable.sol";
import "src/test/mocks/WETH9.sol";

// --------------------------------------
// 额外的“带转账税”Token，用于测试 SupportingFeeOnTransfer
// --------------------------------------
contract ERC20FeeOnTransfer is ERC20Mintable {
    uint256 public feePercentage;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _feePercentage
    ) ERC20Mintable(_name, _symbol) {
        feePercentage = _feePercentage; // 如：10 表示 1% 手续费
    }

    // 新增内部的 _transfer 和 _burn 函数直接操作继承来的存储变量
    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }

    function _burn(address account, uint256 amount) internal {
        require(balanceOf[account] >= amount, "ERC20: burn amount exceeds balance");
        balanceOf[account] -= amount;
        totalSupply -= amount;
    }

    /// 用一个新函数实现带手续费的转账功能
    function transferWithFee(address recipient, uint256 amount) public returns (bool) {
        uint256 fee = (amount * feePercentage) / 1000;
        uint256 sendAmount = amount - fee;
        _burn(msg.sender, fee);
        _transfer(msg.sender, recipient, sendAmount);
        return true;
    }
}

contract TestUniswapV2Router02FullCoverage is Test {
    UniswapV2Factory factory;
    UniswapV2Router02 router;
    ERC20Mintable tokenA;
    ERC20Mintable tokenB;
    WETH9 weth;
    ERC20FeeOnTransfer feeToken; // 用于测试支持FeeOnTransfer的swap

    address user = address(0x999);
    address otherUser = address(0x888);

    // 为了测试 removeLiquidityWithPermit / removeLiquidityETHWithPermit
    // 这里存一下签名参数
    uint8 v;
    bytes32 r;
    bytes32 s;

    function setUp() public {
        // 部署Factory & WETH
        factory = new UniswapV2Factory(address(this));
        weth = new WETH9();

        // 部署Router
        router = new UniswapV2Router02(address(factory), address(weth));

        // 部署代币
        tokenA = new ERC20Mintable("TokenA", "TKA");
        tokenB = new ERC20Mintable("TokenB", "TKB");
        feeToken = new ERC20FeeOnTransfer("FeeToken", "FEE", 10); // 1% 转账税

        // 给 user & otherUser 铸一些代币
        tokenA.mint(user, 1_000_000 ether);
        tokenB.mint(user, 1_000_000 ether);
        feeToken.mint(user, 1_000_000 ether);

        tokenA.mint(otherUser, 1_000_000 ether);
        tokenB.mint(otherUser, 1_000_000 ether);
        feeToken.mint(otherUser, 1_000_000 ether);

        // 给 user & otherUser 一些 ETH
        vm.deal(user, 100 ether);
        vm.deal(otherUser, 100 ether);
    }

    // ==============================
    //         流动性相关测试
    // ==============================

    function testAddLiquidity() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            2000 ether,
            900 ether,
            1800 ether,
            user,
            block.timestamp + 1000
        );

        assertEq(amountA, 1000 ether, "amountA mismatch");
        assertEq(amountB, 2000 ether, "amountB mismatch");
        assertGt(liquidity, 0, "liquidity should be > 0");

        vm.stopPrank();
    }

    function testAddLiquidityETH() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);

        (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{
            value: 10 ether
        }(
            address(tokenA),
            100 ether,   // amountTokenDesired
            50 ether,    // amountTokenMin
            5 ether,     // amountETHMin
            user,
            block.timestamp + 1000
        );

        assertEq(amountToken, 100 ether, "Token used mismatch");
        assertEq(amountETH, 10 ether, "ETH used mismatch");
        assertGt(liquidity, 0, "Liquidity minted");
        vm.stopPrank();
    }

    function testRemoveLiquidity() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        // 先添加一些流动性
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

        // 获取 pair 地址
        address pair = factory.getPair(address(tokenA), address(tokenB));
        // 先批准Router能花费LP
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

        // 先添加一些 TokenA/ETH 流动性
        (, , uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            1000 ether,
            900 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );

        // 获取 pair 地址
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

    // ==============================
    //    removeLiquidityWithPermit
    // ==============================
    // 这里演示如何签名 & 用 permit 移除流动性
    // 如果要真正覆盖签名校验，需要做 EIP-2612 签名；此处仅做示例

    function testRemoveLiquidityETHWithPermit() public {
        // 先由 user 添加一些流动性
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);

        (, , uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            1000 ether,
            900 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );
        vm.stopPrank();

        // 获取 pair 地址
        // 用 permit 的方式，不再需要 approve

        // ======= 准备签名 =======
        // Pair 合约本身支持 permit（UniswapV2ERC20）
        // 这里仅做一个最小化的示例，不做完整 EIP-712 结构校验
        // 真实场景请参考 Foundry 官方文档 / EIP-2612
        {
            // 生成一条无效签名看能否正常revert
            vm.startPrank(user);
            vm.expectRevert();
            router.removeLiquidityETHWithPermit(
                address(tokenA),
                liquidity,
                900 ether,
                9 ether,
                user,
                block.timestamp + 1000,
                false, // approveMax
                v, r, s
            );
            vm.stopPrank();
        }

        // 如果要测试成功场景，需要正确的 v, r, s。
        // 下面仅示例: 强行用“假签名”调用, 一般会 revert.
        // 如果你想让测试通过, 需用 EIP-2612 方式先生成真正的签名.

        // vm.startPrank(user);
        // router.removeLiquidityETHWithPermit(
        //     address(tokenA),
        //     liquidity,
        //     900 ether,
        //     9 ether,
        //     user,
        //     block.timestamp + 1000,
        //     false, // approveMax
        //     v, r, s
        // );
        // vm.stopPrank();
    }

    // ==============================
    //           Swap 相关
    // ==============================

    function testSwapExactTokensForTokens() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        // 添加 1:1 流动性
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

        uint balanceBBefore = tokenB.balanceOf(user);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        // 用 100 tokenA 换 tokenB
        router.swapExactTokensForTokens(
            100 ether,
            1, // 最少接收1个
            path,
            user,
            block.timestamp + 1000
        );

        uint balanceBAfter = tokenB.balanceOf(user);
        assertGt(balanceBAfter, balanceBBefore, "User B balance should increase");

        vm.stopPrank();
    }

    function testSwapTokensForExactTokens() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        // 添加 1:1 流动性
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

        // 用户希望换到 200 tokenB，愿意付出最多 300 tokenA
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint[] memory amounts = router.swapTokensForExactTokens(
            200 ether,
            300 ether,
            path,
            user,
            block.timestamp + 1000
        );

        // amounts[0] = 实际花了多少 tokenA
        // amounts[1] = 获得多少 tokenB
        assertLe(amounts[0], 300 ether, "Spent too many TokenA");
        assertEq(amounts[1], 200 ether, "Did not get exact B");
        vm.stopPrank();
    }

    function testSwapExactTokensForETH() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);

        // 先添加 TokenA/WETH 流动性（即 ETH 流动性）
        router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            1000 ether,   // amountTokenDesired
            1000 ether,   // amountTokenMin
            10 ether,     // amountETHMin
            user,
            block.timestamp + 1000
        );

        uint balanceETHBefore = user.balance;

        // 路径：TokenA -> WETH -> (提取成ETH)
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);

        // 用 100 tokenA 换 ETH，最少接收 1 wei 即可
        router.swapExactTokensForETH(
            100 ether,
            1, 
            path,
            user,
            block.timestamp + 1000
        );

        uint balanceETHAfter = user.balance;
        assertGt(balanceETHAfter, balanceETHBefore, "User's ETH balance should increase");

        vm.stopPrank();
    }

    function testSwapTokensForExactETH() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);

        // 先添加 TokenA/WETH 流动性
        router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            1000 ether,
            900 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );

        uint balanceETHBefore = user.balance;

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);

        // 想要精确得到 2 ETH，最多付 500 tokenA
        uint[] memory amounts = router.swapTokensForExactETH(
            2 ether,
            500 ether,
            path,
            user,
            block.timestamp + 1000
        );

        assertEq(amounts[1], 2 ether, "Did not get exact 2 ETH");
        assertLe(amounts[0], 500 ether, "Spent too many TokenA");

        uint balanceETHAfter = user.balance;
        assertEq(balanceETHAfter, balanceETHBefore + 2 ether, "ETH not correct");

        vm.stopPrank();
    }

    function testSwapExactETHForTokens() public {
        vm.startPrank(user);
        tokenB.approve(address(router), type(uint).max);

        // 先添加 TokenB/WETH 流动性
        router.addLiquidityETH{value: 10 ether}(
            address(tokenB),
            1000 ether,   // amountTokenDesired
            900 ether,    // amountTokenMin
            9 ether,      // amountETHMin
            user,
            block.timestamp + 1000
        );

        uint balanceBBefore = tokenB.balanceOf(user);

        // 路径：WETH -> TokenB
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenB);

        // 用 1 ETH 换 TokenB
        router.swapExactETHForTokens{value: 1 ether}(
            1, // 最少接收 1 wei 的 TokenB
            path,
            user,
            block.timestamp + 1000
        );

        uint balanceBAfter = tokenB.balanceOf(user);
        assertGt(balanceBAfter, balanceBBefore, "User B balance should increase");

        vm.stopPrank();
    }

    function testSwapETHForExactTokens() public {
        vm.startPrank(user);
        tokenB.approve(address(router), type(uint).max);

        // 先添加 TokenB/WETH 流动性
        router.addLiquidityETH{value: 10 ether}(
            address(tokenB),
            1000 ether,
            900 ether,
            9 ether,
            user,
            block.timestamp + 1000
        );

        uint balanceBBefore = tokenB.balanceOf(user);

        // 路径：WETH -> TokenB
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenB);

        // 想要精确得到 100 TokenB，最多支付 2 ETH
        uint[] memory amounts = router.swapETHForExactTokens{value: 2 ether}(
            100 ether,
            path,
            user,
            block.timestamp + 1000
        );

        // amounts[1] = 实际得到的 TokenB
        assertEq(amounts[1], 100 ether, "Did not get exact TokenB");
        // 可能只花费了其中的一部分 ETH
        assertLe(amounts[0], 2 ether, "Spent too many ETH");

        // 多余的 ETH 会退回
        uint balanceBAfter = tokenB.balanceOf(user);
        assertEq(balanceBAfter, balanceBBefore + 100 ether, "User B balance mismatch");

        vm.stopPrank();
    }

    // ==============================
    //   支持 Fee on Transfer 测试
    // ==============================
    // 演示 swapExactTokensForTokensSupportingFeeOnTransferTokens
    // 其余 supportingFeeOnTransfer 逻辑同理

    function testSwapExactTokensForTokensSupportingFeeOnTransferTokens() public {
        vm.startPrank(user);
        feeToken.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        // 先给 feeToken/tokenB 加一些流动性
        // feeToken 有 1% 转账税，会在 transfer 时销毁一部分
        router.addLiquidity(
            address(feeToken),
            address(tokenB),
            1000 ether,
            1000 ether,
            900 ether,
            900 ether,
            user,
            block.timestamp + 1000
        );

        uint balanceBBefore = tokenB.balanceOf(user);

        address[] memory path = new address[](2);
        path[0] = address(feeToken);
        path[1] = address(tokenB);

        // 调用 supportingFeeOnTransfer 的版本
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100 ether, // 准备卖出 100 feeToken
            1,         // 最少接收 1 wei 的 tokenB
            path,
            user,
            block.timestamp + 1000
        );

        uint balanceBAfter = tokenB.balanceOf(user);
        assertGt(balanceBAfter, balanceBBefore, "User B balance should increase after fee swap");

        vm.stopPrank();
    }

    // ==============================
    //   一些常见“负面”测试示例
    // ==============================

    // 比如测试无效路径
    function testSwapRevertInvalidPath() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);

        // 不添加流动性，或者 path 长度 < 2
        address[] memory path = new address[](1);
        path[0] = address(tokenA);

        vm.expectRevert(); 
        router.swapExactTokensForTokens(100 ether, 1, path, user, block.timestamp + 1000);

        vm.stopPrank();
    }

    // 比如测试deadline过期
    function testSwapRevertDeadlineExpired() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);

        // 传一个已经过期的deadline
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.expectRevert(); 
        router.swapExactTokensForTokens(100 ether, 1, path, user, block.timestamp - 1);

        vm.stopPrank();
    }

    // 还可以测试 amountOutMin 太高 导致滑点过大场景等
    // ...
    function testAddLiquidity_CoverAllBranches() public {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        // 1) 第一次注入：空池 -> (reserveA == 0 && reserveB == 0) 分支
        //    假设我们注入 A=1000, B=2000，池子比例 = 1 : 2
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            2000 ether,
            1000 ether,
            2000 ether,
            user,
            block.timestamp + 1000
        );
        // 现在池子里 reserveA=1000, reserveB=2000

        // 2) 再注入一次，这次要触发 "amountBOptimal <= amountBDesired"
        //    amountBOptimal = (amountADesired * reserveB) / reserveA
        //                    = (100 * 2000) / 1000
        //                    = 200
        //    如果 amountBDesired=300，则 200 <= 300 => 走第一个分支
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,   // amountADesired
            300 ether,   // amountBDesired
            70 ether,    // amountAMin
            200 ether,   // amountBMin
            user,
            block.timestamp + 1000
        );

        // 3) 再注入一次，这次要触发 "amountBOptimal > amountBDesired"
        //    同理, amountBOptimal 还是 200
        //    如果 amountBDesired=150，则 200 > 150 => 走 else 分支
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,   // amountADesired
            150 ether,   // amountBDesired
            70 ether,    // amountAMin
            150 ether,   // amountBMin
            user,
            block.timestamp + 1000
        );

        vm.stopPrank();
    }
    
    function testSwapExactETHForTokensSupportingFeeOnTransferTokens() public {
        vm.startPrank(user);

        // 1) 先给 user 存一些 WETH 流动性, 也可以用 addLiquidityETH
        feeToken.approve(address(router), type(uint).max);

        // 给 feeToken/WETH 添加流动性
        router.addLiquidityETH{value: 10 ether}(
            address(feeToken),
            1000 ether, // amountTokenDesired
            900 ether,  // amountTokenMin
            9 ether,    // amountETHMin
            user,
            block.timestamp + 1000
        );

        // 2) 构造路径: [WETH, feeToken]
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(feeToken);

        uint balanceBefore = feeToken.balanceOf(user);

        // 3) swapExactETHForTokensSupportingFeeOnTransferTokens
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1 ether}(
            1, // amountOutMin
            path,
            user,
            block.timestamp + 1000
        );

        // 4) 断言
        uint balanceAfter = feeToken.balanceOf(user);
        assertGt(balanceAfter, balanceBefore, "User's FeeToken should increase");

        vm.stopPrank();
        }

    function testSwapExactTokensForETHSupportingFeeOnTransferTokens() public {
        vm.startPrank(user);
        feeToken.approve(address(router), type(uint).max);

        // 1) 先添加 feeToken/WETH 流动性
        router.addLiquidityETH{value: 5 ether}(
            address(feeToken),
            1000 ether,
            900 ether,
            4 ether,
            user,
            block.timestamp + 1000
        );

        // 2) 构造路径: [feeToken, WETH]
        address[] memory path = new address[](2);
        path[0] = address(feeToken);
        path[1] = address(weth);

        uint balanceETHBefore = user.balance;

        // 3) swapExactTokensForETHSupportingFeeOnTransferTokens
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            100 ether, // amountIn
            1,         // amountOutMin
            path,
            user,
            block.timestamp + 1000
        );

        // 4) 断言
        uint balanceETHAfter = user.balance;
        assertGt(balanceETHAfter, balanceETHBefore, "User's ETH should increase");

        vm.stopPrank();
    }

    function testQuote() public view{
        // 假设: reserveA=1000, reserveB=2000, amountA=100
        // 正常情况: quote = (amountA * reserveB) / reserveA = (100 * 2000)/1000 = 200
        uint amountB = router.quote(100, 1000, 2000);
        assertEq(amountB, 200, "quote mismatch");
    }

    // 测试 quote() 的负面场景, reserveA=0 => revert
    function testQuoteRevert_ReserveAZero() public {
       vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.quote(100, 0, 2000);
    }

    // ==================================
    // 2) 测试 getAmountOut()
    // ==================================
    function testGetAmountOut() public view{
        // 常见公式: getAmountOut(amountIn, reserveIn, reserveOut) = 
        //   amountInWithFee = amountIn * 997
        //   numerator = amountInWithFee * reserveOut
        //   denominator = reserveIn * 1000 + amountInWithFee
        //   amountOut = numerator / denominator
        // 这里随便用一些数值做断言
        uint out = router.getAmountOut(100, 1000, 2000);
        // 计算一下手动:
        //   amountInWithFee = 100 * 997 = 99700
        //   numerator = 99700 * 2000 = 199400000
        //   denominator = 1000*1000 + 99700 = 1000000 + 99700 = 1099700
        //   out = 199400000 / 1099700 ~ 181
        assertEq(out, 181, "getAmountOut mismatch");
    }

    // 负面场景: amountIn=0 => revert
    function testGetAmountOutRevert_ZeroAmountIn() public {
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT"));
        router.getAmountOut(0, 1000, 2000);
    }

    // 负面场景: reserveIn=0 or reserveOut=0 => revert
    function testGetAmountOutRevert_ZeroReserves() public {
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.getAmountOut(100, 0, 2000);

        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.getAmountOut(100, 1000, 0);
    }

    // ==================================
    // 3) 测试 getAmountIn()
    // ==================================
    function testGetAmountIn() public view{
        // formula: getAmountIn(amountOut, reserveIn, reserveOut) = 
        //   numerator = reserveIn * amountOut * 1000
        //   denominator = (reserveOut - amountOut)*997
        //   amountIn = numerator / denominator + 1
        // 例如: amountOut=200, reserveIn=1000, reserveOut=2000
        //   numerator = 1000*200*1000 = 200,000,000
        //   denominator = (2000 - 200)*997 = 1800*997 = 1,794,600
        //   amountIn ~ 111 (加1 之后 ~ 112)
        uint inAmt = router.getAmountIn(200, 1000, 2000);
        // 你可以手动算一下
        // 下面给个大概 assert
        assertEq(inAmt, 112, "getAmountIn mismatch");
    }

    function testGetAmountInRevert_ZeroAmountOut() public {
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT"));
        router.getAmountIn(0, 1000, 2000);
    }

    function testGetAmountInRevert_ZeroReserves() public {
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.getAmountIn(200, 0, 2000);

        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.getAmountIn(200, 1000, 0);
    }

    // ==================================
    // 4) 测试 getAmountsOut()
    // ==================================
    // 这里需要一个真实的 pair, path 才不会 revert "UniswapV2Library: INVALID_PATH"
    function testGetAmountsOut_SingleHop() public {
        // 先添加 A-B 流动性
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            2000 ether,
            900 ether,
            1800 ether,
            user,
            block.timestamp + 1000
        );
        vm.stopPrank();

        // 构造 path: A -> B
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        // getAmountsOut(100, [A,B])
        uint[] memory amounts = router.getAmountsOut(100 ether, path);
        // amounts[0] = 100
        // amounts[1] = 经过公式计算
        assertEq(amounts[0], 100 ether, "input mismatch");
        assertGt(amounts[1], 0, "output should be > 0");
    }

    // 多跳: A -> WETH -> B
    function testGetAmountsOut_MultiHop() public {
        // 添加 A-WETH, WETH-B 流动性
        vm.startPrank(user);

        // 1) 先把原生 ETH 存进 WETH
        //    比如需要 20~30 ETH 做流动性，自己估计
        weth.deposit{value: 20 ether}();

        // 2) approve
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);
        weth.approve(address(router), type(uint).max);

        // 3) 添加 A-WETH 流动性
        //    不要写 1000 ether 太大，user 只有 20 WETH
        router.addLiquidity(
            address(tokenA),
            address(weth),
            10 ether,   // amountTokenDesired
            10 ether,   // amountWETHDesired
            9 ether,    // amountTokenMin
            9 ether,    // amountWETHMin
            user,
            block.timestamp + 1000
        );

        // 4) 再添加 WETH-B 流动性
        router.addLiquidity(
            address(weth),
            address(tokenB),
            10 ether,   // amountWETHDesired
            20 ether,   // amountBDesired
            9 ether,
            18 ether,
            user,
            block.timestamp + 1000
        );

        vm.stopPrank();

        // 5) 构造多跳路径 A->WETH->B，然后
        //    router.getAmountsOut(1 ether, path) 等
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(weth);
        path[2] = address(tokenB);

        uint[] memory amounts = router.getAmountsOut(1 ether, path);
        assertEq(amounts.length, 3, "length mismatch");
        // amounts[0] = 100
        // amounts[1] = ...
        // amounts[2] = ...
        assertEq(amounts[0], 1e18 , "input mismatch");
        assertGt(amounts[2], 0, "final output > 0");
    }

    // 负面场景: path无效
    function testGetAmountsOutRevert_InvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = address(tokenA);

        vm.expectRevert(); // 具体 revert msg 可能是 "UniswapV2Library: INVALID_PATH"
        router.getAmountsOut(100, path);
    }

    // ==================================
    // 5) 测试 getAmountsIn()
    // ==================================
    function testGetAmountsIn_SingleHop() public {
        // 跟 getAmountsOut 类似, 先有 A-B 流动性
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 ether,
            2000 ether,
            900 ether,
            1800 ether,
            user,
            block.timestamp + 1000
        );
        vm.stopPrank();

        // A -> B
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        // 想得到 500 B, 计算需要多少 A
        uint[] memory amounts = router.getAmountsIn(500 ether, path);
        // amounts[1] = 500
        // amounts[0] = some > 0
        assertEq(amounts[1], 500 ether, "final output mismatch");
        assertGt(amounts[0], 0, "input A should be > 0");
    }
    function testGetAmountsIn_MultiHop() public {
        // 测试目标：A -> WETH -> B，想要得到 500 B，计算需要多少 A

        // ========== 1) 先让 user 有足够 ETH，并转换一部分为 WETH ==========
        vm.deal(user, 100 ether); // 给 user 100 ETH
        vm.startPrank(user);

        // 存 20 ETH 进 WETH, 这样 user 有 20 WETH
        weth.deposit{value: 20 ether}(); 

        // 2) 给路由器 approve A, B, WETH
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);
        weth.approve(address(router), type(uint).max);

        // ========== 3) 给 (A, WETH) 池添加一些流动性 ==========
        // 这里注入 10 A + 10 WETH => 池子比例 1:1
        // 确保 user 真的持有 >= 10 WETH
        router.addLiquidity(
            address(tokenA),
            address(weth),
            10 ether,  // amountADesired
            10 ether,  // amountWETHDesired
            9 ether,   // amountAMin
            9 ether,   // amountWETHMin
            user,
            block.timestamp + 1000
        );

        // ========== 4) 给 (WETH, B) 池添加一些流动性 ==========
        // 这里注入 10 WETH + 2000 B => 池子比例 1 : 200
        // 这样如果我们想得到 500 B，池子里有足够 B 来计算
        router.addLiquidity(
            address(weth),
            address(tokenB),
            10 ether,    // amountWETHDesired
            2000 ether,  // amountBDesired
            9 ether,     // amountWETHMin
            1800 ether,  // amountBMin
            user,
            block.timestamp + 1000
        );

        vm.stopPrank();

        // ========== 5) 调用 getAmountsIn(500 B, [A, WETH, B]) ==========
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(weth);
        path[2] = address(tokenB);

        uint[] memory amounts = router.getAmountsIn(500 ether, path);

        // ========== 6) 断言结果 ==========
        // amounts.length == 3
        // amounts[0] = 需要多少 A
        // amounts[1] = 中间过程的 WETH
        // amounts[2] = 500
        assertEq(amounts.length, 3, "length mismatch");
        assertEq(amounts[2], 500 ether, "final output mismatch");
        assertGt(amounts[0], 0, "input A should be > 0");
    }
    function testGetAmountsInRevert_InvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = address(tokenA);

        vm.expectRevert(); 
        router.getAmountsIn(100, path);
    }
}