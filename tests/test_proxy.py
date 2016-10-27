import os
import re
import unittest
from contextlib import contextmanager

from ethereum import abi
from ethereum import tester
from ethereum.tester import TransactionFailed
from ethereum.utils import denoms
from rlp.utils_py2 import decode_hex

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


@contextmanager
def work_dir_context(file_path):
    cwd = os.getcwd()
    file_name = os.path.basename(file_path)
    rel_dir = os.path.dirname(file_path) or '.'
    dir_name = os.path.abspath(rel_dir)

    os.chdir(dir_name)
    yield file_name
    os.chdir(cwd)


class ContractHelper(object):
    """
    Tools for replacing strings in contract (regex). Default behaviour: replace developer addresses
    """

    def __init__(self, contract_path, regex=None):
        if not regex:
            regex = DEV_ADDR_REGEX

        self.regex = re.compile(regex)
        self.contract_path = contract_path

        with work_dir_context(contract_path) as file_name:
            self.source = open(file_name).read().rstrip()

    def findall(self, regex=None):
        return self._re(regex).findall(self.source)

    def sub(self, replacements, regex=None):
        i = [-1]

        def replace(m):
            i[0] += 1
            if i[0] < len(replacements):
                return m.group(0).replace(m.group(1), replacements[i[0]])
            return m.group(0)

        self.source = self._re(regex).sub(replace, self.source)

    def _re(self, regex):
        if regex:
            return re.compile(regex)
        return self.regex

    @staticmethod
    def dev_address(addr):
        return '0x' + addr.encode('hex')


class GNTCrowdfundingTest(unittest.TestCase):

    def setUp(self):
        self.state = tester.state()

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

        self.contract, self.c_addr, _ = self.__deploy_gnt(self.founder, dev_addresses, 2, 2)

        self.creation_min = self.contract.tokenCreationMin()
        self.creation_rate = self.contract.tokenCreationRate()
        self.transfer_value = denoms.ether * self.creation_rate
        self.eth_part = int(self.creation_min / (3 * self.creation_rate)) + 1 * denoms.ether

        self.founder_key = tester.keys[9]

    def __deploy_gnt(self, founder, dev_addresses, start, end, creator_idx=9):

        alloc_helper = ContractHelper(ALLOC_CONTRACT_PATH)
        # remove import
        alloc_helper.sub([''], regex=IMPORT_TOKEN_REGEX)
        # replace dev addresses
        alloc_helper.sub(dev_addresses)

        # replace import with contract source
        gnt_helper = ContractHelper(GNT_CONTRACT_PATH, regex=IMPORT_ALLOC_REGEX)
        gnt_helper.sub([alloc_helper.source])

        gas_before = self.state.block.gas_used

        with work_dir_context(gnt_helper.contract_path):
            contract = self.state.abi_contract(gnt_helper.source,
                                               language='solidity',
                                               sender=tester.keys[creator_idx],
                                               constructor_parameters=(founder, start, end))

        return contract, contract.address, self.state.block.gas_used - gas_before

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
        self.state.send(tester.keys[3], self.c_addr, self.eth_part)
        self.state.send(tester.keys[4], self.c_addr, self.eth_part)
        self.state.send(tester.keys[5], self.c_addr, self.eth_part)

        # Fail: gnt.transfer | notLocked
        with self.assertRaises(TransactionFailed):
            self.pd0.transfer(tester.accounts[8], self.transfer_value, sender=tester.keys[0])
        with self.assertRaises(TransactionFailed):
            self.pf.transfer(tester.accounts[8], self.transfer_value, sender=founder_key)

        account9_balance_initial = self.state.block.get_balance(tester.accounts[9])

        # ---------------
        #  POST FUNDING
        # ---------------
        self.state.mine(1)

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

        gnt_pd0 = self.contract.balanceOf(self.addr_pd0)
        gnt_pf = self.contract.balanceOf(self.founder)

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
        self.state.send(tester.keys[3], self.c_addr, self.eth_part * 2)
        self.state.send(tester.keys[4], self.c_addr, self.eth_part * 2)
        self.state.send(tester.keys[5], self.c_addr, self.eth_part * 2)

        # Success (balance == 0)
        self.pf.withdraw(sender=self.founder_key)
        assert self.state.block.get_balance(self.founder) == founder_balance_initial

        # ---------------
        #  POST FUNDING
        # ---------------
        self.state.mine(1)

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

    def test_change_factory_and_migration_agent(self):
        # ---------------
        #   PRE FUNDING
        # ---------------
        self.state.mine(1)

        # gnt.changeGolemFactory | inOperational
        with self.assertRaises(TransactionFailed):
            self.pf.changeGolemFactory(tester.accounts[7], sender=self.founder_key)

        # gnt.setMigrationAgent | inNormal
        with self.assertRaises(TransactionFailed):
            self.pf.setMigrationAgent(tester.accounts[7], sender=self.founder_key)

        # ---------------
        #     FUNDING
        # ---------------
        self.state.mine(1)

        # Send creation_min+ to the GNT contract
        self.state.send(tester.keys[3], self.c_addr, self.eth_part)
        self.state.send(tester.keys[4], self.c_addr, self.eth_part)
        self.state.send(tester.keys[5], self.c_addr, self.eth_part)

        # gnt.changeGolemFactory | inOperational
        with self.assertRaises(TransactionFailed):
            self.pf.changeGolemFactory(tester.accounts[7], sender=self.founder_key)

        # ---------------
        #  POST FUNDING
        # ---------------
        self.state.mine(1)

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

        # Fail: proxy.changeGolemFactory | ownerOnly
        with self.assertRaises(TransactionFailed):
            self.pf.changeGolemFactory(tester.accounts[7], sender=tester.keys[7])

        self.pf.changeGolemFactory(tester.accounts[7], sender=self.founder_key)

    def test_migration(self):
        # ---------------
        #     FUNDING
        # ---------------
        self.state.mine(2)

        # Send creation_min+ to the GNT contract
        self.state.send(tester.keys[3], self.c_addr, self.eth_part)
        self.state.send(tester.keys[4], self.c_addr, self.eth_part)
        self.state.send(tester.keys[5], self.c_addr, self.eth_part)

        total_tokens = self.contract.totalSupply()

        # ---------------
        #  POST FUNDING
        # ---------------
        self.state.mine(1)

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

        extra_tokens = self.contract.totalSupply() - total_tokens
        approx_min_tokens = int(extra_tokens / 30.)
        balance_pd0 = self.contract.balanceOf(self.addr_pd0)

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


class GNTContractHelperTest(unittest.TestCase):

    def test_sub(self):

        alloc_helper = ContractHelper(ALLOC_CONTRACT_PATH)
        # remove import
        alloc_helper.sub([''], regex=IMPORT_TOKEN_REGEX)

        print alloc_helper.findall()

        assert alloc_helper.findall()[:6] == ['0xde00', '0xde01', '0xde02', '0xde03', '0xde04', '0xde05']
        alloc_helper.sub(['0xad00', '0xad01', '0xad02'])
        assert alloc_helper.findall()[:6] == ['0xad00', '0xad01', '0xad02', '0xde03', '0xde04', '0xde05']

        # replace import with contract source
        gnt_helper = ContractHelper(GNT_CONTRACT_PATH, regex=IMPORT_ALLOC_REGEX)
        gnt_helper.sub([alloc_helper.source])

        state = tester.state()
        contract = state.abi_contract(gnt_helper.source, language='solidity', sender=tester.k0)

        import pprint
        pprint.pprint(dir(contract))

        assert contract

