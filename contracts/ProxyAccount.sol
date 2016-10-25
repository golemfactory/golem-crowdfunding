pragma solidity ^0.4.1;

import * as Source from "./Token.sol";

contract TimeLockedGNTProxyAccount {

    address public owner;

    uint256 public availableAfter;
    Source.GolemNetworkToken public gnt;

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
        gnt = Source.GolemNetworkToken(_gnt);
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


contract TimeLockedGolemFactoryProxyAccount is TimeLockedGNTProxyAccount {

    // Creation and initialization

    function TimeLockedGolemFactoryProxyAccount(uint256 _availableAfter) TimeLockedGNTProxyAccount(_availableAfter) {
    }
    
    // Modifiers
    
    modifier gntOnly {
        if (msg.sender != address(gnt)) throw;
        _;
    }

    // Golem Factory privileged API

    function changeGolemFactory(address _golemFactory) ownerOnly external {
        gnt.changeGolemFactory(_golemFactory);
    }
    // Migration interface

    function setMigrationAgent(address _agent) ownerOnly external {
        gnt.setMigrationAgent(_agent);
    }

    // Default function - allow transfers from the GNT contract only  
    
    function() gntOnly payable {
    }

    // Withdraw - transfer ETH to to the Golem Factory
    
    function withdraw() ownerOnly {
        if (!owner.send(this.balance)) throw;
    }
}
