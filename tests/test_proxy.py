import os
import unittest

from ethereum import abi
from ethereum import tester
from ethereum.config import default_config
from ethereum.tester import TransactionFailed
from ethereum.utils import denoms
from rlp.utils_py2 import decode_hex

from test_gnt import ContractHelper, deploy_gnt

GNT_CONTRACT_PATH = os.path.join('contracts', 'Token.sol')
ALLOC_CONTRACT_PATH = os.path.join('contracts', 'GNTAllocation.sol')

IMPORT_TOKEN_REGEX = '(import "\.\/Token\.sol";).*'
IMPORT_ALLOC_REGEX = '(import "\.\/GNTAllocation\.sol";).*'
DEV_ADDR_REGEX = "\s*allocations\[([a-zA-Z0-9]+)\].*"

PROXY_INIT = decode_hex(open('tests/ProxyAccount.bin', 'r').read().rstrip())
PROXY_ABI = open('tests/ProxyAccount.abi', 'r').read()

PROXY_FACTORY_INIT = decode_hex(open('tests/ProxyFactoryAccount.bin', 'r').read().rstrip())
PROXY_FACTORY_ABI = open('tests/ProxyFactoryAccount.abi', 'r').read()

MIGRATION_INIT = decode_hex(open('tests/MigrationAgent.bin', 'r').read().rstrip())
MIGRATION_ABI = open('tests/MigrationAgent.abi', 'r').read()

TARGET_INIT = decode_hex(open('tests/GNTTargetToken.bin', 'r').read().rstrip())
TARGET_ABI = open('tests/GNTTargetToken.abi', 'r').read()

gwei = 10 ** 9

tester.gas_limit = int(1.9 * 10 ** 6)
tester.gas_price = int(22.5 * gwei)


