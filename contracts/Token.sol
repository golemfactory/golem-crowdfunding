pragma solidity ^0.4.1;

contract MigrationAgent {
    function migrateFrom(address _from, uint256 _value);
}

contract GolemNetworkToken {
    string public constant name = "Golem Network Token";
    string public constant symbol = "GNT";
    uint8 public constant decimals = 18;  // 18 decimal places, the same as ETH.

    // TODO: Set these params before crowfunding!
    uint256 constant percentTokensForFounder = 18;
    uint256 public constant tokenCreationRate = 1000;
    // The token creation cap without endowment.
    uint256 constant tokenCreationCap = 847457627118644067796611 * tokenCreationRate;

    uint256 fundingStartBlock;
    uint256 fundingEndBlock;

    address public founder;

    uint256 totalTokens;
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;

    address public migrationAgent;
    uint256 public totalMigrated;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Migrate(address indexed _from, address indexed _to, uint256 _value);

    function GolemNetworkToken(address _founder, uint256 _fundingStartBlock,
                               uint256 _fundingEndBlock) {
        founder = _founder;
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

        // The funding is ended also if the token creation cap is reached
        // (or overpassed in case of generation of endowment).
        return totalTokens >= tokenCreationCap;
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

    function changeFounder(address _newFounder) external {
        // TODO: Sort function by importance.
        if (msg.sender == founder)
            founder = _newFounder;
    }

    // If in the funding period, generate tokens for incoming ethers.
    function() payable external {
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
    }

    // Allow the Founder to transfer ethers from the funding to its account.
    // This can be done only after the funding has endned but multiple times
    // in case someone accedentially deposits any ether in the Token contract.
    function transferEtherToFounder() external {
        // Only after the funding has ended.
        if (msg.sender != founder) throw;
        if (!fundingHasEnded()) throw;

        if (!founder.send(this.balance)) throw;
    }

    // Finalize the funding period
    function finalizeFunding() external {
        if (fundingFinalized()) throw;
        if (msg.sender != founder) throw;
        if (!fundingHasEnded()) throw;

        // Generate additional tokens for the Founder.
        var additionalTokens = totalTokens * percentTokensForFounder / (100 - percentTokensForFounder);
        balances[founder] += additionalTokens;
        totalTokens += additionalTokens;

        // Cleanup. Remove all data not needed any more.
        // Also zero the founder address to indicate that funding has been
        // finalized.
        fundingStartBlock = 0;
        fundingEndBlock = 0;
    }
}
