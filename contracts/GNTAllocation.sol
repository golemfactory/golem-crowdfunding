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
        // 6/18 = 1/3
        allocations[0xde00] = 83333; // DIVISOR / 3 * 25 / 100
        allocations[0xde01] = 24333; // DIVISOR / 3 * 7.3 / 100
        allocations[0xde02] = 24333; // DIVISOR / 3 * 7.3 / 100
        allocations[0xde03] = 24333; // DIVISOR / 3 * 7.3 / 100
        allocations[0xde04] = 24333; // DIVISOR / 3 * 7.3 / 100
        allocations[0xde05] = 24333; // DIVISOR / 3 * 7.3 / 100
        allocations[0xde06] = 20999; // DIVISOR / 3 * 6.3 / 100
        allocations[0xde07] = 20999; // DIVISOR / 3 * 6.3 / 100
        allocations[0xde08] = 20999; // DIVISOR / 3 * 6.3 / 100
        allocations[0xde09] = 20999; // DIVISOR / 3 * 6.3 / 100
        allocations[0xde10] = 10333; // DIVISOR / 3 * 3.1 / 100
        allocations[0xde11] =  5099; // DIVISOR / 3 * 1.53 / 100
        allocations[0xde12] =  4999; // DIVISOR / 3 * 1.5 / 100
        allocations[0xde13] =  3333; // DIVISOR / 3 * 1 / 100
        allocations[0xde14] =  3333; // DIVISOR / 3 * 1 / 100
        allocations[0xde15] =  3333; // DIVISOR / 3 * 1 / 100
        allocations[0xde16] =  2333; // DIVISOR / 3 * 0.7 / 100
        allocations[0xde17] =  2333; // DIVISOR / 3 * 0.7 / 100
        allocations[0xde18] =  2333; // DIVISOR / 3 * 0.7 / 100
        allocations[0xde19] =  2333; // DIVISOR / 3 * 0.7 / 100
        allocations[0xde20] =  2333; // DIVISOR / 3 * 0.7 / 100
        allocations[0xde21] =  1399; // DIVISOR / 3 * 0.42 / 100
        allocations[0xde22] =   833; // DIVISOR / 3 * 0.25 / 100
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
