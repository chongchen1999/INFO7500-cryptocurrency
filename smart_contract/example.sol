// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BasicToken
 * @dev Implementation of a basic ERC20-like token
 */
contract BasicToken {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    address public owner;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "BasicToken: caller is not the owner");
        _;
    }
    
    /**
     * @dev Constructor that gives the msg.sender all existing tokens.
     */
    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 initialSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
        
        // Calculate the initial supply with decimals
        uint256 supply = initialSupply * (10 ** uint256(decimals));
        
        // Mint initial tokens to contract creator
        _mint(msg.sender, supply);
    }
    
    /**
     * @dev Gets the balance of the specified address.
     * @param account The address to query the balance of.
     * @return A uint256 representing the balance.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev Transfer token for a specified address.
     * @param to The recipient address.
     * @param amount The amount to send.
     * @return A boolean that indicates if the operation was successful.
     */
    function transfer(address to, uint256 amount) public returns (bool) {
        require(to != address(0), "BasicToken: transfer to the zero address");
        require(_balances[msg.sender] >= amount, "BasicToken: transfer amount exceeds balance");
        
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * @param spender The address which will spend the funds.
     * @param amount The amount of tokens to be spent.
     * @return A boolean that indicates if the operation was successful.
     */
    function approve(address spender, uint256 amount) public returns (bool) {
        require(spender != address(0), "BasicToken: approve to the zero address");
        
        _allowances[msg.sender][spender] = amount;
        
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    /**
     * @dev Returns the remaining number of tokens that spender will be allowed to spend on behalf of owner.
     * @param owner The address which owns the funds.
     * @param spender The address which will spend the funds.
     * @return A uint256 specifying the remaining amount of tokens.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }
    
    /**
     * @dev Transfer tokens from one address to another.
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param amount The amount to transfer.
     * @return A boolean that indicates if the operation was successful.
     */
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(from != address(0), "BasicToken: transfer from the zero address");
        require(to != address(0), "BasicToken: transfer to the zero address");
        require(_balances[from] >= amount, "BasicToken: transfer amount exceeds balance");
        require(_allowances[from][msg.sender] >= amount, "BasicToken: insufficient allowance");
        
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    /**
     * @dev Creates tokens and assigns them to the specified account.
     * @param to The account that will receive the created tokens.
     * @param amount The amount of tokens to create.
     */
    function mint(address to, uint256 amount) public onlyOwner returns (bool) {
        _mint(to, amount);
        return true;
    }
    
    /**
     * @dev Internal function to mint tokens.
     * @param to The account that will receive the created tokens.
     * @param amount The amount of tokens to create.
     */
    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "BasicToken: mint to the zero address");
        
        totalSupply += amount;
        _balances[to] += amount;
        
        emit Transfer(address(0), to, amount);
        emit Mint(to, amount);
    }
    
    /**
     * @dev Destroys tokens from the caller's account.
     * @param amount The amount of tokens to destroy.
     */
    function burn(uint256 amount) public returns (bool) {
        _burn(msg.sender, amount);
        return true;
    }
    
    /**
     * @dev Destroys tokens from a specified account.
     * @param from The account from which tokens will be burned.
     * @param amount The amount of tokens to burn.
     */
    function burnFrom(address from, uint256 amount) public returns (bool) {
        require(_allowances[from][msg.sender] >= amount, "BasicToken: insufficient allowance");
        
        _allowances[from][msg.sender] -= amount;
        _burn(from, amount);
        
        return true;
    }
    
    /**
     * @dev Internal function to burn tokens.
     * @param from The account from which tokens will be burned.
     * @param amount The amount of tokens to burn.
     */
    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "BasicToken: burn from the zero address");
        require(_balances[from] >= amount, "BasicToken: burn amount exceeds balance");
        
        _balances[from] -= amount;
        totalSupply -= amount;
        
        emit Transfer(from, address(0), amount);
        emit Burn(from, amount);
    }
    
    /**
     * @dev Transfers ownership of the contract to a new account.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "BasicToken: new owner is the zero address");
        owner = newOwner;
    }
}