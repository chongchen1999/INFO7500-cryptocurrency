// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "lib/forge-std/src/Test.sol"; 
import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Pair.sol";
import "../test/mocks/ERC20Mintable.sol";

contract TestUniswapV2Factory is Test {
    UniswapV2Factory factory;
    ERC20Mintable tokenA;
    ERC20Mintable tokenB;
    ERC20Mintable tokenC;
    address alice = address(0x123);
    address bob = address(0x456);
    address carol = address(0x789);

    function setUp() public {
        // 部署Factory，本合约作为feeToSetter
        factory = new UniswapV2Factory(address(this));

        // 部署测试代币
        tokenA = new ERC20Mintable("Token A", "TKA");
        tokenB = new ERC20Mintable("Token B", "TKB");
        tokenC = new ERC20Mintable("Token C", "TKC");
    }

    // 测试创建交易对时检查代币地址
    function test_RevertWhen_CreatePairWithSameToken() public {
        vm.expectRevert();
        factory.createPair(address(tokenA), address(tokenA));
    }

    // 测试创建交易对时检查零地址
    function test_RevertWhen_CreatePairWithZeroAddress() public {
        vm.expectRevert();
        factory.createPair(address(0), address(tokenB));
        
        vm.expectRevert();
        factory.createPair(address(tokenA), address(0));
    }

    // 测试普通创建交易对
    function testCreatePair() public {
        address pair = factory.createPair(address(tokenA), address(tokenB));
        address storedPair = factory.getPair(address(tokenA), address(tokenB));
        
        // 检查地址匹配
        assertEq(pair, storedPair, "Pair address mismatch");
        
        // 检查反向查询也能工作
        address reversePair = factory.getPair(address(tokenB), address(tokenA));
        assertEq(pair, reversePair, "Reverse pair lookup failed");
        
        // 检查allPairs数组
        assertEq(factory.allPairsLength(), 1, "Pairs length should be 1");
        assertEq(factory.allPairs(0), pair, "Pair should be in allPairs");
    }

    // 测试创建多个交易对
    function testCreateMultiplePairs() public {
        address pair1 = factory.createPair(address(tokenA), address(tokenB));
        address pair2 = factory.createPair(address(tokenA), address(tokenC));
        address pair3 = factory.createPair(address(tokenB), address(tokenC));
        
        // 检查地址匹配
        assertEq(factory.getPair(address(tokenA), address(tokenB)), pair1);
        assertEq(factory.getPair(address(tokenA), address(tokenC)), pair2);
        assertEq(factory.getPair(address(tokenB), address(tokenC)), pair3);
        
        // 检查allPairs数组
        assertEq(factory.allPairsLength(), 3, "Pairs length should be 3");
        assertEq(factory.allPairs(0), pair1);
        assertEq(factory.allPairs(1), pair2);
        assertEq(factory.allPairs(2), pair3);
    }

    // 测试重复创建相同的交易对会失败
    function test_RevertWhen_CreatePairTwice() public {
        factory.createPair(address(tokenA), address(tokenB));
        
        vm.expectRevert("UniswapV2: PAIR_EXISTS");
        factory.createPair(address(tokenA), address(tokenB));
        
        // 反向顺序也应该失败
        vm.expectRevert("UniswapV2: PAIR_EXISTS");
        factory.createPair(address(tokenB), address(tokenA));
    }

    // 测试创建的交易对是否正确初始化
    function testPairInitialization() public {
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        UniswapV2Pair pair = UniswapV2Pair(pairAddress);
        
        // 检查代币地址
        (address token0, address token1) = tokenA < tokenB 
            ? (address(tokenA), address(tokenB)) 
            : (address(tokenB), address(tokenA));
            
        assertEq(pair.token0(), token0, "Token0 mismatch");
        assertEq(pair.token1(), token1, "Token1 mismatch");
        assertEq(pair.factory(), address(factory), "Factory mismatch");
    }

    // 测试设置feeTo
    function testSetFeeTo() public {
        // 初始 feeTo 应为 0
        assertEq(factory.feeTo(), address(0));
        
        // 设置后再检查
        factory.setFeeTo(alice);
        assertEq(factory.feeTo(), alice);
        
        // 再次更改
        factory.setFeeTo(bob);
        assertEq(factory.feeTo(), bob);
        
        // 改回0地址
        factory.setFeeTo(address(0));
        assertEq(factory.feeTo(), address(0));
    }

    // 测试非feeToSetter尝试设置feeTo会失败
    function test_RevertWhen_UnauthorizedSetFeeTo() public {
        vm.prank(alice);
        vm.expectRevert("UniswapV2: FORBIDDEN");
        factory.setFeeTo(alice);
    }

    // 测试设置feeToSetter
    function testSetFeeToSetter() public {
        assertEq(factory.feeToSetter(), address(this));
        
        factory.setFeeToSetter(alice);
        assertEq(factory.feeToSetter(), alice);

        // 再次修改只允许 alice
        vm.prank(alice);
        factory.setFeeToSetter(bob);
        assertEq(factory.feeToSetter(), bob);
        
        // bob再次修改
        vm.prank(bob);
        factory.setFeeToSetter(carol);
        assertEq(factory.feeToSetter(), carol);
    }

    // 测试非feeToSetter尝试设置feeToSetter会失败
    function test_RevertWhen_UnauthorizedSetFeeToSetter() public {
        vm.prank(alice);
        vm.expectRevert("UniswapV2: FORBIDDEN");
        factory.setFeeToSetter(alice);
        
        // 即使当前的feeToSetter已经变更，旧的feeToSetter也不能再设置
        factory.setFeeToSetter(alice);
        
        vm.prank(address(this));
        vm.expectRevert("UniswapV2: FORBIDDEN");
        factory.setFeeToSetter(address(this));
    }

    // 测试获取INIT_CODE_PAIR_HASH
    function testGetInitCodePairHash() public {
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(UniswapV2Pair).creationCode));
        console.logBytes32(initCodeHash);
        
        // 验证CREATE2地址计算
        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        
        address computedAddress = address(uint160(uint256(keccak256(abi.encodePacked(
            hex'ff',
            address(factory),
            keccak256(abi.encodePacked(token0, token1)),
            initCodeHash
        )))));
        
        address actualAddress = factory.createPair(address(tokenA), address(tokenB));
        assertEq(actualAddress, computedAddress, "CREATE2 address calculation failed");
    }

    // 测试遍历所有交易对
    function testIterateAllPairs() public {
        // 创建几个交易对
        address pair1 = factory.createPair(address(tokenA), address(tokenB));
        address pair2 = factory.createPair(address(tokenA), address(tokenC));
        address pair3 = factory.createPair(address(tokenB), address(tokenC));
        
        // 检查长度
        assertEq(factory.allPairsLength(), 3);
        
        // 模拟遍历所有交易对
        address[] memory pairs = new address[](factory.allPairsLength());
        for (uint i = 0; i < factory.allPairsLength(); i++) {
            pairs[i] = factory.allPairs(i);
        }
        
        // 验证遍历结果
        assertEq(pairs[0], pair1);
        assertEq(pairs[1], pair2);
        assertEq(pairs[2], pair3);
    }
}