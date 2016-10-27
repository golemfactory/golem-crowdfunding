pragma solidity ^0.4.1;

import "./Token.sol";

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

    function TimeLockedGNTProxyAccount(address _owner, uint256 _availableAfter) {
        owner = _owner;
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


contract TimeLockedGolemFactoryProxyAccount is TimeLockedGNTProxyAccount {

    // Creation and initialization

    function TimeLockedGolemFactoryProxyAccount(address _owner, uint256 _availableAfter) TimeLockedGNTProxyAccount(_owner, _availableAfter) {
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

contract ProxyAccountCreator {
    
    address owner;
    uint256 availableAfter;
    
    uint256 numGeneratedProxies;
    
    uint256 private constant PROXIES_AT_ONCE = 4;
    uint256 private constant NUM_DEVS = 23;
    
    bool finalized;
    
    event DevProxy(uint256 idx, address _addr);
    event GolemFactoryProxy(address _addr);
    
    function ProxyAccountCreator(uint256 _availableAfter) {
        owner = msg.sender;
        availableAfter = _availableAfter;
        numGeneratedProxies = 0;
        finalized = false;
    }

    function min(uint256 a, uint256 b) private returns (uint256 result) {
        if (a < b)
            return a;
            
        return b;
    }

    function() {
        if (msg.sender != owner) throw;
        if (finalized) throw;
        
        address   golemFactory = 0xde23;
        address[] devs = [
            0xde00,
            0xde01,
            0xde02,
            0xde03,
            0xde04,
            0xde05,
            0xde06,
            0xde07,
            0xde08,
            0xde09,
            0xde10,
            0xde11,
            0xde12,
            0xde13,
            0xde14,
            0xde15,
            0xde16,
            0xde17,
            0xde18,
            0xde19,
            0xde20,
            0xde21,
            0xde22
        ];   
    
        var bound = min(numGeneratedProxies + PROXIES_AT_ONCE, devs.length);
        
        for (uint256 i = numGeneratedProxies; i < bound; ++i) {
            var devAddr = devs[i];
            var proxyContract = new TimeLockedGNTProxyAccount(devAddr, availableAfter);
            
            numGeneratedProxies++;
        
            DevProxy(i, address(proxyContract));
        }
        
        if(numGeneratedProxies == devs.length && !finalized) {
            var golemFactoryProxyContract = new TimeLockedGolemFactoryProxyAccount(golemFactoryAddr, availableAfter);

            finalized = true;
            numGeneratedProxies++;

            GolemFactoryProxy(address(golemFactoryProxyContract));
        }
    }
