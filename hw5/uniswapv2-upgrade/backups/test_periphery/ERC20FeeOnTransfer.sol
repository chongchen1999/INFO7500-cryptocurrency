// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "src/test/mocks/ERC20Mintable.sol";

contract ERC20FeeOnTransfer is ERC20Mintable {
    uint256 public feePercentage;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _feePercentage
    ) ERC20Mintable(_name, _symbol) {
        feePercentage = _feePercentage; // 如：10 表示 1% 手续费
    }

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

    function transferWithFee(address recipient, uint256 amount) public returns (bool) {
        uint256 fee = (amount * feePercentage) / 1000;
        uint256 sendAmount = amount - fee;
        _burn(msg.sender, fee);
        _transfer(msg.sender, recipient, sendAmount);
        return true;
    }
}