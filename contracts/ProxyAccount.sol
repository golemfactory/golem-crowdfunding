pragma solidity ^0.4.1;


contract GolemNetworkToken {

    function transfer(address _to, uint256 _value) returns (bool success);
    function balanceOf(address _owner) constant returns (uint256 balance);

    function migrate(uint256 _value);
    function setMigrationAgent(address _agent);

    function changeGolemFactory(address _golemFactory);
}


contract TimeLockedGNTProxyAccount {

    address public owner;

    uint256 public availableAfter;
    address public gnt;


    // Modifiers
	
    modifier ownerOnly {
        if (msg.sender != owner) throw;
        _;
    }

    modifier gntOnly {
        if (msg.sender != gnt) throw;
        _;
    }
   
   modifier notLocked {
    	if (now < availableAfter) throw;
    	_;
    }


    // Creation and initialization

    function TimeLockedGNTProxyAccount(uint256 _availableAter) {
        owner = msg.sender;
        availableAfter = _availableAter;
    }

    function setGNTContract(address _gnt) ownerOnly external {
        gnt = _gnt;
    }


    // Token interface

    function transfer(address _to, uint256 _value) notLocked ownerOnly returns (bool success) {
        return GolemNetworkToken(gnt).transfer(_to, _value);
    }
    

    // Migration interface

    function migrate(uint256 _value) ownerOnly external {
        GolemNetworkToken(gnt).migrate(_value);
    }

    
    // Default function - do not allow any eth transfers to this contract
    
    function() {
    }
}


contract TimeLockedGolemFactoryProxyAccount is TimeLockedGNTProxyAccount {

    // Creation and initialization

    function TimeLockedGolemFactoryProxyAccount(uint256 _availableAter) TimeLockedGNTProxyAccount(_availableAter) {
    }
    

    // Golem Factory privileged API

    function changeGolemFactory(address _golemFactory) ownerOnly external {
        GolemNetworkToken(gnt).changeGolemFactory(_golemFactory);
    }

    // Migration interface

    function setMigrationAgent(address _agent) ownerOnly external {
        GolemNetworkToken(gnt).setMigrationAgent(_agent);
    }

    // Default function - transfer everything to the owner by default, allow transfers from the GNT contract only  
    
    function() gntOnly payable {
        if (!owner.send(this.balance)) throw;
    }
}
