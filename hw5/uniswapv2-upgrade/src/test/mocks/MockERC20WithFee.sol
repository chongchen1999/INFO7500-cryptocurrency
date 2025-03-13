// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "src/core/interfaces/IERC20.sol";

contract MockERC20WithFee is IERC20 {
    string public constant name = "MockTokenWithFee";
    string public constant symbol = "MTF";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // 转账时收取1%的费用
    uint256 public constant feeRate = 100; // 1%
    address public feeRecipient;

    constructor(uint256 _initialSupply, address _feeRecipient) {
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply;
        feeRecipient = _feeRecipient;
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        uint256 fee = amount * feeRate / 10000;
        uint256 transferAmount = amount - fee;
        
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += transferAmount;
        balanceOf[feeRecipient] += fee;
        
        emit Transfer(msg.sender, recipient, transferAmount);
        emit Transfer(msg.sender, feeRecipient, fee);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        uint256 fee = amount * feeRate / 10000;
        uint256 transferAmount = amount - fee;
        
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += transferAmount;
        balanceOf[feeRecipient] += fee;
        
        emit Transfer(sender, recipient, transferAmount);
        emit Transfer(sender, feeRecipient, fee);
        return true;
    }
}