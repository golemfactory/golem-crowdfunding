pragma solidity ^0.4.1;

import "StandardToken.sol";
import "GolemCrowdfundingForward.sol";


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

    GolemCrowdfunding constant golemCrowdfunding = GolemCrowdfunding({{GolemCrowdfunding}}); // TODO: 

    modifier noEther() {
        if (msg.value > 0) {
            throw;
        }
        _
    }

    modifier crowdfundingContractOnly () {
        if (msg.sender != address(golemCrowdfunding)) {
            throw;
        }
        _
    }

    /// @notice Issues specified number of tokens on behalf of the crowdfunding contract.
    /// @param _receiver Address of the receiver.
    /// @param _numTokens Number of tokens to issue.
    function issueTokens(address _receiver, uint _numTokens) external crowdfundingContractOnly returns (bool)
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

    function transfer(address _to, uint256 _value) noEther returns (bool)
    {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) noEther returns (bool)
    {
        return super.transferFrom(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) noEther returns (bool success) {
        return super.approve(_spender, _value);
    }
}
