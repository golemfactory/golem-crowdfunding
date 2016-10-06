contract TokenDB {
    address public golemAgent = 0xFF;    // Golem agent can call any method (initially gntmakeragent)
    address public accountAgent = 0xFF;      // Account agent can only call transfer method (initially gntaccountagent)
    address master = 0xFF;                      // Allowed to change agents

    mapping (address => uint256) balances;

    function balanceOf(address _addr) constant returns (uint256) { return balances[_addr]; }

    function transfer(address _from, address _to, uint256 _value) returns (bool success) {
        if (_value < 1 || (msg.sender != golemAgent && msg.sender != accountAgent)) {
            throw;
        }
        
        uint256 fromBalance = balances[_from];
        if (_value > fromBalance) throw;
        
        balances[_from] = fromBalance - _value;
        balances[_to] += _value;

        return true;
    }
    
    function create(address _addr, uint256 _value) returns (bool success) {
        if (_value < 1 || msg.sender != golemAgent) throw;
        balances[_addr] += _value;
        return true;
    }
    
    function setGolemAgent(address _addr) {
        if (msg.sender == master)
            golemAgent = _addr;
    }

    function setAccountAgent(address _addr) {
        if (msg.sender == master)
            accountAgent = _addr;
    }

    function setMaster(address _addr) {
        if (msg.sender == master)
            master = _addr;
    }
}