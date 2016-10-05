pragma solidity ^0.4.1;

// Abstract contract for the full ERC 20 Token standard
// https://github.com/ethereum/EIPs/issues/20


contract ERC20TokenInterface {

    // FIXME: SingularityDTVtoken implements it slightly different
    // // This is not an abstract function, because solc won't recognize generated getter functions for public variables as functions
    // function totalSupply() constant returns (uint256 supply) {}
    
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

contract StandardToken is ERC20TokenInterface {

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    uint256 public totalSupply;
    
    function transfer(address _to, uint256 _value) returns (bool success) {
        //Default assumes totalSupply can't be over max (2^256 - 1).
        //If your token leaves out totalSupply and can issue more tokens as time goes on, you need to check if it doesn't wrap.
        //Replace the if with this one instead.
        //if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        } else { 
	    return false; 
	}
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
        } else { 
	    return false; 
	}
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
    The following variables are OPTIONAL. One does not have to include them.
    They allow one to customise the token contract & in no way influences the core functionality.
    Some wallets/interfaces might not even bother to look at this information.
    */

    string public standard = 'Token 0.1';

    string public constant name = "Golem Network Token";
    uint8 public constant decimals = 21; // FIXME: 1 ETH will be changed to 1000 GNT and 1 ETH has 18 decimal units
    string public constant symbol = "GNT";

    address constant owner = {{address(GolemCrowdfunding contract)}}; // TODO: 

    modifier ownerOnly () {
        if (msg.sender != owner) {
            throw;
        }
        _
    }

    /// @notice Issues specified number of tokens on behalf of the crowdfunding contract (owner).
    /// @param _receiver Address of the receiver.
    /// @param _numTokens Number of tokens to issue.
    function issueTokens(address _receiver, uint _numTokens) external ownerOnly returns (bool)
    {
        if (_numTokens == 0) {
            return false;
        }
        
        balances[_receiver] += _numTokens;
        totalSupply += _numTokens;        
        
        Transfer(0, address(golemCrowdfunding), _numTokens);
        Transfer(address(golemCrowdfunding), _receiver, _numTokens);
        
        return true;
    }
}

