pragma solidity ^0.4.4;

import "./TimeLockedGNTProxyAccount.sol";

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

    function setMigrationMaster(address _migrationMaster) ownerOnly external {
        gnt.setMigrationMaster(_migrationMaster);
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
