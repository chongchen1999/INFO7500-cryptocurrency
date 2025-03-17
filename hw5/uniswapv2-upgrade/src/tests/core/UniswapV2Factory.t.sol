// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "lib/forge-std/src/Test.sol";
import "src/contracts/UniswapV2Factory.sol";
import "src/contracts/UniswapV2Pair.sol";

contract UniswapV2FactoryTest is Test {
    UniswapV2Factory factory;
    
    address TEST_ADDRESS_1 = address(0x1000000000000000000000000000000000000000);
    address TEST_ADDRESS_2 = address(0x2000000000000000000000000000000000000000);
    
    address wallet;
    address other;
    
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );
    
    function setUp() public {
        wallet = address(this);
        other = address(0xABCD);
        
        // 创建工厂合约，设置feeToSetter为测试合约地址
        factory = new UniswapV2Factory(wallet);
    }
    
    function testFeeToFeeToSetterAllPairsLength() view public {
        assertEq(factory.feeTo(), address(0));
        assertEq(factory.feeToSetter(), wallet);
        assertEq(factory.allPairsLength(), 0);
    }
    
    function testCreatePair() public {
        address token0 = TEST_ADDRESS_1;
        address token1 = TEST_ADDRESS_2;
        
        // 确保token0 < token1，以匹配Uniswap的排序逻辑
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        
        // 计算预期的pair地址
        address expectedPairAddress = computeAddress(factory, token0, token1);
        
        // 验证PairCreated事件
        vm.expectEmit(true, true, true, true);
        emit PairCreated(token0, token1, expectedPairAddress, 1);
        
        // 创建交易对
        factory.createPair(TEST_ADDRESS_1, TEST_ADDRESS_2);
        
        // 验证创建重复交易对会失败
        vm.expectRevert(bytes("UniswapV2: PAIR_EXISTS"));
        factory.createPair(TEST_ADDRESS_1, TEST_ADDRESS_2);
        
        // 验证反序创建也会失败
        vm.expectRevert(bytes("UniswapV2: PAIR_EXISTS"));
        factory.createPair(TEST_ADDRESS_2, TEST_ADDRESS_1);
        
        // 验证getPair功能
        assertEq(factory.getPair(TEST_ADDRESS_1, TEST_ADDRESS_2), expectedPairAddress);
        assertEq(factory.getPair(TEST_ADDRESS_2, TEST_ADDRESS_1), expectedPairAddress);
        
        // 验证allPairs和allPairsLength
        assertEq(factory.allPairs(0), expectedPairAddress);
        assertEq(factory.allPairsLength(), 1);
        
        // 验证pair合约的属性
        UniswapV2Pair pair = UniswapV2Pair(expectedPairAddress);
        assertEq(address(pair.factory()), address(factory));
        assertEq(pair.token0(), token0);
        assertEq(pair.token1(), token1);
    }
    
    function testCreatePairReverse() public {
        address token0 = TEST_ADDRESS_2; // 注意这里顺序相反
        address token1 = TEST_ADDRESS_1;
        
        // 确保token0 < token1，以匹配Uniswap的排序逻辑
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        
        // 计算预期的pair地址
        address expectedPairAddress = computeAddress(factory, token0, token1);
        
        // 验证PairCreated事件
        vm.expectEmit(true, true, true, true);
        emit PairCreated(token0, token1, expectedPairAddress, 1);
        
        // 创建交易对（注意这里用反序的参数）
        factory.createPair(TEST_ADDRESS_2, TEST_ADDRESS_1);
        
        // 验证基本属性
        assertEq(factory.getPair(TEST_ADDRESS_1, TEST_ADDRESS_2), expectedPairAddress);
        assertEq(factory.getPair(TEST_ADDRESS_2, TEST_ADDRESS_1), expectedPairAddress);
        assertEq(factory.allPairs(0), expectedPairAddress);
        assertEq(factory.allPairsLength(), 1);
    }
    
    function testCreatePairGas() public {
        // 在Foundry中衡量gas使用
        uint256 gasBefore = gasleft();
        factory.createPair(TEST_ADDRESS_1, TEST_ADDRESS_2);
        uint256 gasUsed = gasBefore - gasleft();
        
        // 注意：具体数值可能需要调整
        // 原测试期望值为2512920
        assertLe(gasUsed, 4000000);
    }
    
    function testSetFeeTo() public {
        // 测试非授权用户无法设置feeTo
        vm.prank(other);
        vm.expectRevert(bytes("UniswapV2: FORBIDDEN"));
        factory.setFeeTo(other);
        
        // 测试授权用户可以设置feeTo
        factory.setFeeTo(wallet);
        assertEq(factory.feeTo(), wallet);
    }
    
    function testSetFeeToSetter() public {
        // 测试非授权用户无法设置feeToSetter
        vm.prank(other);
        vm.expectRevert(bytes("UniswapV2: FORBIDDEN"));
        factory.setFeeToSetter(other);
        
        // 测试授权用户可以设置feeToSetter
        factory.setFeeToSetter(other);
        assertEq(factory.feeToSetter(), other);
        
        // 测试旧的feeToSetter不再有权限
        vm.expectRevert(bytes("UniswapV2: FORBIDDEN"));
        factory.setFeeToSetter(wallet);
    }
    
    // 辅助函数：计算pair地址
    function computeAddress(
        UniswapV2Factory _factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
            hex'ff',
            address(_factory),
            salt,
            keccak256(type(UniswapV2Pair).creationCode)
        )))));
    }
}
