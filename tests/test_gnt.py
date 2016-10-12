import unittest
from ethereum import abi, tester
from rlp.utils import decode_hex

tester.serpent = True  # tester tries to load serpent module, prevent that.

# GNT contract bytecode (used to create the contract) and ABI.
# This is procudes by solidity compiler from Token.sol file.
# You can use Solidity Browser
# https://ethereum.github.io/browser-solidity/#version=soljson-v0.4.2+commit.af6afb04.js&optimize=true
# to work on and update the Token.
GNT_INIT = decode_hex(open('tests/GolemNetworkToken.bin', 'r').read().rstrip())
GNT_ABI = open('tests/GolemNetworkToken.abi', 'r').read()

class GNTCrowdfundingTest(unittest.TestCase):

    # Test account monitor.
    # The ethereum.tester predefines 10 Ethereum accounts
    # (tester.accounts, tester.keys).
    class Monitor:
        def __init__(self, state, account_idx, value=0):
            self.addr = tester.accounts[account_idx]
            self.key = tester.keys[account_idx]
            self.state = state
            self.value = value
            self.initial = state.block.get_balance(self.addr)
            assert self.initial > 0
            assert self.addr != state.block.coinbase

        def gas(self):
            b = self.state.block.get_balance(self.addr)
            total = self.initial - b
            g = (total - self.value) / tester.gas_price
            return g

    def monitor(self, addr, value=0):
        return self.Monitor(self.state, addr, value)

    def setUp(self):
        self.state = tester.state()

    def deploy_contract(self, founder, start, end, creator_idx=9):
        owner = self.monitor(creator_idx)
        t = abi.ContractTranslator(GNT_ABI)
        args = t.encode_constructor_arguments((founder, start, end))
        addr = self.state.evm(GNT_INIT + args,
                              sender=owner.key)
        self.c = tester.ABIContract(self.state, GNT_ABI, addr)
        return addr, owner.gas()

    def contract_balance(self):
        return self.state.block.get_balance(self.c.address)

    def balance_of(self, addr_idx):
        return self.c.balanceOf(tester.accounts[addr_idx])

    def test_deployment(self):
        founder = tester.accounts[2]
        c, g = self.deploy_contract(founder, 5, 105)
        assert len(c) == 20
        assert g <= 850000
        assert self.contract_balance() == 0
        assert decode_hex(self.c.founder()) == founder
        assert not self.c.fundingOngoing()

    def test_initial_balance(self):
        founder = tester.accounts[3]
        self.deploy_contract(founder, 5, 105)
        assert self.balance_of(8) == 0
