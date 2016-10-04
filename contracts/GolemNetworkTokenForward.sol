pragma solidity ^0.4.1;

import "ERC20TokenInterface.sol";


contract GolemNetworkToken is ERC20TokenInterface {

    function issueTokens(address _receiver, uint _numTokens) returns (bool);
}
