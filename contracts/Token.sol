pragma solidity ^0.4.1;

contract MigrationAgent {
    function migrateFrom(address _from, uint256 _value);
}

contract GolemNetworkToken {
    string public constant name = "Golem Network Token";
    string public constant symbol = "GNT";
    uint8 public constant decimals = 18;  // 18 decimal places, the same as ETH.

    // TODO: SET these PARAMS before THE CROWDFUNDING!
    uint256 constant percentTokensGolemFactory = 12;
    uint256 constant percentTokensDevelopers = 6;
    uint256 public constant tokenCreationRate = 1000;

    // The funding cap in wei.
    uint256 public constant tokenCreationCap = 820000 ether * tokenCreationRate;
    uint256 public constant tokenCreationMin =  150000 ether * tokenCreationRate;

    uint256 fundingStartBlock;
    uint256 fundingEndBlock;
    bool fundingComplete = false;
    bool public targetMinReached = false;
    bool public finalized = false;

    address public golemFactory;

    // TODO: SET before THE CROWDFUNDING!
    // Invariants:
    // dev0Percent + dev1Percent + dev2Percent + dev3Percent + dev4Percent + dev5Percent = 100
    // dev0Percent > 0 && dev1Percent > 0 && dev2Percent > 0 && dev3Percent > 0 && dev4Percent > 0 && dev5Percent > 0
    // FIXME: array based approach can be used instead, provided that it is safe to use this Solidity feature
    address public constant dev0 = 0xde00;
    uint256 public constant dev0Percent = 10;

    address public constant dev1 = 0xde01;
    uint256 public constant dev1Percent = 10;

    address public constant dev2 = 0xde02;
    uint256 public constant dev2Percent = 15;

    address public constant dev3 = 0xde03;
    uint256 public constant dev3Percent = 20;

    address public constant dev4 = 0xde04;
    uint256 public constant dev4Percent = 20;

    address public constant dev5 = 0xde05;
    // uint256 public dev5Percent;  can be calculated as: 100 - dev0Percent - dev1Percent - dev2Percent - dev3Percent - dev4Percent

    uint256 totalTokens;
    mapping (address => uint256) balances;

    address public migrationAgent;
    uint256 public totalMigrated;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Migrate(address indexed _from, address indexed _to, uint256 _value);

    function GolemNetworkToken(address _golemFactory, uint256 _fundingStartBlock,
                               uint256 _fundingEndBlock) {
        golemFactory = _golemFactory;
        fundingStartBlock = _fundingStartBlock;
        fundingEndBlock = _fundingEndBlock;
    }

    function transfer(address _to, uint256 _value) returns (bool success) {
        if (!transferEnabled()) return false;
        
        var senderBalance = balances[msg.sender];
        if (senderBalance >= _value && _value > 0) {
            senderBalance -= _value;
            balances[msg.sender] = senderBalance;
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

    function migrate(uint256 _value) {
        if (migrationAgent == 0) throw;
        if (_value == 0 || _value > balances[msg.sender]) throw;

        balances[msg.sender] -= _value;
        totalTokens -= _value;
        totalMigrated += _value;
        MigrationAgent(migrationAgent).migrateFrom(msg.sender, _value);
        Migrate(msg.sender, migrationAgent, _value);
    }

    function setMigrationAgent(address _agent) external {
        // Can't set agent if already set or funding isn't finalized
        if (msg.sender != golemFactory || migrationAgent != 0 || !finalized) throw;
        
        migrationAgent = _agent;
    }

    // Crowdfunding:

    function fundingActive() returns (bool) {
        // ensure false is returned if called after endblock
        if (block.number > fundingEndBlock)
            fundingComplete = true;
        return block.number >= fundingStartBlock && block.number <= fundingEndBlock && (!targetMinReached || !fundingComplete);
    }

    function transferEnabled() constant returns (bool) {
        return fundingComplete && targetMinReached;
    }
    
    // Helper function to get number of tokens left during the funding.
    function numberOfTokensLeft() constant returns (uint256) {
        if (totalTokens >= tokenCreationCap || !fundingActive())
            return 0;
        return tokenCreationCap - totalTokens;
    }

    function changeGolemFactory(address _golemFactory) external {
        if (finalized && msg.sender == golemFactory)
            golemFactory = _golemFactory;
    }

    // Create tokens when funding is active
    // Update state when funding period lapses and/or min/max funding occurs
    function() payable external {
        // half if funding has concluded or empty value is sent
        if (!fundingActive()) throw;
        if (msg.value == 0) throw;

        // Do not create more than cap
        var numTokens = msg.value * tokenCreationRate;
        if (numTokens > numberOfTokensLeft()) throw;

        // Assign new tokens to the sender
        balances[msg.sender] += numTokens;
        totalTokens += numTokens;
        
        if (totalTokens >= tokenCreationMin && !targetMinReached)
            targetMinReached = true;
        
        if (totalTokens >= tokenCreationCap)
            fundingComplete = true;
        
        // Log token creation event
        Transfer(0, msg.sender, numTokens);
    }

    // If cap was reached or crowdfunding has ended then:
    // Transfer ETH to the golemFactory address
    // Create GNT for the golemFactory (representing the company)
    // Create GNT for the developers
    // Update GNT state (number of tokens)
    function finalize() external {
        if (fundingActive() || block.number <= fundingEndBlock || finalized) throw;

        // 1. Transfer ETH to the golemFactory address
        if (!golemFactory.send(this.balance)) throw;

        // 2. Create GNT for the golemFactory (representing the company)
        var numAdditionalTokens = totalTokens * (percentTokensGolemFactory + percentTokensDevelopers) / (100 - percentTokensGolemFactory - percentTokensDevelopers);
        var numTokensForGolemAgent = numAdditionalTokens * percentTokensGolemFactory / (percentTokensGolemFactory + percentTokensDevelopers);

        balances[golemFactory] += numTokensForGolemAgent;

        // 3. Create GNT for the golemFactory (representing the company)
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

        finalized = true;
    }
    
    function refund() external {
        if (fundingActive() || transferEnabled()) throw;

        var gntValue = balances[msg.sender];
        if (gntValue == 0) throw;
        balances[msg.sender] = 0;
        totalTokens -= gntValue;
        
        var ethValue = gntValue / tokenCreationRate;
        if (!msg.sender.send(ethValue)) throw;   
    }
}
