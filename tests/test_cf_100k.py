import cPickle
import os
import unittest

from ethereum import tester
from ethereum.exceptions import BlockGasLimitReached
from ethereum.utils import denoms

from test_gnt import deploy_contract_and_accounts, deploy_gnt

STATE_FILE_NAME = 'test100k.state'

N_PARTICIPANTS = 10 ** 5
GAS_PRICE = 21 * 10 ** 9
BLOCK_PERIOD = 2000

tester.gas_limit = 2 * 10 ** 6
tester.gas_price = GAS_PRICE


def calc_block_gas_limit():
    return int(BLOCK_PERIOD * 450000000000000 / GAS_PRICE)


def calc_wei_to_send_per_participant(cap_eth, n_participants):
    return int(cap_eth / n_participants)


class StateHolder(object):

    def __init__(self, state=None, contract=None, allocation=None, keys=None, accounts=None):
        self.state = state
        self.contract = contract
        self.allocation = allocation
        self.keys = keys
        self.accounts = accounts

    def persist(self, state_file_path):
        print "Persisting state..."
        with open(state_file_path, 'w') as state_file:
            cPickle.dump(self, state_file, cPickle.HIGHEST_PROTOCOL)
        print "... done."

    @staticmethod
    def restore(state_file_path):
        print "Loading state..."
        with open(state_file_path, 'r') as state_file:
            return cPickle.load(state_file)


class GNTCrowdfundingTest100k(unittest.TestCase):

    def setUp(self):
        state_file_path = STATE_FILE_NAME

        if os.path.isfile(state_file_path):
            state_holder = StateHolder.restore(state_file_path)
        else:
            self.state = tester.state()
            c, a, keys, addrs = deploy_contract_and_accounts(self.state, N_PARTICIPANTS,
                                                             deploy_contract=False)

            state_holder = StateHolder(self.state, c, a, keys, addrs)
            state_holder.persist(state_file_path)

        self._populate_state_from_holder(state_holder)
        self.state.block.gas_limit = calc_block_gas_limit()
        print "Gas limit:", self.state.block.gas_limit

    def _populate_state_from_holder(self, state_holder):
        self.state = state_holder.state
        self.contract = state_holder.contract
        self.allocation = state_holder.allocation
        self.keys = state_holder.keys
        self.accounts = state_holder.accounts

    def _send(self, idx, address, value):
        # Retries sending if block gas limit has been reached
        try:
            self.state.send(self.keys[idx], address, value)
        except BlockGasLimitReached:
            self.state.mine(1)
            print ":: block", self.state.block.number
            print "Gas limit:", self.state.block.gas_limit
            self._send(idx, address, value)

    def _fund(self, n_participants=N_PARTICIPANTS, start=1, duration=BLOCK_PERIOD,
              min_eth=150000 * 100, cap_eth=820000 * 100):

        min = min_eth * denoms.ether
        cap = cap_eth * denoms.ether
        end = start + duration

        contract, _, _ = deploy_gnt(
            self.state,
            start=start,
            end=end,
            factory=tester.accounts[9],
            replacements=[
                ([str(min_eth)], 'constant tokenCreationMin\s?=\s?([0-9]+) ether'),
                ([str(cap_eth)], 'constant tokenCreationCap\s?=\s?([0-9]+) ether'),
            ]
        )

        creation_rate = contract.tokenCreationRate()
        to_send = calc_wei_to_send_per_participant(cap, n_participants)

        self.state.mine(1)

        try:

            for i in xrange(n_participants):
                if i % 100 == 0:
                    print "Progress:", 100. * i / n_participants, '%'
                self._send(i, contract.address, to_send)

        except Exception:

            gas_limit = self.state.block.gas_limit
            # to be able to read contract's properties
            self.state.block.gas_limit = 10 ** 10

            total = contract.totalSupply()
            min_tokens = min * creation_rate
            cap_tokens = cap * creation_rate

            print "\n"
            print "---- SUMMARY ----"

            print "Block:", self.state.block.number
            print "End:  ", end
            print "GNT:  ", total
            print "Left: ", contract.numberOfTokensLeft()
            print "Act:  ", contract.fundingActive()
            print "Min:  ", min_tokens
            print "Min:  ", contract.tokenCreationMin()
            print "Max:  ", cap_tokens
            print "Max:  ", contract.tokenCreationCap()

            print "Block gas limit:        ", gas_limit
            print "Initial block gas limit:", calc_block_gas_limit()

            print "---- ------- ----"

            if self.state.block.number > end:

                if total >= min_tokens:
                    print "Funding succeeded at iteration", i
                else:
                    self.fail("Funding period ended at iteration {}".format(i))

            elif total > (cap - to_send) * creation_rate:
                print "Cap reached at iteration", i
            else:
                raise

        else:

            self.state.mine(1)
            assert contract.totalSupply() == contract.tokenCreationRate() * n_participants * to_send

    @unittest.skip("Skip for CI")
    def test_funding(self):
        self._fund()
