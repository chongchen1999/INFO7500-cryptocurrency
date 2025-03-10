// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/core/UniswapV2Factory.sol";
import "../../src/core/UniswapV2Pair.sol";

contract UniswapV2FactoryTest is Test {
    UniswapV2Factory factory;
    address feeToSetter = address(0x123);
    address tokenA = address(0x456);
    address tokenB = address(0x789);

    function setUp() public {
        factory = new UniswapV2Factory(feeToSetter);
    }

    function testSetFeeTo() public {
        vm.prank(feeToSetter);
        factory.setFeeTo(address(0xabc));
        assertEq(factory.feeTo(), address(0xabc));
    }

    function testFailSetFeeToByUnauthorized() public {
        factory.setFeeTo(address(0xabc)); // Should fail because msg.sender is not feeToSetter
    }

    function testSetFeeToSetter() public {
        vm.prank(feeToSetter);
        factory.setFeeToSetter(address(0xdef));
        assertEq(factory.feeToSetter(), address(0xdef));
    }

    function testFailSetFeeToSetterByUnauthorized() public {
        factory.setFeeToSetter(address(0xdef)); // Should fail
    }

    function testCreatePair() public {
        address pair = factory.createPair(tokenA, tokenB);
        assertEq(factory.getPair(tokenA, tokenB), pair);
        assertEq(factory.getPair(tokenB, tokenA), pair);
        assertEq(factory.allPairsLength(), 1);
    }

    function testFailCreatePairWithSameToken() public {
        factory.createPair(tokenA, tokenA); // Should fail due to identical addresses
    }

    function testFailCreatePairWithZeroAddress() public {
        factory.createPair(address(0), tokenB); // Should fail due to zero address
    }

    function testFailCreatePairIfAlreadyExists() public {
        factory.createPair(tokenA, tokenB);
        factory.createPair(tokenA, tokenB); // Should fail as pair already exists
    }
}

