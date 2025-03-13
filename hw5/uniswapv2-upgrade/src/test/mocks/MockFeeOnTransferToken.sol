// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.28;

// import "src/core/interfaces/IERC20.sol";

// contract MockFeeOnTransferToken is IERC20 {
//     uint256 private _totalSupply;
//     mapping(address => uint256) private _balances;
//     mapping(address => mapping(address => uint256)) private _allowances;
    
//     uint256 public constant FEE_PERCENT = 5; // 5% fee on transfers

//     constructor() {
//         _totalSupply = 1000000 * 10**18; // 1M tokens
//         _balances[msg.sender] = _totalSupply;
//     }

//     function totalSupply() external view override returns (uint256) {
//         return _totalSupply;
//     }

//     function balanceOf(address account) external view override returns (uint256) {
//         return _balances[account];
//     }

//     function transfer(address to, uint256 amount) external override returns (bool) {
//         uint256 fee = (amount * FEE_PERCENT) / 100;
//         uint256 actualAmount = amount - fee;
        
//         _balances[msg.sender] -= amount;
//         _balances[to] += actualAmount;
//         // Fee is burned
//         _totalSupply -= fee;
        
//         emit Transfer(msg.sender, to, actualAmount);
//         return true;
//     }

//     function allowance(address owner, address spender) external view override returns (uint256) {
//         return _allowances[owner][spender];
//     }

//     function approve(address spender, uint256 amount) external override returns (bool) {
//         _allowances[msg.sender][spender] = amount;
//         emit Approval(msg.sender, spender, amount);
//         return true;
//     }

//     function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
//         require(_allowances[from][msg.sender] >= amount, "ERC20: insufficient allowance");
        
//         uint256 fee = (amount * FEE_PERCENT) / 100;
//         uint256 actualAmount = amount - fee;
        
//         _allowances[from][msg.sender] -= amount;
//         _balances[from] -= amount;
//         _balances[to] += actualAmount;
//         // Fee is burned
//         _totalSupply -= fee;
        
//         emit Transfer(from, to, actualAmount);
//         return true;
//     }
// }