class GNTCrowdfundingTest(unittest.TestCase):

    def setUp(self):
        self.state = tester.state()
        self.starting_block = default_config.get('ANTI_DOS_FORK_BLKNUM') + 1
        self.state.block.number = self.starting_block

        available_after = self.state.block.timestamp + 1000

        self.pd0, self.addr_pd0, _ = self.__deploy_proxy(available_after, creator_idx=0)
        self.pd1, self.addr_pd1, _ = self.__deploy_proxy(available_after, creator_idx=1)
        self.pd2, self.addr_pd2, _ = self.__deploy_proxy(available_after, creator_idx=2)

        self.pf, self.founder, _ = self.__deploy_factory_proxy(available_after)

        dev_addresses = [ContractHelper.dev_address(a) for a in [
            self.addr_pd0,
            self.addr_pd1,
            self.addr_pd2
        ]]

        self.contract, self.c_addr, _ = deploy_gnt(self.state, self.founder, dev_addresses, 2, 3)

        self.creation_min = self.contract.tokenCreationMin()
        self.creation_rate = self.contract.tokenCreationRate()
        self.transfer_value = denoms.ether * self.creation_rate
        self.eth_part = int(self.creation_min / (3 * self.creation_rate)) + 1 * denoms.ether

        self.founder_key = tester.keys[9]

    def __deploy_proxy(self, available_after, creator_idx=9):
        return self.__deploy_contract(PROXY_INIT, PROXY_ABI, creator_idx, available_after)

    def __deploy_factory_proxy(self, available_after, creator_idx=9):
        return self.__deploy_contract(PROXY_FACTORY_INIT, PROXY_FACTORY_ABI, creator_idx, available_after)

    def __deploy_contract(self, _bin, _abi, creator_idx, *args):
        gas_before = self.state.block.gas_used

        t = abi.ContractTranslator(_abi)
        args = t.encode_constructor_arguments(args)
        addr = self.state.evm(_bin + args,
                              sender=tester.keys[creator_idx])
        contract = tester.ABIContract(self.state, _abi, addr)

        return contract, addr, self.state.block.gas_used - gas_before

    def test_transfer(self):

        founder_key = tester.keys[9]
        founder_balance_initial = self.state.block.get_balance(self.founder)
        c_addr_hex = self.c_addr.encode('hex')

        assert self.contract.golemFactory() == self.founder.encode('hex')
        assert self.founder != tester.accounts[9]
        assert self.pf.owner() == tester.accounts[9].encode('hex')

        # Fail: proxy payable
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.keys[8], self.addr_pd0, 1 * denoms.ether)

        # Fail: factory_proxy payable | gntOnly
        with self.assertRaises(TransactionFailed):
            self.state.send(tester.keys[8], self.founder, 1 * denoms.ether)

        # ---------------
        #   PRE FUNDING
        # ---------------
        self.state.mine(1)

        # Fail: proxy.transfer | gnt != 0
        with self.assertRaises(TransactionFailed):
            self.pd0.transfer(tester.accounts[8], self.transfer_value, sender=tester.keys[0])
        with self.assertRaises(TransactionFailed):
            self.pf.transfer(tester.accounts[8], self.transfer_value, sender=founder_key)

        # Fail: proxy.setGNTContract | ownerOnly
        with self.assertRaises(TransactionFailed):
            self.pd0.setGNTContract(self.c_addr, sender=tester.keys[2])

        self.pd0.setGNTContract(self.c_addr, sender=tester.keys[0])
        self.pd1.setGNTContract(self.c_addr, sender=tester.keys[1])
        self.pd2.setGNTContract(self.c_addr, sender=tester.keys[2])
        self.pf.setGNTContract(self.c_addr, sender=founder_key)

        assert self.pd0.gnt() == c_addr_hex
        assert self.pd1.gnt() == c_addr_hex
        assert self.pd2.gnt() == c_addr_hex
        assert self.pf.gnt() == c_addr_hex

        # Fail: gnt.transfer | notLocked
        with self.assertRaises(TransactionFailed):
            self.pd0.transfer(tester.accounts[8], self.transfer_value, sender=tester.keys[0])
        with self.assertRaises(TransactionFailed):
            self.pf.transfer(tester.accounts[8], self.transfer_value, sender=founder_key)

        # ---------------
        #     FUNDING
        # ---------------
        self.state.mine(1)

        # Send creation_min+ to the GNT contract
        self.contract.mint(sender=tester.keys[3], value=self.eth_part)
        self.contract.mint(sender=tester.keys[4], value=self.eth_part)
        self.contract.mint(sender=tester.keys[5], value=self.eth_part)

        # Fail: gnt.transfer | notLocked
        with self.assertRaises(TransactionFailed):
            self.pd0.transfer(tester.accounts[8], self.transfer_value, sender=tester.keys[0])
        with self.assertRaises(TransactionFailed):
            self.pf.transfer(tester.accounts[8], self.transfer_value, sender=founder_key)

        account9_balance_initial = self.state.block.get_balance(tester.accounts[9])

        # ---------------
        #  POST FUNDING
        # ---------------
        self.state.mine(2)

        self.contract.finalize()

        assert self.state.block.get_balance(self.founder) > founder_balance_initial
        assert self.state.block.get_balance(tester.accounts[9]) == account9_balance_initial

        # Fail: gnt.transfer | notLocked
        with self.assertRaises(TransactionFailed):
            self.pd0.transfer(tester.accounts[8], self.transfer_value, sender=tester.keys[0])
        with self.assertRaises(TransactionFailed):
            self.pf.transfer(tester.accounts[8], self.transfer_value, sender=founder_key)

        # ---------------
        #    UNLOCKED
        # ---------------
        # Advance time
        self.state.block.timestamp += 1000

        # Fail: gnt.transfer | ownerOnly
        with self.assertRaises(TransactionFailed):
            self.pd0.transfer(tester.accounts[8], self.transfer_value, sender=tester.keys[2])
        with self.assertRaises(TransactionFailed):
            self.pf.transfer(tester.accounts[8], self.transfer_value, sender=tester.keys[2])

        # gnt_pd0 = self.contract.balanceOf(self.addr_pd0)
        # gnt_pf = self.contract.balanceOf(self.founder)

        self.pd0.transfer(tester.accounts[8], self.transfer_value, sender=tester.keys[0])
        self.pf.transfer(tester.accounts[8], self.transfer_value, sender=founder_key)

        # assert self.contract.balanceOf(tester.accounts[8]) == 2 * self.transfer_value
        # assert self.contract.balanceOf(self.addr_pd0) == gnt_pd0 - self.transfer_value
        # assert self.contract.balanceOf(self.founder) == gnt_pf - self.transfer_value

    def test_withdraw(self):

        founder_balance_initial = self.state.block.get_balance(self.founder)
        account9_balance_initial = self.state.block.get_balance(tester.accounts[9])

        # ---------------
        #   PRE FUNDING
        # ---------------
        self.state.mine(1)

        # Fail: gnt.withdraw | ownerOnly
        with self.assertRaises(TransactionFailed):
            self.pf.withdraw(sender=tester.keys[0])

        # Success (balance == 0)
        self.pf.withdraw(sender=self.founder_key)
        assert self.state.block.get_balance(self.founder) == founder_balance_initial

        # ---------------
        #     FUNDING
        # ---------------
        self.state.mine(1)

        # Send creation_min+ to the GNT contract
        self.contract.mint(sender=tester.keys[3], value=self.eth_part * 2)
        self.contract.mint(sender=tester.keys[4], value=self.eth_part * 2)
        self.contract.mint(sender=tester.keys[5], value=self.eth_part * 2)

        # Success (balance == 0)
        self.pf.withdraw(sender=self.founder_key)
        assert self.state.block.get_balance(self.founder) == founder_balance_initial

        # ---------------
        #  POST FUNDING
        # ---------------
        self.state.mine(2)

        # Fail: gnt == 0
        with self.assertRaises(TransactionFailed):
            self.contract.finalize()

        self.pf.setGNTContract(self.c_addr, sender=self.founder_key)
        self.contract.finalize()

        to_withdraw = self.state.block.get_balance(self.founder)
        assert to_withdraw > 0

        # Success (balance > 0)
        self.pf.withdraw(sender=self.founder_key)

        assert self.state.block.get_balance(self.founder) == 0
        assert self.state.block.get_balance(tester.accounts[9]) > account9_balance_initial
        assert self.state.block.get_balance(tester.accounts[9]) <= account9_balance_initial + to_withdraw

    def test_migration_master_and_migration_agent(self):
        # ---------------
        #   PRE FUNDING
        # ---------------
        self.state.mine(1)

        # gnt.setMigrationMaster | inOperational
        with self.assertRaises(TransactionFailed):
            self.pf.setMigrationMaster(tester.accounts[7], sender=self.founder_key)

        # gnt.setMigrationAgent | inNormal
        with self.assertRaises(TransactionFailed):
            self.pf.setMigrationAgent(tester.accounts[7], sender=self.founder_key)

        # ---------------
        #     FUNDING
        # ---------------
        self.state.mine(1)

        # Send creation_min+ to the GNT contract
        self.contract.mint(sender=tester.keys[3], value=self.eth_part)
        self.contract.mint(sender=tester.keys[4], value=self.eth_part)
        self.contract.mint(sender=tester.keys[5], value=self.eth_part)

        # gnt.setMigrationMaster | inOperational
        with self.assertRaises(TransactionFailed):
            self.pf.setMigrationMaster(tester.accounts[7], sender=self.founder_key)

        # ---------------
        #  POST FUNDING
        # ---------------
        self.state.mine(2)

        self.pf.setGNTContract(self.c_addr, sender=self.founder_key)
        self.contract.finalize()

        # Fail: proxy.setMigrationAgent | ownerOnly
        with self.assertRaises(TransactionFailed):
            self.pf.setMigrationAgent(tester.accounts[7], sender=tester.keys[7])

        assert self.contract.migrationAgent() == '0' * 40
        self.pf.setMigrationAgent(tester.accounts[7], sender=self.founder_key)

        # Fail: proxy.setMigrationAgent | inNormal
        with self.assertRaises(TransactionFailed):
            self.pf.setMigrationAgent(tester.accounts[7], sender=self.founder_key)

        # Fail: proxy.setMigrationMaster | ownerOnly
        with self.assertRaises(TransactionFailed):
            self.pf.setMigrationMaster(tester.accounts[7], sender=tester.keys[7])

        self.pf.setMigrationMaster(tester.accounts[7], sender=self.founder_key)

    def test_migration(self):
        # ---------------
        #     FUNDING
        # ---------------
        self.state.mine(2)

        # Send creation_min+ to the GNT contract
        self.contract.mint(sender=tester.keys[3], value=self.eth_part)
        self.contract.mint(sender=tester.keys[4], value=self.eth_part)
        self.contract.mint(sender=tester.keys[5], value=self.eth_part)

        total_tokens = self.contract.totalSupply()

        # ---------------
        #  POST FUNDING
        # ---------------
        self.state.mine(2)

        self.pd0.setGNTContract(self.c_addr, sender=tester.keys[0])
        self.pf.setGNTContract(self.c_addr, sender=self.founder_key)

        self.contract.finalize()

        assert self.contract.balanceOf(self.addr_pd0) == 0
        # assert self.contract.balanceOf(self.addr_pd0) > 0

        # ---------------
        #    IN NORMAL
        # ---------------
        migration, m_addr, _ = self.__deploy_contract(MIGRATION_INIT, MIGRATION_ABI, 9, self.c_addr)
        target, t_addr, _ = self.__deploy_contract(TARGET_INIT, TARGET_ABI, 9, m_addr)

        # extra_tokens = self.contract.totalSupply() - total_tokens
        # approx_min_tokens = int(extra_tokens / 30.)
        # balance_pd0 = self.contract.balanceOf(self.addr_pd0)

        self.pf.setMigrationAgent(m_addr, sender=self.founder_key)

        # ---------------
        #  IN MIGRATION
        # ---------------
        migration.setTargetToken(t_addr, sender=self.founder_key)

        # assert approx_min_tokens < balance_pd0 < extra_tokens
        # assert self.contract.balanceOf(tester.accounts[0]) == 0
        # assert target.balanceOf(tester.accounts[0]) == 0
        #
        # with self.assertRaises(TransactionFailed):
        #     self.pd0.migrate(extra_tokens, sender=tester.keys[1])
        #
        # assert self.contract.balanceOf(self.addr_pd0) == balance_pd0
        # assert self.contract.balanceOf(tester.accounts[0]) == 0
        # assert target.balanceOf(tester.accounts[0]) == 0
        #
        # self.pd0.migrate(balance_pd0, sender=tester.keys[0])
        #
        # assert self.contract.balanceOf(tester.accounts[0]) == 0
        # assert target.balanceOf(tester.accounts[0]) == 0
        # assert target.balanceOf(self.addr_pd0) == balance_pd0
