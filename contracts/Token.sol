pragma solidity ^0.4.1;

// Abstract contract for the full ERC 20 Token standard
// https://github.com/ethereum/EIPs/issues/20

contract ERC20TokenInterface {
    /// total amount of tokens
    function totalSupply() constant returns (uint256);

    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address _owner) constant returns (uint256 balance);

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _value) returns (bool success);

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);

    /// @notice `msg.sender` approves `_addr` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of wei to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address _spender, uint256 _value) returns (bool success);

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
    function allowance(address _owner, address _spender) constant returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract BalanceDB {
    address owner;
    address controller; // TODO: We can merge owner and controller.
    uint256 public total;
    mapping (address => uint256) balances;

    function BalanceDB(address _owner, address _controller) {
        owner = _owner;
        controller = _controller;
    }

    function balanceOf(address _addr) constant returns (uint256) {
        return balances[_addr];
    }

    function addBalance(address _addr, uint256 _value) {
        if (msg.sender != controller) throw;
        balances[_addr] += _value;
        total += _value;
    }

    function changeController(address _newController) {
        // FIXME: We have to decide how to report failures.
        if (msg.sender == owner)
            controller = _newController;
    }

    function changeOwner(address _newOwner) {
        if (msg.sender == owner)
            owner = _newOwner;
    }
}

contract StandardToken is ERC20TokenInterface {
    BalanceDB db;

    mapping (address => mapping (address => uint256)) allowed;

    function StandardToken(address _db) {
        // TODO: It would be cheaper if the db address is a constant.
        db = BalanceDB(_db);
    }

    function totalSupply() constant returns (uint256) {
        return db.total();
    }

    function transfer(address _to, uint256 _value) returns (bool success) {
        if (db.balanceOf(msg.sender) >= _value && _value > 0) {
            // TODO: Make sure the calls cause a throw in case of OOG.
            db.addBalance(msg.sender, -_value);
            db.addBalance(_to, _value);
            Transfer(msg.sender, _to, _value);
            return true;
        }
        return false;
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        if (db.balanceOf(_from) >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            db.addBalance(msg.sender, -_value);
            db.addBalance(_to, _value);
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        }
        return false;
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return db.balanceOf(_owner);
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}

contract GolemNetworkToken is StandardToken {
    string public standard = 'Token 0.1'; // TODO: I think we should remove it.

    string public constant name = "Golem Network Token";
    uint8 public constant decimals = 10^18; // TODO
    string public constant symbol = "GNT";

    uint256 constant percentTokensForFounder = 18;
    uint256 constant tokensPerWei = 1;
    uint256 constant fundingMax = 847457627118644067796611 * tokensPerWei;
    uint256 fundingStart;
    uint256 fundingEnd;
    address founder;

    function GolemNetworkToken(address _db, address _founder, uint256 _fundingStart,
                               uint256 _fundingEnd) StandardToken(_db) {
        founder = _founder;
        fundingStart = _fundingStart;
        fundingEnd = _fundingEnd;
    }

    // Helper function to check if the funding has ended. It also handles the
    // case where `fundingEnd` has been zerod.
    function fundingHasEnded() constant returns (bool) {
        if (block.number > fundingEnd)
            return true;

        // The funding is ended also if the cap is reached.
        return totalSupply() == fundingMax;
    }

    // Are we in the funding period?
    function fundingOngoing() constant returns (bool) {
        if (fundingHasEnded())
            return false;
        return block.number >= fundingStart;
    }

    // Helper function to get number of tokens left during the funding.
    // This is also a public function to allow better Dapps integration.
    function numberOfTokensLeft() constant returns (uint256) {
        return fundingMax - totalSupply();
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

        var numTokens = msg.value * tokensPerWei;
        if (numTokens == 0) throw;

        // Do not allow generating more than the cap.
        // UI should known that and propose available number of tokens,
        // but still it is a race condition.
        // Alternatively, we can generate up the cap and return the left ether
        // to the sender. But calling unknown addresses is a sequrity risk.
        if (numTokens > numberOfTokensLeft()) throw;

        // Assigne new tokens to the sender
        db.addBalance(msg.sender, numTokens);
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
        if (fundingEnd == 0) throw;
        if (msg.sender != founder) throw;
        if (!fundingHasEnded()) throw;

        // Generate additional tokens for the Founder.
        var additionalTokens = totalSupply() * percentTokensForFounder / (100 - percentTokensForFounder);
        db.addBalance(founder, additionalTokens);

        // Cleanup. Remove all data not needed any more.
        // Also zero the founder address to indicate that funding has been
        // finalized.
        fundingStart = 0;
        fundingEnd = 0;
    }
}
