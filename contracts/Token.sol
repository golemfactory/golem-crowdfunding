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
    event Export(address indexed _from, address indexed _to, uint256 _value);
}

contract TokenImporter {
    function importTokens(address _from, uint256 _value);
}

contract GolemNetworkToken is ERC20TokenInterface {
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

    uint256 numTokens;
    uint256 public totalExported;
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;

    address public importer;
    mapping (address => uint256) exports;

    function GolemNetworkToken(address _founder, uint256 _fundingStart,
                               uint256 _fundingEnd) {
        founder = _founder;
        fundingStart = _fundingStart;
        fundingEnd = _fundingEnd;
    }

    function transfer(address _to, uint256 _value) returns (bool success) {
        if (isTransferable() && balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        }
        return false;
    }

    function export(uint256 _value) {
        if (!isExportable()) throw;
        if (!isTransferable()) throw;
        if (balances[msg.sender] < _value) throw;
        if (_value == 0) throw;

        balances[msg.sender] -= _value;
        exports[importer] += _value;
        numTokens -= _value;
        totalExported += _value;
        TokenImporter(importer).importTokens(msg.sender, _value);
        Export(msg.sender, importer, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value)
            returns (bool success) {
        if (isTransferable() && balances[_from] >= _value &&
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
        return numTokens;
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

    // Helper function to check if the funding has ended. It also handles the
    // case where `fundingEnd` has been zerod.
    function fundingHasEnded() constant returns (bool) {
        if (block.number > fundingEnd)
            return true;

        // The funding is ended also if the cap is reached.
        return numTokens == fundingMax;
    }

    function fundingFinalized() constant returns (bool) {
        return fundingEnd == 0;
    }

    // Are we in the funding period?
    function fundingOngoing() constant returns (bool) {
        if (fundingHasEnded())
            return false;
        return block.number >= fundingStart;
    }

    function isTransferable() constant returns (bool) {
        return fundingHasEnded();
    }

    function isExportable() constant returns (bool) {
        return importer != 0;
    }

    // Helper function to get number of tokens left during the funding.
    // This is also a public function to allow better Dapps integration.
    function numberOfTokensLeft() constant returns (uint256) {
        return fundingMax - numTokens;
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
        balances[msg.sender] += numTokens;
        numTokens += numTokens;
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
        var additionalTokens = numTokens * percentTokensForFounder / (100 - percentTokensForFounder);
        balances[founder] += additionalTokens;
        numTokens += additionalTokens;

        // Cleanup. Remove all data not needed any more.
        // Also zero the founder address to indicate that funding has been
        // finalized.
        fundingStart = 0;
        fundingEnd = 0;
    }

    function setImporter(address _importer) external {
        if (msg.sender != founder) throw;
        if (isExportable()) throw;  // Do not allow changing the importer.
        importer = _importer;
    }
}
