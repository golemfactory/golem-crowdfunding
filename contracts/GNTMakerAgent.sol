import "TokenDB.sol";

contract GolemNetworkTokenCreator {    
    /// Assumptions of this code:
    // * This is deployed close to start block: then we don't need API for hasStarted() (throw is sufficient)
    // * TokenDB is deployed ahead of time
    // TODO:
    // * ensure gas availability for default function
    // * ensure gas availability for finalize
    // * ensure against max-recursion depth for finalize

    string public constant name = "Golem Network Token Creator";
    string public constant solidityVersion = "xxxxxxxx";

    // Immutable token creation parameters
    TokenDB tokenDB;
    uint256 constant tokensPerWei = 1000; // TODO: Parameter
    uint256 constant maxTokens = 1000000 * tokensPerWei * 1000000000000000000; // TODO: Parameter
    uint256 constant start = 2521252; // TODO: Parameter
    uint256 constant end = 2558252; // TODO: Parameter

    // Immutable token finalization parameters
    address developerETHAddress = 0xFF; // 0xDEVELOPERETHER
    address developerGNTAddress = 0xFF; // 0xDEVELOPERGNT

    // Mutable token creation values
    uint256 public tokensCreated;
    bool finalized = false;
    
    // Events
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    function finished() constant returns (bool) {
        if (finalized == true || block.number > end || tokensCreated == maxTokens)
            return true;
        return false;
    }

    function tokensRemaining() constant returns (uint256) {
        return maxTokens - tokensCreated;
    }

    // If past start block, create tokens from ether.
    function() external {
        if (msg.value == 0 || finished() || block.number < start)
            throw;
    
        uint256 numTokens = msg.value * tokensPerWei;
        if (numTokens > tokensRemaining()) throw;

        if(!tokenDB.create(msg.sender, numTokens)) throw;
        tokensCreated += numTokens;

        // Notify about token creation
        Transfer(0, msg.sender, numTokens);
    }

    function finalize() external {
        if (!finalized && finished() && msg.sender == developerGNTAddress)
        {
            // Generate additional tokens
            var tokens = tokensCreated * 120 / 880;
            if(!tokenDB.create(developerGNTAddress, tokens)) throw;
            tokensCreated += tokens;

            // Set finalized state
            finalized = true;
        }
        
        if (finalized && msg.sender == developerETHAddress)
        {
            suicide(developerETHAddress);
            // OR! developerETHAddress.send(this.balance)
        }
    }
    
    function setDeveloperETHAddress(address _address) external {
        if (msg.sender == developerETHAddress)
            developerETHAddress = _address;
    }
    
    function setDeveloperGNTAddress(address _address) external {
        if (msg.sender == developerGNTAddress)
            developerGNTAddress = _address;
    }
}