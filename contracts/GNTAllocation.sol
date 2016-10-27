pragma solidity ^0.4.1;

import "./Token.sol";

contract GNTAllocation {
    mapping (address => uint256) allocations;
    uint256 constant DIVISOR = 18 / 6 * 10000;

    GolemNetworkToken gnt;
    uint256 unlockedAt;

    uint256 tokensCreated = 0;
    uint256 tokensRemaining = 0;

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

    // FIXME: Rename to something like "notifyFundingFinalized()"?
    function allocate(uint256 _tokensCreated) external {
        if (msg.sender != address(gnt)) throw;

        tokensCreated = _tokensCreated;
        tokensRemaining = _tokensCreated;
    }


    // Allows developer to unlock its allocated tokens by transfering them back
    // to its address.
    function unlock() external {
        // FIXME: Remove tokensRemaining == 0 test. Not needed.
        if (tokensRemaining == 0 || now < unlockedAt) throw;

        var allocation = allocations[msg.sender];
        allocations[msg.sender] = 0;

        var toTransfer = tokensCreated * allocation / DIVISOR;
        // account for rounding (only last developer to pull tokens will be affected)
        // FIXME: This cannot happen, but some remaining tokens are going to
        //        left here forever. Assign them to the last transfer.
        // FIXME: We can also selfdestruct the contract after unlocking
        //        last account.
        toTransfer = toTransfer > tokensRemaining ? tokensRemaining : toTransfer;
        tokensRemaining -= toTransfer;
        // Will fail if allocation is 0.
        if (!gnt.transfer(msg.sender, toTransfer)) throw;
    }
}
