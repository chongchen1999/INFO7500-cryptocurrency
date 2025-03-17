// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "lib/forge-std/src/Test.sol";
import "src/contracts/UniswapV2ERC20.sol"; // 假设合约在这个路径

contract UniswapV2ERC20Test is Test {
    UniswapV2ERC20 token;
    address wallet = address(1);
    address other = address(2);
    
    uint256 constant TOTAL_SUPPLY = 10000 * 10**18;
    uint256 constant TEST_AMOUNT = 10 * 10**18;
    
    function setUp() public {
        vm.startPrank(wallet);
        token = new UniswapV2ERC20();
        token.mint(wallet, TOTAL_SUPPLY);
        vm.stopPrank();
    }
    
    function testBasicProperties() public view {
        assertEq(token.name(), "Uniswap V2");
        assertEq(token.symbol(), "UNI-V2");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
        assertEq(token.balanceOf(wallet), TOTAL_SUPPLY);
        
        // 验证DOMAIN_SEPARATOR
        bytes32 expectedDomain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(token.name())),
                keccak256(bytes("1")),
                block.chainid,
                address(token)
            )
        );
        assertEq(token.DOMAIN_SEPARATOR(), expectedDomain);
        
        // 验证PERMIT_TYPEHASH
        bytes32 expectedTypehash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        assertEq(token.PERMIT_TYPEHASH(), expectedTypehash);
    }
    
    function testApprove() public {
        vm.startPrank(wallet);
        
        // 使用IUniswapV2ERC20接口中定义的事件，而不是合约中的事件
        // 这里需要直接使用事件签名，因为事件在原合约中被注释掉了
        vm.expectEmit(true, true, true, true);
        emit Approval(wallet, other, TEST_AMOUNT);
        token.approve(other, TEST_AMOUNT);
        
        assertEq(token.allowance(wallet, other), TEST_AMOUNT);
        vm.stopPrank();
    }
    
    function testTransfer() public {
        vm.startPrank(wallet);
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(wallet, other, TEST_AMOUNT);
        token.transfer(other, TEST_AMOUNT);
        
        assertEq(token.balanceOf(wallet), TOTAL_SUPPLY - TEST_AMOUNT);
        assertEq(token.balanceOf(other), TEST_AMOUNT);
        vm.stopPrank();
    }
    
    function testTransferFail() public {
        vm.startPrank(wallet);
        
        // 测试transfer失败 - 余额不足
        vm.expectRevert(stdError.arithmeticError);  // 使用standard error类型
        token.transfer(other, TOTAL_SUPPLY + 1);
        vm.stopPrank();
        
        vm.startPrank(other);
        // 测试从无余额账户转账
        vm.expectRevert(stdError.arithmeticError);  // 使用standard error类型
        token.transfer(wallet, 1);
        vm.stopPrank();
    }
    
    function testTransferFrom() public {
        vm.startPrank(wallet);
        
        // 授权other可以转账TEST_AMOUNT
        token.approve(other, TEST_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(other);
        // 测试transferFrom
        vm.expectEmit(true, true, true, true);
        emit Transfer(wallet, other, TEST_AMOUNT);
        token.transferFrom(wallet, other, TEST_AMOUNT);
        
        assertEq(token.allowance(wallet, other), 0);
        assertEq(token.balanceOf(wallet), TOTAL_SUPPLY - TEST_AMOUNT);
        assertEq(token.balanceOf(other), TEST_AMOUNT);
        vm.stopPrank();
    }
    
    function testTransferFromMax() public {
        vm.startPrank(wallet);
        
        // 授权other可以转账最大值
        token.approve(other, type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(other);
        // 测试使用最大授权额度transferFrom
        vm.expectEmit(true, true, true, true);
        emit Transfer(wallet, other, TEST_AMOUNT);
        token.transferFrom(wallet, other, TEST_AMOUNT);
        
        // 最大授权额度不应减少
        assertEq(token.allowance(wallet, other), type(uint256).max);
        assertEq(token.balanceOf(wallet), TOTAL_SUPPLY - TEST_AMOUNT);
        assertEq(token.balanceOf(other), TEST_AMOUNT);
        vm.stopPrank();
    }
    
    function testBurn() public {
        // 先给wallet一些token
        uint256 initialBalance = token.balanceOf(wallet);
        uint256 initialSupply = token.totalSupply();
        
        vm.startPrank(wallet);
        // 测试burn功能
        vm.expectEmit(true, true, true, true);
        emit Transfer(wallet, address(0), TEST_AMOUNT);
        token.burn(wallet, TEST_AMOUNT);
        
        // 验证余额和总供应量减少
        assertEq(token.balanceOf(wallet), initialBalance - TEST_AMOUNT);
        assertEq(token.totalSupply(), initialSupply - TEST_AMOUNT);
        vm.stopPrank();
    }
    
    function testBurnFail() public {
        // 测试burn失败 - 余额不足
        vm.startPrank(wallet);
        vm.expectRevert(stdError.arithmeticError);
        token.burn(wallet, TOTAL_SUPPLY + 1);
        vm.stopPrank();
        
        // 测试burn失败 - 从无余额账户burn
        vm.startPrank(other);
        vm.expectRevert(stdError.arithmeticError);
        token.burn(other, 1);
        vm.stopPrank();
    }
    
    function testUnauthorizedBurn() public {
        // 获取初始值
        uint256 initialWalletBalance = token.balanceOf(wallet);
        uint256 initialTotalSupply = token.totalSupply();
        
        // 测试任何人都可以burn其他账户的token - 这是合约的实际行为
        // 注意：这个测试确认了当前合约设计允许任何人从任何地址烧毁代币
        vm.prank(other);
        vm.expectEmit(true, true, true, true);
        emit Transfer(wallet, address(0), TEST_AMOUNT);
        token.burn(wallet, TEST_AMOUNT);
        
        // 验证wallet的余额和总供应量已减少
        assertEq(token.balanceOf(wallet), initialWalletBalance - TEST_AMOUNT);
        assertEq(token.totalSupply(), initialTotalSupply - TEST_AMOUNT);
    }
    
    function testPermit() public {
        uint256 privateKey = 0xA11CE; // 测试用私钥
        address owner = vm.addr(privateKey); // 从私钥派生地址
        
        // 先给owner一些token以便测试
        // 正确使用vm.store设置代币余额
        vm.store(
            address(token),
            keccak256(abi.encode(owner, uint256(0))), // balanceOf[owner]的存储位置
            bytes32(uint256(TOTAL_SUPPLY / 2))
        );
        
        // permit参数
        uint256 nonce = token.nonces(owner);
        uint256 deadline = type(uint256).max;
        
        // 构建permit数据
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypehash = token.PERMIT_TYPEHASH();
        
        bytes32 structHash = keccak256(
            abi.encode(
                permitTypehash,
                owner,
                other,
                TEST_AMOUNT,
                nonce,
                deadline
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );
        
        // 使用私钥生成签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        // 使用permit函数
        vm.expectEmit(true, true, true, true);
        emit Approval(owner, other, TEST_AMOUNT);
        token.permit(owner, other, TEST_AMOUNT, deadline, v, r, s);
        
        // 验证结果
        assertEq(token.allowance(owner, other), TEST_AMOUNT);
        assertEq(token.nonces(owner), 1);
    }
    
    // 直接在测试合约中定义事件，因为原合约中的事件被注释掉了
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
}