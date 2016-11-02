pragma solidity ^0.4.4;

import "./Token.sol";

contract GNTAllocation {
    mapping (address => uint256) allocations;
    uint256 constant DIVISOR = 18 / 6 * 10000;

    GolemNetworkToken gnt;
    uint256 unlockedAt;

    uint256 tokensCreated = 0;

    function GNTAllocation(address _golemFactory) internal {
        gnt = GolemNetworkToken(msg.sender);
        unlockedAt = now + 6 * 30 days;

        // reserved for factory
        allocations[_golemFactory] = 20000; // 12 * DIVISOR / 18

        // developers
        allocations[0xde00] = 2500; // 0.25 * 6 * DIVISOR / 18
        allocations[0xde01] =  730; // ...
        allocations[0xde02] =  730;
        allocations[0xde03] =  730;
        allocations[0xde04] =  730;
        allocations[0xde05] =  730;
        allocations[0xde06] =  630;
        allocations[0xde07] =  630;
        allocations[0xde08] =  630;
        allocations[0xde09] =  630;
        allocations[0xde10] =  310;
        allocations[0xde11] =  153;
        allocations[0xde12] =  150;
        allocations[0xde13] =  100;
        allocations[0xde14] =  100;
        allocations[0xde15] =  100;
        allocations[0xde16] =   70;
        allocations[0xde17] =   70;
        allocations[0xde18] =   70;
        allocations[0xde19] =   70;
        allocations[0xde20] =   70;
        allocations[0xde21] =   42;
        allocations[0xde22] =   25;
    }

    // Allows developer to unlock its allocated tokens by transferring them back
    // to developer's address.
    function unlock() external {
        if (now < unlockedAt) throw;

        // First unlock attempt.
        if (tokensCreated == 0) {
            // Fetch number of total tokens locked.
            tokensCreated = gnt.balanceOf(this);
        }

        var allocation = allocations[msg.sender];
        allocations[msg.sender] = 0;
        var toTransfer = tokensCreated * allocation / DIVISOR;

        // Will fail if allocation is 0.
        if (!gnt.transfer(msg.sender, toTransfer)) throw;
    }
}
