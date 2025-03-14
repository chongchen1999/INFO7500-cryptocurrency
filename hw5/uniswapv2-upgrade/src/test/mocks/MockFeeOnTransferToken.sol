// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "src/core/interfaces/IERC20.sol";

contract MockFeeOnTransferToken is IERC20 {
    string private constant _name = "Mock Fee Token";
    string private constant _symbol = "MFT";
    uint8 private constant _decimals = 18;
    
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public transferFee = 10; // 1% fee

    constructor(uint256 initialSupply) {
        _totalSupply = initialSupply;
        _balances[msg.sender] = initialSupply;
    }

    function name() external pure override returns (string memory) {
        return _name;
    }

    function symbol() external pure override returns (string memory) {
        return _symbol;
    }

    function decimals() external pure override returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        address owner = msg.sender;
        uint256 fee = (amount * transferFee) / FEE_DENOMINATOR;
        uint256 actualAmount = amount - fee;
        
        _balances[owner] -= amount;
        _balances[to] += actualAmount;
        _totalSupply -= fee; // Burn the fee

        emit Transfer(owner, to, actualAmount);
        if (fee > 0) {
            emit Transfer(owner, address(0), fee);
        }
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        require(_allowances[from][msg.sender] >= amount, "ERC20: insufficient allowance");
        
        _allowances[from][msg.sender] -= amount;
        
        uint256 fee = (amount * transferFee) / FEE_DENOMINATOR;
        uint256 actualAmount = amount - fee;
        
        _balances[from] -= amount;
        _balances[to] += actualAmount;
        _totalSupply -= fee; // Burn the fee

        emit Transfer(from, to, actualAmount);
        if (fee > 0) {
            emit Transfer(from, address(0), fee);
        }
        return true;
    }
}