import "TokenDB.sol";

// TODO: Make upgradeable via delegatecall mechanism

contract GNTAccountAgent {
    string public constant name = "GNT Account";
    string public constant solidityVersion = "xxxxxxxx";

    TokenDB tokenDB;

    function balanceOf(address _owner) returns (uint256 balance) {
        return tokenDB.balanceOf(_owner);
    }

    function transfer(address _to, uint256 _value) returns (bool success) {
        return tokenDB.transfer(msg.sender, _to, _value);
    }
    
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
}