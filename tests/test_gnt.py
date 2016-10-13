import unittest
from ethereum import abi, tester
from ethereum.exceptions import InvalidTransaction
from ethereum.tester import TransactionFailed
from ethereum.utils import denoms
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

    def transfer(self, sender, to, value):
        return self.c.transfer(to, value, sender=sender)

    def test_deployment(self):
        founder = tester.accounts[2]
        c, g = self.deploy_contract(founder, 5, 105)
        assert len(c) == 20
        assert g <= 850000
        assert self.contract_balance() == 0
        assert decode_hex(self.c.founder()) == founder
        assert not self.c.fundingOngoing()

    def test_initial_balance(self):
        founder = tester.accounts[8]
        self.deploy_contract(founder, 5, 105)
        assert self.balance_of(8) == 0

    def test_transfer_enabled_after_end_block(self):
        founder = tester.accounts[4]
        self.deploy_contract(founder, 3, 13)
        assert self.state.block.number == 0 
        assert not self.c.transferEnabled()
        for _ in range(13):
            self.state.mine()
            assert not self.c.transferEnabled()
        assert self.state.block.number == 13
        for _ in range(259):
            self.state.mine()
            assert self.c.transferEnabled()

    def test_transfer_enabled_after_max_fund_reached(self):
        founder = tester.accounts[2]
        addr, _ = self.deploy_contract(founder, 3, 7)
        assert not self.c.transferEnabled()
        for _ in range(3):
            self.state.mine()
            assert not self.c.transferEnabled()
        self.state.send(tester.keys[0], addr, 11)
        assert not self.c.transferEnabled()
        self.state.send(tester.keys[1], addr, 847457627118644067796600)
        assert self.c.transferEnabled()
        for _ in range(8):
            self.state.mine()
            assert self.c.transferEnabled()

    def test_total_supply(self):
        founder = tester.accounts[7]
        addr, _ = self.deploy_contract(founder, 2, 4)
        assert self.c.totalSupply() == 0
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.keys[3], addr, 6611)
        assert self.c.totalSupply() == 0
        self.state.mine(2)
        assert self.c.totalSupply() == 0
        self.state.send(tester.keys[3], addr, 6611)
        assert self.c.totalSupply() == 6611
        self.state.send(tester.keys[0], addr, 389)
        assert self.c.totalSupply() == 7000
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.keys[0], addr, 0)
        assert self.c.totalSupply() == 7000
        self.state.send(tester.keys[7], addr, 1)
        assert self.c.totalSupply() == 7001
        self.state.mine(3)
        assert self.c.totalSupply() == 7001
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.keys[7], addr, 10)
        assert self.c.totalSupply() == 7001
        self.c.finalizeFunding(sender=tester.keys[7])
        assert self.c.totalSupply() == 8537
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.keys[1], addr, 10)
        assert self.c.totalSupply() == 8537

    def test_payable_period(self):
        c_addr, _ = self.deploy_contract(tester.a0, 2, 2)
        value = 3 * denoms.ether

        # before funding
        self.state.mine(1)
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.k1, c_addr, value)

        # during funding
        self.state.mine(1)
        self.state.send(tester.k1, c_addr, value)

        # after funding
        self.state.mine(1)
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.k1, c_addr, value)

    def test_payable_amounts(self):
        c_addr, _ = self.deploy_contract(tester.a0, 1, 1)
        value = 3 * denoms.ether

        self.state.mine(1)

        tokens_max = self.c.numberOfTokensLeft()

        # invalid value
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.k1, c_addr, 0)

        # changing balance
        self.state.send(tester.k1, c_addr, value)
        assert self.c.numberOfTokensLeft() == tokens_max - value
        assert self.c.totalSupply() == value

        self.state.send(tester.k2, c_addr, value)
        assert self.c.numberOfTokensLeft() == tokens_max - 2 * value
        assert self.c.totalSupply() == 2 * value

        self.state.send(tester.k1, c_addr, tokens_max - 3 * value)
        assert self.c.numberOfTokensLeft() == value
        assert self.c.totalSupply() == tokens_max - value

        # more than available tokens
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.k2, c_addr, 2 * value)

        # exact amount of available tokens
        self.state.send(tester.k1, c_addr, value)
        assert self.c.numberOfTokensLeft() == 0
        assert self.c.totalSupply() == tokens_max

        # no tokens available
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.k2, c_addr, value)

    def test_transfer_from_allowances(self):
        c_addr, _ = self.deploy_contract(tester.a0, 1, 1)

        value_1 = 10 * denoms.ether
        value_2 = 3 * denoms.ether

        self.state.mine(1)
        self.state.send(tester.k1, c_addr, value_1)

        # Funds without allowance [1 -> 2]
        assert not self.c.transferFrom(tester.a1, tester.a2, value_2,
                                       sender=tester.k2)

        # Allowance without funds [4 -> 2]
        assert self.c.allowance(tester.a4, tester.a2) == 0
        assert self.c.approve(tester.a2, sender=tester.k4)
        assert not self.c.transferFrom(tester.a4, tester.a2, value_2,
                                       sender=tester.k2)

    def test_transfer_from_period(self):
        c_addr, _ = self.deploy_contract(tester.a0, 1, 1)

        value_1 = 10 * denoms.ether
        value_2 = 3 * denoms.ether

        self.state.mine(1)

        # During funding
        self.state.send(tester.k1, c_addr, value_1)

        assert self.balance_of(1) == value_1
        assert self.c.approve(tester.a2, value_2,
                              sender=tester.k1)

        assert self.c.allowance(tester.a1, tester.a2) == value_2
        assert not self.c.transferFrom(tester.a1, tester.a2, value_2,
                                       sender=tester.k2)
        # Funding ended
        self.state.mine(1)

        assert self.c.transferFrom(tester.a1, tester.a2, value_2,
                                   sender=tester.k2)
        assert self.c.allowance(tester.a1, tester.a2) == 0

        assert self.balance_of(1) == value_1 - value_2
        assert self.balance_of(2) == value_2

    # Check if the transfer() is locked during the funding period.
    def test_transfer_locked(self):
        addr, _ = self.deploy_contract(tester.a0, 1, 1)

        assert not self.c.fundingOngoing()
        assert not self.c.transferEnabled()

        self.state.mine(1)
        assert self.c.fundingOngoing()
        value = 1 * denoms.ether
        # Create tokens for 1 ether.
        self.state.send(tester.k1, addr, value)
        assert self.balance_of(1) == value

        # At this point a1 has GNT but cannot frasfer them.
        assert not self.c.transferEnabled()
        assert self.transfer(tester.k1, tester.a2, value) is False

        # Funding has ended.
        self.state.mine(1)
        assert self.c.transferEnabled()
        assert self.transfer(tester.k1, tester.a2, value) is True
        assert self.balance_of(1) == 0
        assert self.balance_of(2) == value
