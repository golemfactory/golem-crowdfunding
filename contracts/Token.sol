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

    /*
     *********************************** CONFIGURATION AND STATUS DATA STRUCTURES ***********************************  
     */
     
    // Crowdfunding config
    struct CrowdfundingConfig {
        uint256 constant percentTokensForFounder = 18;

        uint256 constant ETH2GNTRate = 1000;

        uint256 constant minCapInETH = 74074 ether
        uint256 constant maxCapInETH = 740740 ether;

        uint256 crowdfundingStartBlock;
        uint256 crowdfundingEndBlock;
    }
    
    // Crowdfunding status
    struct CrowdfundingStatus {
        mapping (address => uint) fundersETHLedger;

        uint256 balanceETH;
        uint256 issuedGNT;

        bool halted;
        bool finalized;
    }

    /*
     ******************************************* CROWDFUNDING VARIABLES ********************************************
     */
     
    CrowdfundingConfig config;
    CrowdfundingStatus status;

    // Make sure that this address points to a multisig wallet - this is the founder wallet
    address owner;

    GolemNetworkToken  gnt;
 
    /*
     ************************************************** MODIFIERS **************************************************
     */
     
    modifier belowMaxCap() {
        if (msg.value > (config.maxCapInETH - status.balanceETH)) {
            throw;
        }
        _
    }

    modifier afterCrowdfunding() {
        if (block.number <= config.crowdfundingEndBlock) {
            throw;
        }
        _
    }

    modifier onlyIfMinGoalReached() {
        if (status.balanceETH < config.minCapInETH) {
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
        if (status.halted) {
            throw;
        }
        _
    }

    /*
     ************************************************ EMERGENCY API ************************************************
     */

    /// @notice Checks whether crowdfunding is in safe state`
    function checkIfIsInSafeState() constant private {
        if (status.balanceETH > this.balance) {
            throw;
        }
    }

    /// @notice fallback function called by anyone if and the contract is not in the safe state
    function emergencyFallback() external noEther returns (bool)
    {
        if (status.balanceETH > this.balance) {
            if (this.balance > 0 && !founder.send(this.balance)) {
                throw;
            }
            return true;
        }
        return false;
    }

    // Emergency halt - in case something unexpected happens
    function haltCrowdfunding() external onlyOwner {
        status.halted = true;
    }
    
    // Resume crowdfunding contract
    function resumeCrowdfunding() external onlyOwner {
        status.halted = false;
    }
 
    /// @notice fallback function called if for some reason owner address has to be changed
    function changeOwner(address _newOwner) external notHalted onlyOwner {
        owner = _newOwner;
    }

    /*
     ********************************************** CREATION AND SETUP *********************************************
     */

    function GolemCrowdfunding(uint256 _crowdfundingStartBlock, uint256 _crowdfundingEndBlock) {
        owner = msg.sender;
        
        config.crowdfundingStartBlock = _crowdfundingStartBlock;
        config.crowdfundingEndBlock = _crowdfundingEndBlock;
        
        status.balanceETH = 0;
        status.issuedGNT = 0;
        status.halted = false;
        status.finalized = false;
    }

    /// @notice Setup function sets external contracts' addresses.
    /// @param golemNetworkTokenAddress Token address.
    function initialize(address _golemNetworkTokenAddress) external notHalted onlyOwner returns (bool)
    {
        if (address(gnt) == 0) {
            gnt = GolemNetworkToken(_golemNetworkTokenAddress);
            return true;
        }
        return false;
    }
    
    /*
     *********************************************** CROWDFUNDING API **********************************************
     */

    // Crowdfunding entry point (this is the only function that should be called by funders)
    // If before funding period, return all eth from the current message to the owner
    // If during the funding period, generate tokens for incoming ethers
    // If after the funding period, conditionally handle investment return (if the minimum cap was not reached)
    function() external payable notHalted {

        // Make sure that this contract doesn't do anything before the crowdfunding start date
        if (block.number < config.crowdfundingStartBlock) throw;
        
        // Crowdfunding ongoing
        if (block.number <= config.crowdfundingEndBlock) {
            var numTokens = msg.value * config.ETH2GNTRate;

            if( numtokens > 0 ) {
                if (!gnt.issueTokens(msg.sender, numTokens)) {
                    throw;
                }

                // Update ETH ledger and track total ETH sent to this contract
                status.fundersETHLedger[msg.sender] += msg.value;
                status.balanceETH += msg.value;    
                status.issuedGNT += numTokens;
            }
        } else { // After the crowdfunding
            if (msg.value > 0) throw;

            // Minimum cap not reached
            if (status.balanceETH < config.minCapInETH) {
                var funderETH = status.fundersETHLedger[msg.sender];
                status.fundersETHLedger[msg.sender] = 0;
                status.balanceETH -= funderETH;

                if (funderETH > 0 && !msg.sender.send(funderETH)) {
                    throw;
                }
            }
        }

        checkIfIsInSafeState();
    }

    // Finalize crowdfunding (send ETH to the founder and generate additional founder GNT)
    function finalze() external notHalted onlyOwner afterCrowdfunding onlyIfMinGoalReached {
        if (!status.finalized) {
            // Transfer funds to the owner (founder)
            var totalFundedETH = status.balanceETH;
            status.balanceETH = 0;

            if (totalFundedETH > 0 && !owner.send(totalFundedETH)) {
                throw;
            }

            // Generate additional tokens for the Founder
            var founderNumTokens = status.issuedGNT * config.percentTokensForFounder / (100 - config.percentTokensForFounder);

            if (!gnt.issueTokens(owner, founderNumTokens)) {
                throw;
            }

            status.issuedGNT += founderNumTokens;
            status.finalized = true;

            checkIfIsInSafeState();

            // Cleanup. Remove all data not needed any more.
            // Also zero the founder address to indicate that funding has been
            // finalized.
            config.crowdfundingStartBlock = 0;
            config.crowdfundingEndBlock = 0;
        }
    }
}
