import math
import random
import unittest
from random import randint
from os import urandom
from ethereum import abi, tester
from ethereum.tester import TransactionFailed, ContractCreationFailed
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

MIGRATION_INIT = decode_hex(open('tests/MigrationAgent.bin', 'r').read().rstrip())
MIGRATION_ABI = open('tests/MigrationAgent.abi', 'r').read()

TARGET_INIT = decode_hex(open('tests/GNTTargetToken.bin', 'r').read().rstrip())
TARGET_ABI = open('tests/GNTTargetToken.abi', 'r').read()

WALLET_INIT = decode_hex(open('tests/BadWallet.bin', 'r').read().rstrip())
WALLET_ABI = open('tests/BadWallet.abi', 'r').read()


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

    def deploy_wallet(self, _founder, creator_idx=9):
        assert not hasattr(self, 'c')
        owner = self.monitor(creator_idx)
        t = abi.ContractTranslator(WALLET_ABI)
        args = t.encode_constructor_arguments([])
        addr = self.state.evm(WALLET_INIT + args,
                              sender=owner.key)
        self.wallet = tester.ABIContract(self.state, WALLET_ABI, addr)

        return addr, owner.gas()

    def deploy_contract_on_wallet(self, wallet_addr, start, end):
        c_addr = self.wallet.deploy_contract(wallet_addr, start, end)
        self.c = tester.ABIContract(self.state, GNT_ABI, c_addr)
        return c_addr

    def deploy_migration_contract(self, source_contract, creator_idx=9):
        owner = self.monitor(creator_idx)
        t = abi.ContractTranslator(MIGRATION_ABI)
        args = t.encode_constructor_arguments([source_contract])
        addr = self.state.evm(MIGRATION_INIT + args,
                              sender=owner.key)
        self.m = tester.ABIContract(self.state, MIGRATION_ABI, addr)
        return addr, owner.gas()

    def deploy_target_contract(self, migration_contract, creator_idx=9):
        owner = self.monitor(creator_idx)
        t = abi.ContractTranslator(TARGET_ABI)
        args = t.encode_constructor_arguments([migration_contract])
        addr = self.state.evm(TARGET_INIT + args,
                              sender=owner.key)
        self.t = tester.ABIContract(self.state, TARGET_ABI, addr)
        return addr, owner.gas()

    def test_wallet_deploy(self):
        founder = tester.accounts[9]
        key = tester.keys[9]
        wallet_addr, _ = self.deploy_wallet(founder)
        c_addr = self.deploy_contract_on_wallet(wallet_addr, 1, 1)
        self.state.mine(1)

    def test_payment_to_wallet(self):
        founder = tester.accounts[9]
        key = tester.keys[9]
        wallet_addr, _ = self.deploy_wallet(founder)
        self.state.mine(1)
        value = 11000
        self.state.send(tester.keys[0], wallet_addr, value)
        initial_b = self.state.block.get_balance(wallet_addr)
        self.state.send(tester.keys[0], wallet_addr, value)
        self.state.mine(1)
        current_b = self.state.block.get_balance(wallet_addr)
        assert current_b == initial_b + value

    def test_wallet_looping_in_payable(self):
        founder = tester.accounts[9]
        key = tester.keys[9]
        wallet_addr, g0 = self.deploy_wallet(founder)
        assert 0 == self.wallet.get_out_i(sender=key)
        self.wallet.set_extra_work(1, sender=key)
        extra = 10 # 601 passes, 602 fails send
        value = 11000
        self.wallet.set_extra_work(extra);
        self.state.mine(1)
        initial_b = self.state.block.get_balance(wallet_addr)
        self.state.send(tester.keys[0], wallet_addr, value)
        self.state.mine(1)
        current_b = self.state.block.get_balance(wallet_addr)
        assert extra == self.wallet.get_out_i(sender=key)
        assert current_b == initial_b + value

    def test_good_wallet(self):
        founder = tester.accounts[9]
        key = tester.keys[9]
        wallet_addr, g0 = self.deploy_wallet(founder)
        c_addr = self.deploy_contract_on_wallet(wallet_addr, 1, 1)
        value = 1 * denoms.szabo
        self.state.mine(1)
        self.state.send(tester.k1, c_addr, value)
        self.state.mine(3)
        extra = 0
        self.wallet.set_extra_work(extra);
        assert extra == self.wallet.get_extra_work();
        initial_b = self.state.block.get_balance(wallet_addr)
        self.wallet.finalize(c_addr, sender=key)
        self.state.mine(1)
        current_b = self.state.block.get_balance(wallet_addr)
        assert current_b == initial_b + value
        assert extra == self.wallet.get_out_i(sender=key)

    def test_bad_wallet(self):
        founder = tester.accounts[9]
        key = tester.keys[9]
        wallet_addr, g0 = self.deploy_wallet(founder)
        c_addr = self.deploy_contract_on_wallet(wallet_addr, 1, 1)
        value = 1000 * denoms.ether
        self.state.mine(1)
        self.state.send(tester.k1, c_addr, value)
        self.state.mine(3)
        extra = 1
        self.wallet.set_extra_work(extra);
        assert extra == self.wallet.get_extra_work();
        initial_wb = self.state.block.get_balance(wallet_addr)
        initial_fb = self.state.block.get_balance(founder)
        with self.assertRaises(TransactionFailed):
            self.wallet.finalize(c_addr, sender=key)
        self.state.mine(1)
        current_wb = self.state.block.get_balance(wallet_addr)
        current_fb = self.state.block.get_balance(founder)
        assert 0 == self.wallet.get_out_i(sender=key) # OK
        assert current_wb == initial_wb
        assert current_fb < initial_fb

    def contract_balance(self):
        return self.state.block.get_balance(self.c.address)

    def balance_of(self, addr_idx):
        return self.c.balanceOf(tester.accounts[addr_idx])

    def transfer(self, sender, to, value):
        return self.c.transfer(to, value, sender=sender)

    def test_initial_balance(self):
        founder = tester.accounts[8]
        self.deploy_contract(founder, 5, 105)
        assert self.balance_of(8) == 0

    def test_deployment(self):
        founder = tester.accounts[2]
        c, g = self.deploy_contract(founder, 5, 105)
        assert len(c) == 20
        assert g <= 800000
        assert self.contract_balance() == 0
        assert decode_hex(self.c.golemFactory()) == founder
        assert not self.c.fundingOngoing()

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
        assert self.c.totalSupply() == 6611000
        self.state.send(tester.keys[0], addr, 389)
        assert self.c.totalSupply() == 7000000
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.keys[0], addr, 0)
        assert self.c.totalSupply() == 7000000
        self.state.send(tester.keys[7], addr, 1)
        assert self.c.totalSupply() == 7001000
        self.state.mine(3)
        assert self.c.totalSupply() == 7001000
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.keys[7], addr, 10)
        supplyBeforeEndowment = self.c.totalSupply()
        assert supplyBeforeEndowment == 7001000
        self.c.finalizeFunding(sender=tester.keys[7])
        supplyAfterEndowment = self.c.totalSupply()
        endowmentPercent = (supplyAfterEndowment - supplyBeforeEndowment) \
            / float(supplyAfterEndowment)
        epsilon = 0.0001
        assert endowmentPercent < 0.18 + epsilon
        assert endowmentPercent > 0.18 - epsilon
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.keys[1], addr, 10)
        assert self.c.totalSupply() == supplyAfterEndowment

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
        numTokensCreated = value * self.c.tokenCreationRate()
        assert self.c.numberOfTokensLeft() == tokens_max - numTokensCreated
        assert self.c.totalSupply() == numTokensCreated

        self.state.send(tester.k2, c_addr, value)
        assert self.c.numberOfTokensLeft() == tokens_max - 2 * numTokensCreated
        assert self.c.totalSupply() == 2 * numTokensCreated

        value_max = tokens_max / self.c.tokenCreationRate()
        self.state.send(tester.k1, c_addr, value_max - 3 * value)
        assert self.c.numberOfTokensLeft() == numTokensCreated
        assert self.c.totalSupply() == tokens_max - numTokensCreated

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

    # Check if the transfer() is locked during the funding period.
    def test_transfer_locked(self):
        addr, _ = self.deploy_contract(tester.a0, 1, 1)

        assert not self.c.fundingOngoing()
        assert not self.c.transferEnabled()

        self.state.mine(1)
        assert self.c.fundingOngoing()
        value = 113 * denoms.szabo
        tokens = value * self.c.tokenCreationRate()
        # Create tokens for 1 ether.
        self.state.send(tester.k1, addr, value)
        assert self.balance_of(1) == tokens

        # At this point a1 has GNT but cannot frasfer them.
        assert not self.c.transferEnabled()
        assert self.transfer(tester.k1, tester.a2, tokens) is False

        # Funding has ended.
        self.state.mine(1)
        assert self.c.transferEnabled()
        assert self.transfer(tester.k1, tester.a2, tokens) is True
        assert self.balance_of(1) == 0
        assert self.balance_of(2) == tokens

    def test_migration(self):
        s_addr, _ = self.deploy_contract(tester.a9, 2, 2)
        source = self.c
        eths = 3 * denoms.ether

        # pre funding
        self.state.mine(1)
        with self.assertRaises(ContractCreationFailed):
            _1, _2 = self.deploy_migration_contract(s_addr)

        assert not source.migrationEnabled()

        # funding
        self.state.mine(1)
        self.state.send(tester.k1, s_addr, eths)

        with self.assertRaises(ContractCreationFailed):
            _1, _2 = self.deploy_migration_contract(s_addr)

        assert not source.migrationEnabled()

        creation_rate = source.tokenCreationRate()
        value = eths * creation_rate

        # post funding
        self.state.mine(1)

        with self.assertRaises(ContractCreationFailed):
            _1, _2 = self.deploy_migration_contract(s_addr)

        assert not source.migrationEnabled()

        self._finalize_funding(s_addr, expected_supply=value)

        # migration and target token contracts
        # funding _should_ already be over (target amount of GNT)
        m_addr, _ = self.deploy_migration_contract(s_addr)
        t_addr, _ = self.deploy_target_contract(m_addr)

        migration = self.m
        target = self.t

        source.setMigrationAgent(m_addr, sender=tester.k9)
        migration.setTargetToken(t_addr, sender=tester.k9)

        assert source.migrationEnabled()
        assert source.balanceOf(tester.a1) == value
        assert target.balanceOf(tester.a1) == 0

        with self.assertRaises(TransactionFailed):
            source.migrate(0, sender=tester.k1)

        with self.assertRaises(TransactionFailed):
            source.migrate(value + 1, sender=tester.k1)

        with self.assertRaises(TransactionFailed):
            source.migrate(value, sender=tester.k2)

        source.migrate(value, sender=tester.k1)

        with self.assertRaises(TransactionFailed):
            source.migrate(value, sender=tester.k1)

        assert source.balanceOf(tester.a1) == 0
        assert target.balanceOf(tester.a1) == value

        with self.assertRaises(TransactionFailed):
            source.migrate(value, sender=tester.k1)

        # finalize migration
        migration.finalizeMigration(sender=tester.k9)

        with self.assertRaises(TransactionFailed):
            migration.finalizeMigration(sender=tester.k9)

    def test_multiple_migrations(self):
        s_addr, _ = self.deploy_contract(tester.a9, 1, 1)
        n_accounts = len(tester.accounts) - 1

        values = [0] * n_accounts

        # funding
        self.state.mine(1)

        # testers purchase tokens
        for i in range(0, n_accounts):
            value = random.randrange(10, 1000) * denoms.ether
            self.state.send(tester.keys[i], s_addr, value)
            values[i] += value

        total = sum(values)
        source = self.c
        creation_rate = source.tokenCreationRate()

        assert source.totalSupply() == total * creation_rate

        # post funding
        self.state.mine(1)

        self._finalize_funding(s_addr, expected_supply=total * creation_rate)
        # additional tokens are generated for the golem agent and devs
        supply_after_finalization = source.totalSupply()

        m_addr, _ = self.deploy_migration_contract(s_addr)
        t_addr, _ = self.deploy_target_contract(m_addr)

        migration = self.m
        target = self.t

        source.setMigrationAgent(m_addr, sender=tester.k9)
        migration.setTargetToken(t_addr, sender=tester.k9)

        assert supply_after_finalization > total * creation_rate
        assert target.totalSupply() == 0

        # testers migrate tokens in parts
        for j in range(0, 10):
            for i in range(0, n_accounts):
                value = creation_rate * values[i] / 10
                source.migrate(value, sender=tester.keys[i])
                assert target.balanceOf(tester.accounts[i]) == value * (j + 1)

        migration.finalizeMigration(sender=tester.k9)

        assert source.totalSupply() == supply_after_finalization - total * creation_rate
        assert target.totalSupply() == total * creation_rate

    def test_number_of_tokens_left(self):
        addr, _ = self.deploy_contract(tester.a0, 13, 42)
        rate = self.c.tokenCreationRate()

        self.state.mine(13)
        tokens_max = self.c.numberOfTokensLeft()
        self.state.send(tester.k1, addr, tokens_max / rate / 2)
        assert self.c.numberOfTokensLeft() > 0

        self.state.mine(42 - 13 + 1)
        assert self.c.numberOfTokensLeft() == 0

    def test_send_raw_data_no_value(self):
        random_data = urandom(4)
        print("RANDOM DATA: {}".format(random_data.encode('hex')))
        addr, _ = self.deploy_contract(tester.a9, 7, 9)

        assert self.c.totalSupply() == 0
        assert self.contract_balance() == 0

        with self.assertRaises(TransactionFailed):
            self.state.send(tester.k3, addr, value=0, evmdata=random_data)
        assert self.c.totalSupply() == 0
        assert self.contract_balance() == 0

        self.state.mine(7)
        assert self.c.fundingOngoing()
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.k3, addr, value=0, evmdata=random_data)
        assert self.c.totalSupply() == 0
        assert self.contract_balance() == 0

        self.state.mine(3)
        assert not self.c.fundingOngoing()
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.k3, addr, value=0, evmdata=random_data)
        assert self.c.totalSupply() == 0
        assert self.contract_balance() == 0

    def test_send_raw_data_and_value(self):
        random_data = urandom(4)
        print("RANDOM DATA: {}".format(random_data.encode('hex')))
        addr, _ = self.deploy_contract(tester.a9, 7, 9)

        max_value = self.c.numberOfTokensLeft() / self.c.tokenCreationRate()
        random_value = randint(0, max_value)
        print("RANDOM VALUE: {}".format(random_value))

        assert self.c.totalSupply() == 0
        assert self.contract_balance() == 0

        with self.assertRaises(TransactionFailed):
            self.state.send(tester.k3, addr, random_value, evmdata=random_data)
        assert self.c.totalSupply() == 0
        assert self.contract_balance() == 0

        self.state.mine(7)
        assert self.c.fundingOngoing()
        self.state.send(tester.k3, addr, random_value, evmdata=random_data)
        assert self.c.totalSupply() == random_value * self.c.tokenCreationRate()
        assert self.contract_balance() == random_value

        self.state.mine(3)
        assert not self.c.fundingOngoing()
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.k4, addr, random_value, evmdata=random_data)
        assert self.c.totalSupply() == random_value * self.c.tokenCreationRate()
        assert self.contract_balance() == random_value

    def test_send_value_through_other_function(self):
        addr, _ = self.deploy_contract(tester.a0, 17, 19)

        with self.assertRaises(TransactionFailed):
            self.c.totalSupply(value=13, sender=tester.k0)
        assert self.contract_balance() == 0

        with self.assertRaises(TransactionFailed):
            self.c.tokenCreationRate(value=13000000, sender=tester.k0)
        assert self.contract_balance() == 0

    def test_finalize_funding(self):
        addr, _ = self.deploy_contract(tester.a9, 2, 2)

        # private properties ->
        n_devs = 6
        ca_percent = 12
        devs_percent = 6
        sum_percent = ca_percent + devs_percent
        # <- private properties

        ca = self.c.golemFactory()
        creation_rate = self.c.tokenCreationRate()

        # -- before funding
        self.state.mine(1)

        with self.assertRaises(TransactionFailed):
            self.c.finalizeFunding()

        # -- during funding
        self.state.mine(1)

        n_testers = len(tester.accounts) - 1
        eths = [(i + 1) * 100 * denoms.ether for i in xrange(n_testers)]
        for i, e in enumerate(eths):
            self.state.send(tester.keys[i], addr, e)
            assert self.c.balanceOf(tester.accounts[i]) == creation_rate * e

        with self.assertRaises(TransactionFailed):
            self.c.finalizeFunding()

        # -- post funding
        self.state.mine(1)

        total_tokens = self.c.totalSupply()
        assert total_tokens == sum(eths) * creation_rate

        # finalize
        self.c.finalizeFunding()
        with self.assertRaises(TransactionFailed):
            self.c.finalizeFunding()

        # verify values
        dev_addrs = []
        for i in xrange(n_devs):
            method = getattr(self.c, 'dev{}'.format(i))
            dev_addrs.append(method())

        dev_percent = []
        for i in xrange(n_devs - 1):
            method = getattr(self.c, 'dev{}Percent'.format(i))
            dev_percent.append(method())

        last_dev_percent = 100 - sum(dev_percent)
        assert last_dev_percent > 0
        dev_percent.append(last_dev_percent)

        tokens_extra = total_tokens * sum_percent / (100 - sum_percent)
        tokens_ca = tokens_extra * ca_percent / sum_percent
        tokens_devs = tokens_extra - tokens_ca

        print "Total tokens:\t{}".format(total_tokens)
        print "Extra tokens:\t{}".format(tokens_extra)
        print "CA tokens:\t {}".format(tokens_ca)
        print "Dev tokens:\t {}".format(tokens_devs)
        print "Devs", dev_addrs, dev_percent

        # aux verification sum
        ver_sum = 0

        def error(val, n=3):
            magnitude = int(math.log10(val))
            return val / (10 ** (magnitude - n))

        for i in xrange(n_devs):
            expected = dev_percent[i] * tokens_devs / 100
            ver_sum += expected
            err = error(expected)
            assert expected - err <= self.c.balanceOf(dev_addrs[i]) <= expected + err

        err = error(ver_sum)
        assert ver_sum - err <= tokens_devs <= ver_sum + err

        ca_balance = self.c.balanceOf(ca)
        assert ca_balance == tokens_ca

        ver_sum += ca_balance
        err = error(ver_sum)
        assert ver_sum - err <= self.c.totalSupply() - total_tokens <= ver_sum + err

    # assumes post funding period
    def _finalize_funding(self, addr, expected_supply):
        assert self.c.totalSupply() == expected_supply
        self.c.finalizeFunding()
        assert self.c.totalSupply() > expected_supply
        with self.assertRaises(TransactionFailed):
            self.c.finalizeFunding()
