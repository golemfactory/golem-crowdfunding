pragma solidity ^0.4.1;

contract MigrationAgent {
    function migrateFrom(address _from, uint256 _value);
}

contract GolemNetworkToken {
    string public constant name = "Golem Network Token";
    uint8 public constant decimals = 10^18; // TODO: SET before THE CROWDSALE!
    string public constant symbol = "GNT";

    // TODO: SET these PARAMS before THE CROWDSALE!
    uint256 constant percentTokensForFounder = 12;
    uint256 constant percentTokensForDevelopers = 6;
    uint256 constant tokenCreationRate = 1000;
    
    // The funding cap in wei.
    uint256 constant fundingMax = 847457627118644067796611 * tokenCreationRate;

    uint256 fundingStartBlock;
    uint256 fundingEndBlock;
 
    address public founder;  
    address public devAddress;  //Address 
    
    uint256 totalTokens;
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;

    address public migrationAgent;
    uint256 public totalMigrated;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Migrate(address indexed _from, address indexed _to, uint256 _value);

    function GolemNetworkToken(address _founder, address _devAddress, uint256 _fundingStartBlock,
                               uint256 _fundingEndBlock) {
        founder = _founder;
        devAddress = _devAddress;
        fundingStartBlock = _fundingStartBlock;
        fundingEndBlock = _fundingEndBlock;
    }

    // ERC20 Token Interface:
    
    function transfer(address _to, uint256 _value) returns (bool success) {
        if (transferEnabled() && balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        }
        return false;
    }

    function transferFrom(address _from, address _to, uint256 _value)
            returns (bool success) {
        if (transferEnabled() && balances[_from] >= _value &&
                allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
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

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    // Token migration support:

    function migrationEnabled() constant returns (bool) {
        return migrationAgent != 0;
    }

    function migrate(uint256 _value) {
        if (!migrationEnabled()) throw;
        if (!transferEnabled()) throw;
        if (balances[msg.sender] < _value) throw;
        if (_value == 0) throw;

        balances[msg.sender] -= _value;
        totalTokens -= _value;
        totalMigrated += _value;
        MigrationAgent(migrationAgent).migrateFrom(msg.sender, _value);
        Migrate(msg.sender, migrationAgent, _value);
    }

    function setMigrationAgent(address _agent) external {
        if (msg.sender != founder) throw;
        if (migrationEnabled()) throw;  // Do not allow changing the importer.
        migrationAgent = _agent;
    }

    // Crowdfunding:

    // Helper function to check if the funding has ended. It also handles the
    // case where `fundingEnd` has been zerod.
    function fundingHasEnded() constant returns (bool) {
        if (block.number > fundingEndBlock)
            return true;

        // The funding is ended also if the cap is reached.
        return totalTokens == fundingMax;
    }

    function fundingFinalized() constant returns (bool) {
        return fundingEndBlock == 0;
    }

    // Are we in the funding period?
    function fundingOngoing() constant returns (bool) {
        if (fundingHasEnded())
            return false;
        return block.number >= fundingStartBlock;
    }

    function transferEnabled() constant returns (bool) {
        return fundingHasEnded();
    }

    // Helper function to get number of tokens left during the funding.
    // This is also a public function to allow better Dapps integration.
    function numberOfTokensLeft() constant returns (uint256) {
        return fundingMax - totalTokens;
    }

    function changeFounder(address _newFounder) external {
        // TODO: Sort function by importance.
        if (msg.sender == founder)
            founder = _newFounder;
    }

    // If during the funding period, generate tokens for incoming ethers and finalize funding in case, cap was reached.
    // After the funding period - finalize funding
    function() payable external {
        if (fundingFinalized()) throw;

        if (fundingHasEnded()) {
            // Do not allow any eth transfer in this case
            if(msg.value > 0) throw;
            
            // Finalize funding in case the cap was not reached but the funding has ended
            finalizeFunding();
        }
        else {
            // Only in funding period.
            if (!fundingOngoing()) throw;

            var numTokens = msg.value * tokenCreationRate;
            if (numTokens == 0) throw;

            // Do not allow generating more than the cap.
            // UI should known that and propose available number of tokens,
            // but still it is a race condition.
            // Alternatively, we can generate up the cap and return the left ether
            // to the sender. But calling unknown addresses is a sequrity risk.
            if (numTokens > numberOfTokensLeft()) throw;

            // Assigne new tokens to the sender
            balances[msg.sender] += numTokens;
            totalTokens += numTokens;
            // Notify about the token generation with a transfer event from 0 address.
            Transfer(0, msg.sender, numTokens);
            
            if (0 == numberOfTokensLeft()) {
                // Cap reached - finalize funding
                finalizeFunding();                
            }
        }
    }

    function finalizeFunding() private {
        // Transfer ETH to the founder address
        if (!founder.send(this.balance)) throw;
        
        // Generate additional tokens for the Founder and the developers.
        var additionalTokens = totalTokens * (percentTokensForFounder + percentTokensForDevelopers) / (100 - percentTokensForFounder - percentTokensForDevelopers);
        
        var tokensForFounder   = additionalTokens * percentTokensForFounder / (percentTokensForFounder + percentTokensForDevelopers);
        var tokensForDevelpers = additionalTokens - tokensForFounder;
 
        balances[founder] += tokensForFounder;
        balances[devAddress] += tokensForDevelpers;
        
        totalTokens += additionalTokens;

        // Cleanup. Remove all data not needed any more.
        // Also zero the founder address to indicate that funding has been
        // finalized.
        fundingStartBlock = 0;
        fundingEndBlock = 0;    
    }
}
