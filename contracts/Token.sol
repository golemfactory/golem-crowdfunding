pragma solidity ^0.4.1;

contract MigrationAgent {
    function migrateFrom(address _from, uint256 _value);
}

contract GolemNetworkToken {
    string public constant name = "Golem Network Token";
    string public constant symbol = "GNT";
    uint8 public constant decimals = 18;  // 18 decimal places, the same as ETH.

    uint256 public constant tokenCreationRate = 1000;

    // The funding cap in weis.
    uint256 public constant tokenCreationCap = 820000 ether * tokenCreationRate;
    uint256 public constant tokenCreationMin = 150000 ether * tokenCreationRate;

    uint256 fundingStartBlock;
    uint256 fundingEndBlock;

    // The flag indicates if the GNT contract is in "funding" mode.
    bool fundingMode = true;

    address public golemFactory;

    // The currect total token supply.
    uint256 totalTokens;

    mapping (address => uint256) balances;

    address public migrationAgent;
    uint256 public totalMigrated;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Migrate(address indexed _from, address indexed _to, uint256 _value);
    event Refund(address indexed _from, uint256 _value);

    // Checks if in Funding Active state. Aborts transaction otherwise.
    modifier inFundingActive {
        if (!fundingMode) throw;
        // FundingActive: b ≥ Start and b ≤ End and t < Max
        if (block.number < fundingStartBlock ||
            block.number > fundingEndBlock ||
            totalTokens >= tokenCreationCap) throw;
        _;
    }

    // Checks if in Funding Failure state. Aborts transaction otherwise.
    modifier inFundingFailure {
        if (!fundingMode) throw;
        // FundingFailure: b > End and t < Min
        if (block.number <= fundingEndBlock ||
            totalTokens >= tokenCreationMin) throw;
        _;
    }

    // Checks if in Funding Success state. Aborts transaction otherwise.
    modifier inFundingSuccess {
        if (!fundingMode) throw;
        // FundingSuccess: (b > End and t ≥ Min) or t ≥ Max
        if ((block.number <= fundingEndBlock ||
             totalTokens < tokenCreationMin) &&
            totalTokens < tokenCreationCap) throw;
        _;
    }

    // Checks if in Operational state. Aborts transaction otherwise.
    modifier inOperational {
        if (fundingMode) throw;
        _;
    }

    // Checks if in Operational Normal state. Aborts transaction otherwise.
    modifier inNormal {
        if (fundingMode) throw;
        if (migrationAgent != 0) throw;
        _;
    }

    // Checks if in Operational Migration state. Aborts transaction otherwise.
    modifier inMigration {
        if (fundingMode) throw;
        if (migrationAgent == 0) throw;
        _;
    }

    function GolemNetworkToken(address _golemFactory,
                               uint256 _fundingStartBlock,
                               uint256 _fundingEndBlock) {
        golemFactory = _golemFactory;
        fundingStartBlock = _fundingStartBlock;
        fundingEndBlock = _fundingEndBlock;
    }

    function transfer(address _to, uint256 _value) inOperational returns (bool) {
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

    function totalSupply() external constant returns (uint256) {
        return totalTokens;
    }

    function balanceOf(address _owner) external constant returns (uint256) {
        return balances[_owner];
    }

    // Token migration support:

    function migrate(uint256 _value) inMigration external {
        if (_value == 0 || _value > balances[msg.sender]) throw;

        balances[msg.sender] -= _value;
        totalTokens -= _value;
        totalMigrated += _value;
        MigrationAgent(migrationAgent).migrateFrom(msg.sender, _value);
        Migrate(msg.sender, migrationAgent, _value);
    }

    function setMigrationAgent(address _agent) inNormal external {
        if (msg.sender != golemFactory) throw;

        migrationAgent = _agent;
    }

    // Crowdfunding:

    function fundingActive() constant external returns (bool) {
        // Copy of inFundingActive.
        if (!fundingMode) return false;

        // b ≥ Start and b ≤ End and t < Max
        if (block.number < fundingStartBlock ||
            block.number > fundingEndBlock ||
            totalTokens >= tokenCreationCap) return false;
        return true;
    }

    // Helper function to get number of tokens left during the funding.
    function numberOfTokensLeft() constant external returns (uint256) {
        if (!fundingMode) return 0;
        if (block.number > fundingEndBlock) return 0;
        return tokenCreationCap - totalTokens;
    }

    function finalized() constant external returns (bool) {
        return !fundingMode;
    }

    function changeGolemFactory(address _golemFactory) inOperational external {
        if (msg.sender == golemFactory)
            golemFactory = _golemFactory;
    }

    // Create tokens when funding is active
    // Update state when funding period lapses and/or min/max funding occurs
    function() payable inFundingActive external {
        if (msg.value == 0) throw;

        // Do not create more than cap
        var numTokens = msg.value * tokenCreationRate;
        totalTokens += numTokens;
        if (totalTokens > tokenCreationCap) throw;

        // Assign new tokens to the sender
        balances[msg.sender] += numTokens;

        // Log token creation event
        Transfer(0, msg.sender, numTokens);
    }

    // If cap was reached or crowdfunding has ended then:
    // Transfer ETH to the golemFactory address
    // Create GNT for the golemFactory (representing the company)
    // Create GNT for the developers
    // Update GNT state (number of tokens)
    function finalize() inFundingSuccess external {
        // Switch to Operational state. This is the only place this can happen.
        fundingMode = false;

        // 1. Transfer ETH to the golemFactory address
        if (!golemFactory.send(this.balance)) throw;

        // Create additional GNT for the Factory (representing the company)
        // and developers.
        createAdditionalTokens();
    }

    function refund() inFundingFailure external {
        var gntValue = balances[msg.sender];
        if (gntValue == 0) throw;
        balances[msg.sender] = 0;
        totalTokens -= gntValue;

        var ethValue = gntValue / tokenCreationRate;
        if (!msg.sender.send(ethValue)) throw;
        Refund(msg.sender, ethValue);
    }

    struct Dev {
        address addr;
        uint share;
    }

    // Creates additional 12% of tokens for the Factory and 6% for developers.
    function createAdditionalTokens() internal {
        // this calculation could be moved to lockedAllocation function
        uint256 percentTokensLocked = 18;
        uint256 numLockedTokens = totalTokens * percentTokensLocked / (100 - percentTokensLocked);
        
        balances[lockedAllocation] += numLockedTokens;
        lockedAllocation.allocate(numLockedTokens);
        totalTokens += numLockedTokens;
    }
}
