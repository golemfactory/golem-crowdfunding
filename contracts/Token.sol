pragma solidity ^0.4.1;

// Abstract contract for the full ERC 20 Token standard
// https://github.com/ethereum/EIPs/issues/20

contract ERC20TokenInterface {
    /// total amount of tokens
    function totalSupply() constant returns (uint256 supply);

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
    address controller;
    mapping (address => uint256) balances;

    function balanceOf(address _addr) constant returns (uint256 balance) {
        return balances[_addr];
    }

    function setBalanceOf(address _addr, uint256 _value) {
        if (msg.sender == controller)
            balances[_addr] = _value;
    }

    function changeController(address _newController) {
        if (msg.sender == owner)
            controller = _newController;
    }

    function changeOwner(address _newOwner) {
        if (msg.sender == owner)
            owner = _newOwner;
    }
}

contract StandardToken is ERC20TokenInterface {
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;

    function transfer(address _to, uint256 _value) returns (bool success) {
        // FIXME: Should we lock the transfer during the funding period?

        //Default assumes totalSupply can't be over max (2^256 - 1).
        //If your token leaves out totalSupply and can issue more tokens as time goes on, you need to check if it doesn't wrap.
        //Replace the if with this one instead.
        //if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        } else { return false; }
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        //same as above. Replace this line with the following if you want to protect against wrapping uints.
        //if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        } else { return false; }
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
}

contract GolemNetworkToken is StandardToken {

    /*
    NOTE:
    The following variables are OPTIONAL vanities. One does not have to include them.
    They allow one to customise the token contract & in no way influences the core functionality.
    Some wallets/interfaces might not even bother to look at this information.
    */

    string public standard = 'Token 0.1';

    uint256 supply = 0;
    string public constant name = "Golem Network Token";
    uint8 public constant decimals = 10^18; // TODO
    string public constant symbol = "GNT";

    uint256 constant percentTokensForFounder = 18;
    uint256 constant tokensPerWei = 1;
    uint256 constant fundingMax = 847457627118644067796611 * tokensPerWei;
    uint256 fundingStart;
    uint256 fundingEnd;
    address founder;

    function GolemNetworkToken(address _founder, uint256 _fundingStart,
                               uint256 _fundingEnd) {
        founder = _founder;
        fundingStart = _fundingStart;
        fundingEnd = _fundingEnd;
    }

    function changeFounder(address _newFounder) external {
        // TODO: Sort function by importance.
        if (msg.sender == founder)
            founder = _newFounder;
    }

    function totalSupply() constant returns (uint256 supply) {
        return supply;
    }

    function generateTokens() external {
        // TODO: If no params we should move it to function().

        // Only in funding period.
        if (block.number < fundingStart) throw;
        if (block.number > fundingEnd) throw;

        var numTokens = msg.value * tokensPerWei;
        if (numTokens == 0) throw;

        // Do not allow generating more than the cap.
        // UI should known that and propose available number of tokens,
        // but still it is a race condition.
        // Alternatively, we can generate up the cap and return the left ether
        // to the sender. But calling unknown addresses is a sequrity risk.
        uint256 tokensLeft = fundingMax - supply;
        if (numTokens > tokensLeft) throw;

        // Assigne new tokens to the sender
        balances[msg.sender] += numTokens;
        supply += numTokens;
        // TODO: Add event?
    }

    function transferEtherToFounder() external {
        // Only after the funding has ended.
        if (msg.sender != founder) throw;
        if (block.number <= fundingEnd) throw;

        if (!founder.send(this.balance)) throw;
    }

    // Finalize the funding period
    function finalizeFunding() external {
        if (fundingEnd == 0) throw;
        if (msg.sender != founder) throw;
        if (block.number <= fundingEnd) throw;

        // Generate additional tokens for the Founder.
        var additionalTokens = supply * (100 + percentTokensForFounder) / 100;
        balances[founder] += additionalTokens;
        supply += additionalTokens;

        // Cleanup. Remove all data not needed any more.
        // Also zero the founder address to indicate that funding has been
        // finalized.
        fundingStart = 0;
        fundingEnd = 0;
    }
}
