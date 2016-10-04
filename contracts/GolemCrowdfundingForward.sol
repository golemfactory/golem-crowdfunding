pragma solidity ^0.4.1;


contract GolemCrowdfunding {
    function crowdfundingStartBlock() constant returns (uint256);
    function crowdfundingEndBlock() constant returns (uint256);
    function ETH2GNTRate() constant returns (uint256);
    function minCapInETH() constant returns (uint256);
    function maxCapInETH() constant returns (uint256);
    function minAcceptedETH() constant returns (uint256);
    function halted() constant returns (bool);
    function crowdfundingETHBalance() constant returns (uint256);
    function issuedGNT() conatant returns (uint256);
    function founderTokensIssued() constant returns (bool);
}
