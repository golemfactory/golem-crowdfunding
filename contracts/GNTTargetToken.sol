pragma solidity ^0.4.4;

contract GNTTargetToken {

    address migrationAgent;

    // ERC20 variables
    uint256 totalTokens;
    mapping (address => uint256) balances;

    // ERC20 events
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    function GNTTargetToken(address _migrationAgent) {
        migrationAgent = _migrationAgent;
        //Additional constructor code gets here
    }

    // Migration related methods
    function createToken(address _target, uint256 _amount) {
        if (msg.sender != migrationAgent) throw;

        balances[_target] += _amount;
        totalTokens += _amount;

        Transfer(migrationAgent, _target, _amount);
    }

    function finalizeMigration() {
        if (msg.sender != migrationAgent) throw;

        migrationAgent = 0;
    }

    // ERC20 interface (implemented according to the requirements)
    function transfer(address _to, uint256 _value) returns (bool success) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        }
        return false;
    }

    function totalSupply() constant returns (uint256) {
        return totalTokens;
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }
}