contract GolemCrowdfunding {

    // GNT contract 
    GolemNetworkToken public golemNetworkToken;
 
    // Static config
    uint256 constant ETH2GNTRate = 1000;
    uint256 constant minCapInETH = 74074 ether
    uint256 constant maxCapInETH = 740740 ether;

    // Make sure that this address points to the multisig wallet
    address owner;
 
    uint256 crowdfundingStartBlock;
    uint256 crowdfundingEndBlock;
    
    // emergency
    bool halted;
    
    // crowdfunding state
    uint256 crowdfundingETHBalance;
    uint256 issuedGNT;
    mapping (address => uint) fundersETHLedger;
    bool finalized;

    // modifiers
    
    modifier belowMaxCap() {
        // Make sure that current message is below maximum cap
        // Do not allow generating more than the cap.
        // UI should known that and propose available number of tokens,
        // but still it is a race condition.
        // Alternatively, we can generate up the cap and return the left ether
        // to the sender. But calling unknown addresses is a sequrity risk.
        if (msg.value > (maxCapInETH - crowdfundingETHBalance)) {
            throw;
        }
        _
    }

    modifier afterCrowdfunding() {
        if (block.number <= crowdfundingEndBlock) {
            throw;
        }
        _
    }

    modifier onlyIfMinGoalReached() {
        if (crowdfundingETHBalance < minCapInETH) {
            throw;
        }
        _
    }

    modifier onlyOwner() {
        // Only founder the owner is allowed
        if (msg.sender != owner) {
            throw;
        }
        _
    }

    modifier notHalted() {
        if (halted) {
            throw;
        }
        _
    }

    /// @notice Checks whether crowdfunding is in safe state`
    function checkIfIsInSafeState() constant private {
        if (crowdfundingETHBalance > this.balance) {
            throw;
        }
    }

    /// @notice fallback function called by anyone if and the contract is not in the safe state
    function emergencyFallback() external noEther returns (bool)
    {
        if (crowdfundingETHBalance > this.balance) {
            if (this.balance > 0 && !founder.send(this.balance)) {
                throw;
            }
            return true;
        }
        return false;
    }

    // Emergency halt - in case something unexpected happens
    function haltCrowdfunding() external onlyOwner {
        halted = true;
    }
    
    // Resume crowdfunding contract
    function resumeCrowdfunding() external onlyOwner {
        halted = false;
    }
 
    /// @notice fallback function called if for some reason owner address has to be changed
    function changeOwner(address _newOwner) external notHalted onlyOwner {
        owner = _newOwner;
    }

    function GolemCrowdfunding(uint256 _crowdfundingStartBlock, uint256 _crowdfundingEndBlock) {
        owner = msg.sender;
        crowdfundingStartBlock = _crowdfundingStartBlock;
        crowdfundingEndBlock = _crowdfundingEndBlock;
        
        // FIXME: leave or comment out (by default all member variabels are initialized this way)
        halted = false;
        crowdfundingETHBalance = 0;
        issuedGNT = 0;
        finalized = false;
    }

    /// @notice Setup function sets external contracts' addresses.
    /// @param golemNetworkTokenAddress Token address.
    function initialize(address _golemNetworkTokenAddress) external notHalted onlyOwner returns (bool)
    {
        if (address(golemNetworkToken) == 0) {
            golemNetworkToken = GolemNetworkToken(_golemNetworkTokenAddress);
            return true;
        }
        return false;
    }
    
    // Checks if minimum goal was reached
    function minGoalReached() private constant returns (bool) {
        return crowdfundingETHBalance >= minCapInETH;
    }

    // If before fundingh period, return all eth from the current message to the owner
    // If in the funding period, generate tokens for incoming ethers
    // If after the funding period, conditionally handle investment return (if the minimum cap was not reached)
    function() external payable notHalted {

        // Make sure that this contract doesn't do anything before the crowdfunding start date
        if (block.number < crowdfundingStartBlock) throw;
        
        if (block.number <= crowdfundingEndBlock) {
            handleCrowdfunding();
        } else {
            handlePostCrowdfunding();
        }

        checkIfIsInSafeState();
    }

    // Handles generation of tokens
    function handleCrowdfunding() private belowMaxCap {
        var numTokens = msg.value * ETH2GNTRate;

        if( numtokens > 0 ) {
            if (!golemNetworkToken.issueTokens(msg.sender, numTokens)) {
                throw;
            }

            // Update ETH ledger and track total ETH sent to this contract
            fundersETHLedger[msg.sender] += msg.value;
            crowdfundingETHBalance += msg.value;    
            issuedGNT += numTokens;
        }
    }
    
    // Return funder ETH
    function refundFunder() private {    
        var funderETH = fundersETHLedger[msg.sender];
        fundersETHLedger[msg.sender] = 0;
        crowdfundingETHBalance -= funderETH;

        if (funderETH > 0 && !msg.sender.send(funderETH)) {
            throw;
        }
    }

    // Handles token refund in case minCapInETH was not reached
    function handlePostCrowdfunding() private {
        if (msg.value > 0) throw;

        if (!minGoalReached()) {
            refundFunder();
        }
    }

    // Finalize crowdfunding (send ETH to the founder and generate additional founder GNT)
    function finalze() external notHalted onlyOwner afterCrowdfunding onlyIfMinGoalReached {
        if (!finalized) {
            // Transfer funds to the owner (founder)
            var totalFundedETH = crowdfundingETHBalance;
            crowdfundingETHBalance = 0;
            if (totalFundedETH > 0 && !owner.send(totalFundedETH)) {
                throw;
            }
            
            // Generate additional tokens for the Founder
            var founderNumTokens = issuedGNT * percentTokensForFounder / (100 - percentTokensForFounder);

            if (!golemNetworkToken.issueTokens(founder, founderNumTokens)) {
                throw;
            }

            founderTokensIssued = true;
            issuedGNT += founderNumTokens;

            finalized = true;

            checkIfIsInSafeState();

            // Cleanup. Remove all data not needed any more.
            // Also zero the founder address to indicate that funding has been
            // finalized.
            crowdfundingStartBlock = 0;
            crowdfundingEndBlock = 0;
        }
    }
}
