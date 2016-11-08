# Golem Token and Crowdfunding contracts

## Contracts
GNT contract is defined in contracts/Token.sol. Crowdfunding allocation of tokens for Golem Factory and developers is in contracts/GNTAllocation.sol. Other contracts are there for testing purposes only.

## Testing

Testing requires Python and following packages: pyetherem, py.test

    pip install -r requirements.txt
    
To run tests:

    make tests
