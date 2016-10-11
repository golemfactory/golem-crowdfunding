pragma solidity ^0.4.1;

contract GNTTargetToken {

    address migrationAgent;

    // ERC20 variables
    uint256 totalTokens;
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;

    // ERC20 events
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function GNTTargetToken(address _migrationAgent) {
        migrationAgent = _migrationAgent;
        //Additional constructor code gets here
    }

    // Migration related methods
    function createToken(address _target, uint256 _amount) {
        if (msg.sender != migrationAgent) throw;

        balances[_target] += _amount;
        totalSupply += _amount;

        Transfer(migrationAgent, _target, _amount);
    }

    function finalizeMigration() {
        if (msg.sender != migrationAgent) throw;

        migrationAgent = 0;
    }

    // ERC20 interface (implemented according to the requirements)
    function transfer(address _to, uint256 _value) returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value);
    function totalSupply() constant returns (uint256);
    function balanceOf(address _owner) constant returns (uint256 balance);
    function approve(address _spender, uint256 _value) returns (bool success);
    function allowance(address _owner, address _spender) constant returns (uint256 remaining);

}

//Test the whole process against this: https://www.kingoftheether.com/contract-safety-checklist.html
contract MigrationAgent {

    address owner;
    address gntSourceToken;
    address gntTargetToken;
    
    uint256 tokenSupply;
    
    function MigrationAgent(address _gntSourceToken) {
        owner = msg.sender;
        gntSourceToken = _gntSourceToken;
         
        tokenSupply = GolemNetworkToken(gntSourceToken).totalSupply();
    }

    function safetyInvariantCheck(uint256 _value) private {
        if (gntTargetToken == 0) throw;
        if (GolemNetworkToken(gntSourceToken).totalSupply() + GNTTargetToken(gntTargetToken).totalSupply() != tokenSupply - _value) throw;
    }
    
    function setTargetToken(address _gntTargetToken) {
        if (msg.sender != owner) throw;
        if (gntTargetToken != 0) throw; //Allow this change once only
        
        gntTargetToken = _gntTargetToken;
    }
    
    //Interface implementation
    function migrateFrom(address _from, uint256 _value) {
        if (msg.sender != gntSourceToken) throw;
        if (gntTargetToken == 0) throw;

        //Right here gntSourceToken has already been updated, but corresponding GNT have not been created in the gntTargetToken contract yet
        safetInvariantCheck(_value);

        GNTTargetToken(gntTargetToken).createToken(_from, _value);
    
        //Right here totalSupply invariant must hold
        safetInvariantCheck(0);
    }

    function finalizeMigration() {
        if (msg.sender != owner) throw;
        
        safetyInvariantCheck(0);
        
        //Additional, strict test
        //if (gntSourceToken.totalSupply() > 0) throw;
        
        GNTTargetToken(gntTargetToken).finalizeMigration();

        gntSourceToken = 0;
        gntTargetToken = 0;
 
        tokenSupply = 0;
    }

}
