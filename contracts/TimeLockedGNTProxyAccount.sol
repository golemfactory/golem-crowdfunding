pragma solidity ^0.4.4;

import "./GolemNetworkToken.sol";

contract TimeLockedGNTProxyAccount {

    address public owner;

    uint256 public availableAfter;
    GolemNetworkToken public gnt;

    // Modifiers

    modifier ownerOnly {
        if (msg.sender != owner) throw;
        _;
    }

    modifier notLocked {
    	if (now < availableAfter) throw;
    	_;
    }

    // Creation and initialization

    function TimeLockedGNTProxyAccount(uint256 _availableAfter) {
        owner = msg.sender;
        availableAfter = _availableAfter;
    }

    function setGNTContract(address _gnt) ownerOnly external {
        gnt = GolemNetworkToken(_gnt);
    }

    // Token interface

    function transfer(address _to, uint256 _value) notLocked ownerOnly returns (bool success) {
        return gnt.transfer(_to, _value);
    }

    // Migration interface

    function migrate(uint256 _value) ownerOnly external {
        gnt.migrate(_value);
    }

    // Default function - do not allow any eth transfers to this contract

    function() payable {
        throw;
    }
}
