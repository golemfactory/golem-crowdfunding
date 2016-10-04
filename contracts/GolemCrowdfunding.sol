pragma solidity ^0.4.1;

import "GolemNetworkTokenForward.sol";


contract GolemCrowdfunding {

    // GNT contract 
    GolemNetworkToken public golemNetworkToken;
 
    // Static config
    uint256 constant ETH2GNTRate = 1000;
    uint256 constant minCapInETH = 74074 ether
    uint256 constant maxCapInETH = 740740 ether;
    uint256 constant minAcceptedETH = 1000 szabo; // 0.001 ETH

    // Make sure that this address points to the multisig wallet
    address founder = {{multisig wallet}}; // TODO: add valid address here
    address owner;
 
    uint256 crowdfundingStartBlock;
    uint256 crowdfundingEndBlock;
    
    // emergency
    bool halted;
    
    // crowdfunding state
    uint256 crowdfundingETHBalance;
    uint256 issuedGNT;
    mapping (address => uint) fundersETHLedger;
    bool founderTokensIssued;

    // modifiers
    modifier noEther() {
        if (msg.value > 0) {
            throw;
        }
        _
    }

    modifier minInvestment() {
        // Make sure that at least minAcceptedETH was sent
        if (msg.value < minAcceptedETH) {
            throw;
        }
        _
    }

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

    modifier onlyFounder() {
        // Only founder the founder is allowed
        if (msg.sender != founder) {
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

    /// @notice fallback function called if for some reason founder address has to be changed
    function changeFounder(address _newFounder) external notHalted noEther onlyOwner {
        founder = _newFounder;
    }
 
    /// @notice fallback function called if for some reason owner address has to be changed
    function changeOwner(address _newOwner) external notHalted noEther onlyOwner {
        owner = _newOwner;
    }

    function GolemCrowdfunding(uint256 _crowdfundingStartBlock, uint256 _crowdfundingEndBlock) noEther {
        owner = msg.sender;
        crowdfundingStartBlock = _crowdfundingStartBlock;
        crowdfundingEndBlock = _crowdfundingEndBlock;
        halted = false;
        crowdfundingETHBalance = 0;
        issuedGNT = 0;
        founderTokensIssued = false;
    }

    /// @notice Setup function sets external contracts' addresses.
    /// @param golemNetworkTokenAddress Token address.
    function initialize(address _golemNetworkTokenAddress) external notHalted noEther onlyOwner returns (bool)
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
    function() external notHalted {

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
    function handleCrowdfunding() private minInvestment belowMaxCap {
        var numTokens = msg.value * ETH2GNTRate;

        if (!golemNetworkToken.issueTokens(msg.sender, numTokens)) {
            throw;
        }

        // Update ETH ledger and track total ETH sent to this contract
        fundersETHLedger[msg.sender] += msg.value;
        crowdfundingETHBalance += msg.value;    
        issuedGNT += numTokens;
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
    function handlePostCrowdfunding() private noEther {
        if (!minGoalReached()) {
            refundFunder();
        }
    }

    // Allow the Founder to transfer ethers from the funding to its account.
    // This can be done only after the funding has ended and only once
    function transferEtherToFounder() external notHalted onlyOwner afterCrowdfunding onlyIfMinGoalReached {            
        var totalFundedETH = crowdfundingETHBalance;
        crowdfundingETHBalance = 0;
        if (totalFundedETH > 0 && !funder.send(totalFundedETH)) {
            throw;
        }
    
        checkIfIsInSafeState();
    }

    // Finalize the funding period
    function issueFounderTokens() external notHalted noETH onlyOwner afterCrowdfunding onlyIfMinGoalReached {
        
        if (!founderTokensIssued) {
            // Generate additional tokens for the Founder
            var founderNumTokens = issuedGNT * percentTokensForFounder / (100 - percentTokensForFounder);

            if (!golemNetworkToken.issueTokens(founder, founderNumTokens)) {
                throw;
            }

            founderTokensIssued = true;
            issuedGNT += founderNumTokens;
        }

        // Cleanup. Remove all data not needed any more.
        // Also zero the founder address to indicate that funding has been
        // finalized.
        crowdfundingStartBlock = 0;
        crowdfundingEndBlock = 0;
    }
}
