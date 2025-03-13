// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import 'src/core/interfaces/IERC20.sol';

contract FeeOnTransferToken is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint public totalSupply;
    uint public fee = 100; // Fee is denominated in basis points (1% = 100)
    
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    address public owner;
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
    }
    
    function setFee(uint _fee) external {
        require(msg.sender == owner, 'Not owner');
        fee = _fee;
    }
    
    function mint(address to, uint amount) external {
        require(msg.sender == owner, 'Not owner');
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function approve(address spender, uint amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transfer(address to, uint amount) external override returns (bool) {
        uint feeAmount = (amount * fee) / 10000;
        uint transferAmount = amount - feeAmount;
        
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += transferAmount;
        
        // Fee goes to contract owner
        if (feeAmount > 0) {
            balanceOf[owner] += feeAmount;
            emit Transfer(msg.sender, owner, feeAmount);
        }
        
        emit Transfer(msg.sender, to, transferAmount);
        return true;
    }
    
    function transferFrom(address from, address to, uint amount) external override returns (bool) {
        require(allowance[from][msg.sender] >= amount, 'Insufficient allowance');
        
        if (amount != type(uint).max) {
            allowance[from][msg.sender] -= amount;
        }
        
        uint feeAmount = (amount * fee) / 10000;
        uint transferAmount = amount - feeAmount;
        
        balanceOf[from] -= amount;
        balanceOf[to] += transferAmount;
        
        // Fee goes to contract owner
        if (feeAmount > 0) {
            balanceOf[owner] += feeAmount;
            emit Transfer(from, owner, feeAmount);
        }
        
        emit Transfer(from, to, transferAmount);
        return true;
    }
}