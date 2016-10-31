pragma solidity ^0.4.1;

import "./Token.sol";

contract GNTAllocation {
    mapping (address => uint256) allocations;
    // Number of shares to distribute among developers and Golem Factory.
    // Value of each share is expressed in GNT and based on the number
    // of additional created tokens.
    // This number of shares is based on the percentage of additional tokens;
    // the magnitude was chosen to minimize rounding errors.
    uint256 constant SHARES = 18 / 6 * 10000 / 10;

    address golemFactory;

    GolemNetworkToken gnt;
    uint256 unlockedAt;

    // Value of a single share expressed in GNT
    uint256 tokensPerShare = 0;
    // Number of GNT that will remain after
    // assigning all shares, due to rounding errors.
    uint256 sharesRemainder = 0;

    function GNTAllocation(address _golemFactory) internal {
        gnt = GolemNetworkToken(msg.sender);
        golemFactory = _golemFactory;
        unlockedAt = now + 6 * 30 days;

        // reserved for factory
        allocations[_golemFactory] = 2000; // 12 * SHARES / 18 * 10

        // developers
        allocations[0xde00] = 250; // 0.25 * 6 * SHARES / 18 * 10
        allocations[0xde01] =  73; // ...
        allocations[0xde02] =  73;
        allocations[0xde03] =  73;
        allocations[0xde04] =  73;
        allocations[0xde05] =  73;
        allocations[0xde06] =  63;
        allocations[0xde07] =  63;
        allocations[0xde08] =  63;
        allocations[0xde09] =  63;
        allocations[0xde10] =  31;
        allocations[0xde11] =  15;
        allocations[0xde12] =  15;
        allocations[0xde13] =  10;
        allocations[0xde14] =  10;
        allocations[0xde15] =  10;
        allocations[0xde16] =   7;
        allocations[0xde17] =   7;
        allocations[0xde18] =   7;
        allocations[0xde19] =   7;
        allocations[0xde20] =   7;
        allocations[0xde21] =   4;
        allocations[0xde22] =   3;
    }

    // Allows developer to unlock its allocated tokens by transferring them back
    // to developer's address.
    function unlock() external {
        if (now < unlockedAt) throw;

        // First unlock attempt.
        if (tokensPerShare == 0) {
            // Fetch number of total tokens locked.
            var tokensCreated = gnt.balanceOf(this);
            // Calculate the value of each share.
            tokensPerShare = tokensCreated / SHARES;
            // Calculate the number of tokens remaining.
            sharesRemainder = tokensCreated % SHARES;
        }

        var allocation = allocations[msg.sender];
        allocations[msg.sender] = 0;
        var toTransfer = tokensPerShare * allocation;

        // If there are tokens left to transfer for Golem Factory,
        // include the remaining tokens.
        if (msg.sender == golemFactory && toTransfer > 0)
            toTransfer += sharesRemainder;

        // Will fail if allocation is 0.
        if (!gnt.transfer(msg.sender, toTransfer)) throw;
    }
}
