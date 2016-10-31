pragma solidity ^0.4.3;

import "./Token.sol";

contract GNTAllocation {
    mapping (address => uint256) allocations;

    // Number of allocations to distribute additional tokens among developers and
    // Golem Factory. The Golem Factory has right to 2000 allocations,
    // developers to 1000 allocations, divides among individual developers by
    // numbers specified in  `allocations` table.
    uint256 constant totalAllocations = 3000;

    address golemFactory;

    GolemNetworkToken gnt;
    uint256 unlockedAt;

    // Value of a single allocation expressed in GNT.
    uint256 tokensPerAllocation = 0;

    // Number of GNT that will remain after assigning all allocations, due to
    // rounding error in `tokensPerAllocation`.
    uint256 allocationsRemainder = 0;

    function GNTAllocation(address _golemFactory) internal {
        gnt = GolemNetworkToken(msg.sender);
        golemFactory = _golemFactory;
        unlockedAt = now + 6 * 30 days;

        allocations[_golemFactory] = 2000;  // 12/18 pp of 3000 allocations.

        // developers
        allocations[0xde00] = 250;  // 25.0% of developers' allocations (1000).
        allocations[0xde01] =  73;  //  7.5% of developers' allocations.
        allocations[0xde02] =  73;
        allocations[0xde03] =  73;
        allocations[0xde04] =  73;
        allocations[0xde05] =  73;
        allocations[0xde06] =  63;  //  6.3% of developers' allocations.
        allocations[0xde07] =  63;
        allocations[0xde08] =  63;
        allocations[0xde09] =  63;
        allocations[0xde10] =  31;  //  3.1% of developers' allocations.
        allocations[0xde11] =  15;  //  1.5% of developers' allocations.
        allocations[0xde12] =  15;
        allocations[0xde13] =  10;  //  1.0% of developers' allocations.
        allocations[0xde14] =  10;
        allocations[0xde15] =  10;
        allocations[0xde16] =   7;  //  0.7% of developers' allocations.
        allocations[0xde17] =   7;
        allocations[0xde18] =   7;
        allocations[0xde19] =   7;
        allocations[0xde20] =   7;
        allocations[0xde21] =   4;  //  0.4% of developers' allocations.
        allocations[0xde22] =   3;  //  0.3% of developers' allocations.
    }

    // Allows developer to unlock its allocated tokens by transferring them back
    // to developer's address.
    function unlock() external {
        if (now < unlockedAt) throw;

        // First unlock attempt.
        if (tokensPerAllocation == 0) {
            // Fetch number of total tokens locked.
            var tokensCreated = gnt.balanceOf(this);
            // Calculate the value of each allocation.
            tokensPerAllocation = tokensCreated / totalAllocations;
            // Calculate the number of tokens remaining.
            allocationsRemainder = tokensCreated % totalAllocations;
        }

        var allocation = allocations[msg.sender];
        allocations[msg.sender] = 0;
        var toTransfer = tokensPerAllocation * allocation;

        // If there are tokens left to transfer for Golem Factory,
        // include the remaining tokens.
        if (msg.sender == golemFactory && toTransfer > 0)
            toTransfer += allocationsRemainder;

        // Will fail if allocation/toTransfer is 0.
        if (!gnt.transfer(msg.sender, toTransfer)) throw;
    }
}
