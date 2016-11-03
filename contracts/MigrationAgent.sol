pragma solidity ^0.4.4;

import "./GolemNetworkToken.sol";
import "./GNTTargetToken.sol";

//Test the whole process against this: https://www.kingoftheether.com/contract-safety-checklist.html
contract MigrationAgent {

    address owner;
    address gntSourceToken;
    address gntTargetToken;

    uint256 tokenSupply;

    function MigrationAgent(address _gntSourceToken) {
        owner = msg.sender;
        gntSourceToken = _gntSourceToken;

        if (GolemNetworkToken(gntSourceToken).funding()) throw;

        tokenSupply = GolemNetworkToken(gntSourceToken).totalSupply();
    }

    function safetyInvariantCheck(uint256 _value) private {
        if (gntTargetToken == 0) throw;
        if (GolemNetworkToken(gntSourceToken).totalSupply() + GNTTargetToken(gntTargetToken).totalSupply() != tokenSupply - _value) throw;
    }

    function setTargetToken(address _gntTargetToken) {
        if (msg.sender != owner) throw;
        if (gntTargetToken != 0) throw; //Allow this change once only

        gntTargetToken = _gntTargetToken;
    }

    //Interface implementation
    function migrateFrom(address _from, uint256 _value) {
        if (msg.sender != gntSourceToken) throw;
        if (gntTargetToken == 0) throw;

        //Right here gntSourceToken has already been updated, but corresponding GNT have not been created in the gntTargetToken contract yet
        safetyInvariantCheck(_value);

        GNTTargetToken(gntTargetToken).createToken(_from, _value);

        //Right here totalSupply invariant must hold
        safetyInvariantCheck(0);
    }

    function finalizeMigration() {
        if (msg.sender != owner) throw;

        safetyInvariantCheck(0);

        //Additional, strict test
        //if (gntSourceToken.totalSupply() > 0) throw;

        GNTTargetToken(gntTargetToken).finalizeMigration();

        gntSourceToken = 0;
        gntTargetToken = 0;

        tokenSupply = 0;
    }

}
