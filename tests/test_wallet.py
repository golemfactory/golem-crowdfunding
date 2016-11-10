import unittest

from ethereum import abi
from ethereum import tester
from ethereum.config import default_config
from ethereum.tester import TransactionFailed
from ethereum.keys import decode_hex
from ethereum.utils import denoms

GNT_INIT = decode_hex(open('tests/GolemNetworkToken.bin', 'r').read().rstrip())
GNT_ABI = open('tests/GolemNetworkToken.abi', 'r').read()

WALLET_INIT = decode_hex(open('tests/MultiSigWallet.bin', 'r').read().rstrip())
WALLET_ABI = open('tests/MultiSigWallet.abi', 'r').read()

MIGRATION_INIT = decode_hex(open('tests/MigrationAgent.bin', 'r').read().rstrip())
MIGRATION_ABI = open('tests/MigrationAgent.abi', 'r').read()

TARGET_INIT = decode_hex(open('tests/GNTTargetToken.bin', 'r').read().rstrip())
TARGET_ABI = open('tests/GNTTargetToken.abi', 'r').read()

class GolemNetworkTokenWalletTest(unittest.TestCase):

    def setUp(self):
        self.state = tester.state()
        self.starting_block = default_config.get('SPURIOUS_DRAGON_FORK_BLKNUM') + 1
        self.state.block.number = self.starting_block

    def deploy_contract(self, start, end, creator_idx=9, migration_master=None, founder=None):
        if founder is None:
            founder = tester.accounts[creator_idx]
        if migration_master is None:
            migration_master = founder

        t = abi.ContractTranslator(GNT_ABI)
        args = t.encode_constructor_arguments((founder, migration_master,
                                               self.state.block.number + start,
                                               self.state.block.number + end))
        addr = self.state.evm(GNT_INIT + args,
                              sender=tester.keys[creator_idx])
        return tester.ABIContract(self.state, GNT_ABI, addr), t

    def __deploy_contract(self, _bin, _abi, creator_idx, *args):
        gas_before = self.state.block.gas_used

        t = abi.ContractTranslator(_abi)
        args = t.encode_constructor_arguments(args)
        addr = self.state.evm(_bin + args,
                              sender=tester.keys[creator_idx])
        contract = tester.ABIContract(self.state, _abi, addr)

        return contract, addr, self.state.block.gas_used - gas_before

    def __deploy_wallet(self, owner_key, owners, required=1):
        t = abi.ContractTranslator(WALLET_ABI)
        args = t.encode_constructor_arguments((owners, required))
        addr = self.state.evm(WALLET_INIT + args,
                              sender=owner_key)
        return tester.ABIContract(self.state, WALLET_ABI, addr), t

    def deploy_wallet(self, n_wallet_owners, required=1, creator_idx=0):
        _range = range(creator_idx, n_wallet_owners)
        wallet_owners = [tester.accounts[i] for i in _range]
        wallet_owner_keys = [tester.keys[i] for i in _range]
        wallet, t = self.__deploy_wallet(tester.keys[creator_idx], wallet_owners,
                                         required=required)
        return wallet, wallet_owners, wallet_owner_keys, t

    def test_owner_2of3_add_rem(self):
        n_wallet_owners = 3
        wallet, wallet_owners, wallet_owner_keys, translator = self.deploy_wallet(n_wallet_owners,
                                                                                  required=2)

        self.state.mine(1)

        new_acc = tester.accounts[9]

        assert not wallet.isOwner(new_acc)

        add_new = translator.encode_function_call('addOwner', [new_acc])
        wallet.submitTransaction(wallet.address, 0, add_new,
                                 10001, sender=tester.keys[0])
        wallet.submitTransaction(wallet.address, 0, add_new,
                                 10001, sender=tester.keys[1])

        assert wallet.isOwner(new_acc)

        self.state.mine(1)

        old_acc = tester.accounts[0]

        assert wallet.isOwner(old_acc)

        rem_old = translator.encode_function_call('removeOwner', [old_acc])
        wallet.submitTransaction(wallet.address, 0, rem_old,
                                 10001, sender=tester.keys[1])
        wallet.submitTransaction(wallet.address, 0, rem_old,
                                 10001, sender=tester.keys[9])

        assert not wallet.isOwner(old_acc)

    def test_owner_2of3_rem_add(self):
        n_wallet_owners = 3
        wallet, wallet_owners, wallet_owner_keys, translator = self.deploy_wallet(n_wallet_owners,
                                                                                  required=2)
        self.state.mine(1)

        old_acc = tester.accounts[0]
        assert wallet.isOwner(old_acc)

        rem_old = translator.encode_function_call('removeOwner', [old_acc])
        wallet.submitTransaction(wallet.address, 0, rem_old,
                                 10001, sender=tester.keys[1])
        wallet.submitTransaction(wallet.address, 0, rem_old,
                                 10001, sender=tester.keys[2])
        assert not wallet.isOwner(old_acc)

        self.state.mine(1)
        new_acc = tester.accounts[9]
        assert not wallet.isOwner(new_acc)
        add_new = translator.encode_function_call('addOwner', [new_acc])
        wallet.submitTransaction(wallet.address, 0, add_new,
                                 10001, sender=tester.keys[1])
        wallet.submitTransaction(wallet.address, 0, add_new,
                                 10001, sender=tester.keys[2])
        assert wallet.isOwner(new_acc)

    def test_owner_3of5_add_rem(self):
        n_wallet_owners = 5
        wallet, wallet_owners, wallet_owner_keys, translator = self.deploy_wallet(n_wallet_owners,
                                                                                  required=3)

        self.state.mine(1)

        new_acc = tester.accounts[9]

        assert not wallet.isOwner(new_acc)

        add_new = translator.encode_function_call('addOwner', [new_acc])
        wallet.submitTransaction(wallet.address, 0, add_new,
                                 10001, sender=tester.keys[0])
        wallet.submitTransaction(wallet.address, 0, add_new,
                                 10001, sender=tester.keys[1])
        wallet.submitTransaction(wallet.address, 0, add_new,
                                 10001, sender=tester.keys[2])

        assert wallet.isOwner(new_acc)

        self.state.mine(1)

        old_acc = tester.accounts[0]

        assert wallet.isOwner(old_acc)

        rem_old = translator.encode_function_call('removeOwner', [old_acc])
        wallet.submitTransaction(wallet.address, 0, rem_old,
                                 10001, sender=tester.keys[1])
        wallet.submitTransaction(wallet.address, 0, rem_old,
                                 10001, sender=tester.keys[2])
        wallet.submitTransaction(wallet.address, 0, rem_old,
                                 10001, sender=tester.keys[9])

        assert not wallet.isOwner(old_acc)

    def test_owner_3of5_rem_add(self):
        n_wallet_owners = 5
        wallet, wallet_owners, wallet_owner_keys, translator = self.deploy_wallet(n_wallet_owners,
                                                                                  required=3)
        self.state.mine(1)

        old_acc = tester.accounts[0]
        assert wallet.isOwner(old_acc)

        rem_old = translator.encode_function_call('removeOwner', [old_acc])
        wallet.submitTransaction(wallet.address, 0, rem_old,
                                 10001, sender=tester.keys[1])
        wallet.submitTransaction(wallet.address, 0, rem_old,
                                 10001, sender=tester.keys[2])
        wallet.submitTransaction(wallet.address, 0, rem_old,
                                 10001, sender=tester.keys[3])
        assert not wallet.isOwner(old_acc)

        self.state.mine(1)
        new_acc = tester.accounts[9]
        assert not wallet.isOwner(new_acc)
        add_new = translator.encode_function_call('addOwner', [new_acc])
        wallet.submitTransaction(wallet.address, 0, add_new,
                                 10001, sender=tester.keys[1])
        wallet.submitTransaction(wallet.address, 0, add_new,
                                 10001, sender=tester.keys[2])
        wallet.submitTransaction(wallet.address, 0, add_new,
                                 10001, sender=tester.keys[3])
        assert wallet.isOwner(new_acc)

    def test_deploy(self):
        n_wallet_owners = 3

        wallet, wallet_owners, wallet_owner_keys, _ = self.deploy_wallet(n_wallet_owners)
        wallet_owner_balances = [self.state.block.get_balance(wallet_owners[i])
                                 for i in xrange(n_wallet_owners)]

        # Send eth to the wallet contract
        to_send = 10 * denoms.ether
        gas_before = self.state.block.gas_used

        self.state.send(tester.keys[8], wallet.address, to_send)
        gas_used = self.state.block.gas_used - gas_before

        gas_bonus = gas_used * tester.gas_price
        wallet_owner_balances[0] += gas_bonus

        assert self.state.block.get_balance(wallet.address) == to_send
        assert all([self.state.block.get_balance(wallet_owners[i]) == b
                    for i, b in enumerate(wallet_owner_balances)])

    def test_finalize(self):
        n_wallet_owners = 3
        wallet, wallet_owners, wallet_owner_keys, _ = self.deploy_wallet(n_wallet_owners, required=2)
        self.state.mine(1)
        contract, translator = self.deploy_contract(2, 3, founder=wallet.address)

        wallet_balance_init = self.state.block.get_balance(wallet.address)

        self.state.mine(2)
        # Send funds to contract to achieve mincap
        to_send = 200000 * denoms.ether
        contract.create(sender=tester.keys[9], value=to_send)

        # wait for end of funding period and finalize from multisig
        self.state.mine(2)
        finalize = translator.encode_function_call('finalize', [])
        wallet.submitTransaction(contract.address, 0, finalize,
                                 10001, sender=tester.keys[0])
        wallet.submitTransaction(contract.address, 0, finalize,
                                 10001, sender=tester.keys[1])
        assert self.state.block.get_balance(wallet.address) == to_send - wallet_balance_init

    def test_refund(self):
        self.state.mine(1)
        contract, translator = self.deploy_contract(2, 3, creator_idx=1)

        n_wallet_owners = 3
        wallet, wallet_owners, wallet_owner_keys, _ = self.deploy_wallet(n_wallet_owners, required=2)

        # Send eth to the wallet contract
        to_send = 10 * denoms.ether
        self.state.send(tester.keys[9], wallet.address, to_send)
        wallet_balance_init = self.state.block.get_balance(wallet.address)

        # ---------------
        #     FUNDING
        # ---------------
        self.state.mine(2)

        eths_to_spend = to_send - 1 * denoms.ether

        create = decode_hex('efc81a8c')
        wallet.submitTransaction(contract.address, eths_to_spend, create,
                                 10000, sender=tester.keys[0])
        wallet.submitTransaction(contract.address, eths_to_spend, create,
                                 10000, sender=tester.keys[1])

        assert contract.balanceOf(wallet.address) == eths_to_spend * contract.tokenCreationRate()
        assert self.state.block.get_balance(wallet.address) == wallet_balance_init - eths_to_spend

        # ---------------
        #  POST FUNDING
        # ---------------
        self.state.mine(2)

        refund = translator.encode_function_call('refund', [])
        wallet.submitTransaction(contract.address, 0, refund,
                                 10001, sender=tester.keys[0])
        wallet.submitTransaction(contract.address, 0, refund,
                                 10001, sender=tester.keys[1])

        assert contract.balanceOf(wallet.address) == 0
        assert self.state.block.get_balance(wallet.address) == wallet_balance_init


    def test_migration(self):
        n_wallet_owners = 3
        wallet, wallet_owners, wallet_owner_keys, _ = self.deploy_wallet(n_wallet_owners, required=2)
        self.state.mine(1)
        contract, translator = self.deploy_contract(2, 3, migration_master=wallet.address)
        wallet_balance_init = self.state.block.get_balance(wallet.address)
        self.state.mine(2)

        creation_min = contract.tokenCreationMin()
        creation_rate = contract.tokenCreationRate()
        transfer_value = denoms.ether * creation_rate
        eth_part = int(creation_min / (3 * creation_rate)) + 1 * denoms.ether

        # ---------------
        #     FUNDING
        # ---------------
        # Send creation_min+ to the GNT contract
        contract.create(sender=tester.keys[3], value=eth_part)
        contract.create(sender=tester.keys[4], value=eth_part)
        contract.create(sender=tester.keys[5], value=eth_part)

        assert wallet_balance_init + eth_part*3 == self.state.block.get_balance(contract.address)

        total_tokens = contract.totalSupply()

        # ---------------
        #  POST FUNDING
        # ---------------
        self.state.mine(2)

        contract.finalize()
        # ---------------
        #    IN NORMAL
        # ---------------
        migration, m_addr, _ = self.__deploy_contract(MIGRATION_INIT, MIGRATION_ABI, 9, contract.address)
        target, t_addr, _ = self.__deploy_contract(TARGET_INIT, TARGET_ABI, 9, m_addr)

        with self.assertRaises(TransactionFailed):
            contract.setMigrationAgent(m_addr, sender=tester.keys[8])

        setagent = translator.encode_function_call('setMigrationAgent', [m_addr])
        wallet.submitTransaction(contract.address, 0, setagent,
                                 10001, sender=tester.keys[0])
        wallet.submitTransaction(contract.address, 0, setagent,
                                 10001, sender=tester.keys[1])

        # ---------------
        #  IN MIGRATION
        # ---------------
        migration.setTargetToken(t_addr, sender=tester.keys[9])

        b = contract.balanceOf(tester.accounts[3])
        assert b > 0
        contract.migrate(b, sender=tester.keys[3])
        assert 0 == contract.balanceOf(tester.accounts[3])
        assert b == target.balanceOf(tester.accounts[3])
