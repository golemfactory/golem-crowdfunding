import unittest

from ethereum import abi
from ethereum import tester
from ethereum.config import default_config
from ethereum.keys import decode_hex
from ethereum.utils import denoms

GNT_INIT = decode_hex(open('tests/GolemNetworkToken.bin', 'r').read().rstrip())
GNT_ABI = open('tests/GolemNetworkToken.abi', 'r').read()

WALLET_INIT = decode_hex(open('tests/MultiSigWallet.bin', 'r').read().rstrip())
WALLET_ABI = open('tests/MultiSigWallet.abi', 'r').read()



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

    def __deploy_wallet(self, owner_key, owners, required=1):
        t = abi.ContractTranslator(WALLET_ABI)
        args = t.encode_constructor_arguments((owners, required))
        addr = self.state.evm(WALLET_INIT + args,
                              sender=owner_key)
        return tester.ABIContract(self.state, WALLET_ABI, addr)

    def deploy_wallet(self, n_wallet_owners, required=1, creator_idx=0):
        _range = range(creator_idx, n_wallet_owners)
        wallet_owners = [tester.accounts[i] for i in _range]
        wallet_owner_keys = [tester.keys[i] for i in _range]
        wallet = self.__deploy_wallet(tester.keys[creator_idx], wallet_owners,
                                      required=required)
        return wallet, wallet_owners, wallet_owner_keys

    def test_deploy(self):
        n_wallet_owners = 3

        wallet, wallet_owners, wallet_owner_keys = self.deploy_wallet(n_wallet_owners)
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
        wallet, wallet_owners, wallet_owner_keys = self.deploy_wallet(n_wallet_owners, required=2)
        self.state.mine(1)
        contract, translator = self.deploy_contract(2, 3, founder=wallet.address)

        wallet_balance_init = self.state.block.get_balance(wallet.address)

        self.state.mine(2)
        # Send funds to contract to achieve mincap
        to_send = 200000 * denoms.ether
        self.state.send(tester.keys[9], contract.address, to_send)

        # wait for end of funding period and finalize from multisig
        self.state.mine(1)
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
        wallet, wallet_owners, wallet_owner_keys = self.deploy_wallet(n_wallet_owners, required=2)

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
