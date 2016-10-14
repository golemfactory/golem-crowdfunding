pragma solidity ^0.4.1;

contract MigrationAgent {
    function migrateFrom(address _from, uint256 _value);
}

contract GolemNetworkToken {
    string public constant name = "Golem Network Token";
    uint8 public constant decimals = 18; // TODO: SET before THE CROWDSALE!
    string public constant symbol = "GNT";

    // TODO: SET these PARAMS before THE CROWDSALE!
    uint256 constant percentTokensForFounder = 12;
    uint256 constant percentTokensForDevelopers = 6;
    uint256 constant tokenCreationRate = 1000;
    
    // The funding cap in wei.
    uint256 constant fundingMax = 847457627118644067796611 * tokenCreationRate;

    uint256 fundingStartBlock;
    uint256 fundingEndBlock;
 
    address public golemAgent;  

    // These addresses must be known before the contract is deployed
    // TODO: SET before THE CROWDSALE!
    // Invariant:
    // dev0Percent + dev1Percent + dev2Percent + dev3Percent + dev4Percent + dev5Percent = 100
    // dev0Percent > 0 && dev1Percent > 0 && dev2Percent > 0 && dev3Percent > 0 && dev4Percent > 0 && dev5Percent > 0
    // FIXME: array based approach can be used instead, provided that it is safe to use this Solidity feature
    uint256 private numCreatedTokensForDevelopers;
    
    address public dev0;
    uint256 public dev0Percent;

    address public dev1;
    uint256 public dev1Percent;

    address public dev2;
    uint256 public dev2Percent;

    address public dev3;
    uint256 public dev3Percent;

    address public dev4;
    uint256 public dev4Percent;

    address public dev5;
    uint256 public dev5Percent;
    
    uint256 totalTokens;
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;

    address public migrationAgent;
    uint256 public totalMigrated;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Migrate(address indexed _from, address indexed _to, uint256 _value);

    function GolemNetworkToken(address _golemAgent, uint256 _fundingStartBlock,
                               uint256 _fundingEndBlock) {
        golemAgent = _golemAgent;
        fundingStartBlock = _fundingStartBlock;
        fundingEndBlock = _fundingEndBlock;
        
        // MAX_UINT (uninitialized state)
        numCreatedTokensForDevelopers = 2 ** 256 - 1;
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
        if (msg.sender != golemAgent) throw;
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

    function developersEndowmentFinalized() constant returns (bool) {
        return numCreatedTokensForDevelopers == 0;
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

    function changeGolemAgent(address _newGolemAgent) external {
        // TODO: Sort function by importance.
        if (msg.sender == golemAgent)
            golemAgent = _newGolemAgent;
    }

    // If during the funding period, generate tokens for incoming ethers and finalize funding in case, cap was reached.
    // After the funding period - finalize funding
    // FIXME: if we're going to leave the logic according to this design then I'd rather use enumeration to indicate the state of the contract (provided that it is implemented in a secure way in Solidity)
    function() payable external {
        if (developersEndowmentFinalized()) throw;

        if (fundingFinalized()) {
            // Do not allow any eth transfer in this case
            if(msg.value > 0) throw;

            finalizeDevelopersEndowment();
        }
        else {
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
    }

    // Transfers ETH to the golemAgent address
    // Creates GNT for the golemAgent (representing the company)
    // Allocates GNT for the developers (but the creation process is postponed)
    function finalizeFunding() private {
        // Transfer ETH to the golemAgent address
        if (!golemAgent.send(this.balance)) throw;
        
        // Generate additional tokens for the Founder and the developers.
        var additionalTokens = totalTokens * (percentTokensForFounder + percentTokensForDevelopers) / (100 - percentTokensForFounder - percentTokensForDevelopers);
        
        var tokensForGolemAgent = additionalTokens * percentTokensForFounder / (percentTokensForFounder + percentTokensForDevelopers);
        var tokensForDevelpers  = additionalTokens - tokensForGolemAgent;
 
        balances[golemAgent] += tokensForFounder;
        numCreatedTokensForDevelopers = tokensForDevelpers;
        
        totalTokens += additionalTokens;

        // Cleanup. Remove all data not needed any more.
        // Also zero the golemAgent address to indicate that funding has been
        // finalized.
        fundingStartBlock = 0;
        fundingEndBlock = 0;    
    }
    
    // Sets GNT for each specified developer according to the specified GNT distribution 
    function finalizeDevelopersEndowment() private {
        if (numCreatedTokensForDevelopers == 2**256 -1) throw; //Impossible state!!!

        var dev0Tokens = dev0Percent * numCreatedTokensForDevelopers / 100;
        var dev1Tokens = dev1Percent * numCreatedTokensForDevelopers / 100;
        var dev2Tokens = dev2Percent * numCreatedTokensForDevelopers / 100;
        var dev3Tokens = dev3Percent * numCreatedTokensForDevelopers / 100;
        var dev4Tokens = dev4Percent * numCreatedTokensForDevelopers / 100;
        var dev5Tokens = numCreatedTokensForDevelopers - dev0Tokens - dev1Tokens - dev2Tokens - dev3Tokens - dev4Tokens;

        balances[dev0] = dev0Tokens;
        balances[dev1] = dev1Tokens;
        balances[dev2] = dev2Tokens;
        balances[dev3] = dev3Tokens;
        balances[dev4] = dev4Tokens;
        balances[dev5] = dev5Tokens;

        // Indicate that this phase is also finished
        numCreatedTokensForDevelopers = 0;
    }
}
