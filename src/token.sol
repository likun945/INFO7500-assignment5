// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract ERC20Fallback {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _initialSupply;
        balances[msg.sender] = _initialSupply;
    }

    fallback(bytes calldata data) external returns (bytes memory) {
        if (data.length == 0) {
            if (msg.data.length == 68) {
                address to;
                uint256 value;
                assembly {
                    to := calldataload(4)
                    value := calldataload(36)
                }
                require(to != address(0), "Invalid address");
                require(balances[msg.sender] >= value, "Insufficient balance");
                balances[msg.sender] -= value;
                balances[to] += value;
                emit Transfer(msg.sender, to, value);
            } else if (msg.data.length == 100) {
                address spender;
                uint256 amount;
                assembly {
                    spender := calldataload(4)
                    amount := calldataload(36)
                }
                allowances[msg.sender][spender] = amount;
                emit Approval(msg.sender, spender, amount);
            }
        }
        return data;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function balanceOf(address owner) internal view returns (uint256) {
        return balances[owner];
    }

    function transfer(address to, uint256 value) internal {
        require(to != address(0), "Invalid address");
        require(balances[msg.sender] >= value, "Insufficient balance");
        balances[msg.sender] -= value;
        balances[to] += value;
        emit Transfer(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint256 value) internal {
        require(to != address(0), "Invalid address");
        require(balances[from] >= value, "Insufficient balance");
        require(allowances[from][msg.sender] >= value, "Allowance exceeded");

        balances[from] -= value;
        balances[to] += value;
        allowances[from][msg.sender] -= value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 amount) internal {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
    }

    function allowance(address owner, address spender) internal view returns (uint256) {
        return allowances[owner][spender];
    }
}
