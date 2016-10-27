pragma solidity ^0.4.1;

import "./Token.sol";

contract GNTAllocation {
    mapping (address => uint256) allocations;
    uint256 constant DIVISOR = 1000000;

    GolemNetworkToken gnt;
    uint256 unlockedAt;

    uint256 tokensCreated = 0;
    uint256 tokensRemaining = 0;

    function GNTAllocation(address _golemFactory) internal {
        gnt = GolemNetworkToken(msg.sender);
        unlockedAt = now + 6 * 30 days;

        // reserved for factory
        allocations[_golemFactory] = 120000; // 12 * DIVISOR / 100

        // developers
        allocations[0xde00] = 15000; // 6 * DIVISOR / 100 * 25 / 100
        allocations[0xde01] =  4380; // 6 * DIVISOR / 100 * 7.3 / 100
        allocations[0xde02] =  4380; // 6 * DIVISOR / 100 * 7.3 / 100
        allocations[0xde03] =  4380; // 6 * DIVISOR / 100 * 7.3 / 100
        allocations[0xde04] =  4380; // 6 * DIVISOR / 100 * 7.3 / 100
        allocations[0xde05] =  4380; // 6 * DIVISOR / 100 * 7.3 / 100
        allocations[0xde06] =  3780; // 6 * DIVISOR / 100 * 6.3 / 100
        allocations[0xde07] =  3780; // 6 * DIVISOR / 100 * 6.3 / 100
        allocations[0xde08] =  3780; // 6 * DIVISOR / 100 * 6.3 / 100
        allocations[0xde09] =  3780; // 6 * DIVISOR / 100 * 6.3 / 100
        allocations[0xde10] =  1860; // 6 * DIVISOR / 100 * 3.1 / 100
        allocations[0xde11] =   918; // 6 * DIVISOR / 100 * 1.53 / 100
        allocations[0xde12] =   900; // 6 * DIVISOR / 100 * 1.5 / 100
        allocations[0xde13] =   600; // 6 * DIVISOR / 100 * 1 / 100
        allocations[0xde14] =   600; // 6 * DIVISOR / 100 * 1 / 100
        allocations[0xde15] =   600; // 6 * DIVISOR / 100 * 1 / 100
        allocations[0xde16] =   420; // 6 * DIVISOR / 100 * 0.7 / 100
        allocations[0xde17] =   420; // 6 * DIVISOR / 100 * 0.7 / 100
        allocations[0xde18] =   420; // 6 * DIVISOR / 100 * 0.7 / 100
        allocations[0xde19] =   420; // 6 * DIVISOR / 100 * 0.7 / 100
        allocations[0xde20] =   420; // 6 * DIVISOR / 100 * 0.7 / 100
        allocations[0xde21] =   252; // 6 * DIVISOR / 100 * 0.42 / 100
        allocations[0xde22] =   150; // 6 * DIVISOR / 100 * 0.25 / 100
    }

    // FIXME: Rename to something like "notifyFundingFinalized()"?
    function allocate(uint256 _tokensCreated) external {
        if (msg.sender != address(gnt)) throw;

        tokensCreated = _tokensCreated;
        tokensRemaining = _tokensCreated;
    }


    // Allows developer to unlock its allocated tokens by transfering them back
    // to its address.
    function unlock() returns (bool success) {
        // FIXME: Remove tokensRemaining == 0 test. Not needed.
        if (tokensRemaining == 0 || now < unlockedAt) throw;

        // FIXME: Consider allowing any sender to unlock developer tokens.
        var allocation = allocations[msg.sender];
        if (allocation > 0) {
            allocations[msg.sender] = 0;

            var toTransfer = tokensCreated * allocation / DIVISOR;
            // account for rounding (only last developer to pull tokens will be affected)
            // FIXME: This cannot happen, but some remaining tokens are going to
            //        left here forever. Assign them to the last transfer.
            // FIXME: We can also selfdestruct the contract after unlocking
            //        last account.
            toTransfer = toTransfer > tokensRemaining ? tokensRemaining : toTransfer;
            tokensRemaining -= toTransfer;
            gnt.transfer(msg.sender, toTransfer);
            return true;
        }
        return false;
    }
}
