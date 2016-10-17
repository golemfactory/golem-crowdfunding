pragma solidity ^0.4.1;

contract MigrationAgent {
    function migrateFrom(address _from, uint256 _value);
}

contract GolemNetworkToken {
    string public constant name = "Golem Network Token";
    string public constant symbol = "GNT";
    uint8 public constant decimals = 18;  // 18 decimal places, the same as ETH.

    // TODO: SET these PARAMS before THE CROWDFUNDING!
    uint256 constant percentTokensForCrowdfundingAgent = 12;
    uint256 constant percentTokensForDevelopers = 6;
    uint256 constant tokenCreationRate = 1000;
    
    // The funding cap in wei.
    uint256 constant tokenCreationCap = 847457627118644067796611 * tokenCreationRate;

    uint256 fundingStartBlock;
    uint256 fundingEndBlock;
 
    address public crowdfundingAgent;  

    // TODO: SET before THE CROWDFUNDING!
    // Invariants:
    // dev0Percent + dev1Percent + dev2Percent + dev3Percent + dev4Percent + dev5Percent = 100
    // dev0Percent > 0 && dev1Percent > 0 && dev2Percent > 0 && dev3Percent > 0 && dev4Percent > 0 && dev5Percent > 0
    // FIXME: array based approach can be used instead, provided that it is safe to use this Solidity feature
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
    // uint256 public dev5Percent;  can be calculated as: 100 - dev0Percent - dev1Percent - dev2Percent - dev3Percent - dev4Percent
    
    uint256 totalTokens;
    mapping (address => uint256) balances;

    address public migrationAgent;
    uint256 public totalMigrated;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Migrate(address indexed _from, address indexed _to, uint256 _value);

    function GolemNetworkToken(address _crowdfundingAgent, uint256 _fundingStartBlock,
                               uint256 _fundingEndBlock) {
        crowdfundingAgent = _crowdfundingAgent;
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

    function totalSupply() constant returns (uint256) {
        return totalTokens;
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
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
        if (msg.sender != crowdfundingAgent) throw;
        if (migrationEnabled()) throw;  // Do not allow changing the importer.
        migrationAgent = _agent;
    }

    // Crowdfunding:

    // Helper function to check if the funding has ended. It also handles the
    // case where 'fundingEnd' has been zeroed.
    function fundingHasEnded() constant returns (bool) {
        return block.number > fundingEndBlock;
    }

    function fundingNotStarted() constant returns (bool) {
        return block.number < fundingStartBlock;
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
        if (fundingHasEnded())
            return 0;
        return tokenCreationCap - totalTokens;
    }
    
    function changeGolemAgent(address _newCrowdfundingAgent) external {
        // TODO: Sort function by importance.
        if (msg.sender == crowdfundingAgent)
            crowdfundingAgent = _newCrowdfundingAgent;
    }

    // If during the funding period, generate tokens for incoming ethers and finalize funding in case, cap was reached.
    // After the funding period - finalize funding
    function() payable external {
        // Only during the funding period.
        if (!fundingOngoing()) throw;

        var numTokens = msg.value * tokenCreationRate;
        if (numTokens == 0) throw;

        // Do not allow generating more than the cap.
        // UI should known that and propose available number of tokens,
        // but still it is a race condition.
        // Alternatively, we can generate up the cap and return the left ether
        // to the sender. But calling unknown addresses is a sequrity risk.
        if (numTokens > numberOfTokensLeft()) throw;

        // Assign new tokens to the sender
        balances[msg.sender] += numTokens;
        totalTokens += numTokens;
        // Notify about the token generation with a transfer event from 0 address.
        Transfer(0, msg.sender, numTokens);
    }

    // If cap was reached or crowdfunding has ended then:
    // Transfer ETH to the crowdfundingAgent address
    // Create GNT for the crowdfundingAgent (representing the company)
    // Create GNT for the developers
    // Update GNT state (number of tokens)
    // Set finalize flag to true (fundingEndBlock == 0)
    // FIXME: Any events to be added here?
    function finalizeFunding() external {
        if (fundingFinalized()) throw;
        if (fundingNotStarted()) throw;
        if (!fundingHasEnded() && numberOfTokensLeft() > 0) throw;
        
        // 1. Transfer ETH to the crowdfundingAgent address
        if (!crowdfundingAgent.send(this.balance)) throw;
        
        // 2. Create GNT for the crowdfundingAgent (representing the company)
        var numAdditionalTokens = totalTokens * (percentTokensForCrowdfundingAgent + percentTokensForDevelopers) / (100 - percentTokensForCrowdfundingAgent - percentTokensForDevelopers);
        var numTokensForGolemAgent = numAdditionalTokens * percentTokensForCrowdfundingAgent / (percentTokensForCrowdfundingAgent + percentTokensForDevelopers);

        balances[crowdfundingAgent] += numTokensForGolemAgent;

        // 3. Create GNT for the crowdfundingAgent (representing the company)
        var numTokensForDevelpers  = numAdditionalTokens - numTokensForGolemAgent;

        var dev0Tokens = dev0Percent * numTokensForDevelpers / 100;
        var dev1Tokens = dev1Percent * numTokensForDevelpers / 100;
        var dev2Tokens = dev2Percent * numTokensForDevelpers / 100;
        var dev3Tokens = dev3Percent * numTokensForDevelpers / 100;
        var dev4Tokens = dev4Percent * numTokensForDevelpers / 100;
        var dev5Tokens = numTokensForDevelpers - dev0Tokens - dev1Tokens - dev2Tokens - dev3Tokens - dev4Tokens;

        balances[dev0] += dev0Tokens;
        balances[dev1] += dev1Tokens;
        balances[dev2] += dev2Tokens;
        balances[dev3] += dev3Tokens;
        balances[dev4] += dev4Tokens;
        balances[dev5] += dev5Tokens;

        // 4. Update GNT state (number of tokens)
        totalTokens += numAdditionalTokens;

        // 5. Set finalize flag to true (fundingEndBlock == 0)
        // Cleanup. Remove all data not needed any more.
        // Also zero the crowdfundingAgent address to indicate that funding has been
        // finalized.
        fundingStartBlock = 0;
        fundingEndBlock = 0;    
    }    
}
