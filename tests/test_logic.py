from hypothesis import strategies as st
from hypothesis import given

from hypothesis.stateful import GenericStateMachine
from hypothesis.strategies import tuples, sampled_from, just, integers

import math
import random
import unittest
# from unittest import assertRaises
from random import randint
from os import urandom
from ethereum import abi, tester
from ethereum.tester import TransactionFailed, ContractCreationFailed
from ethereum.utils import denoms
from rlp.utils import decode_hex

tester.serpent = True  # tester tries to load serpent module, prevent that.

GNT_INIT = decode_hex(open('tests/GolemNetworkToken.bin', 'r').read().rstrip())
GNT_ABI = open('tests/GolemNetworkToken.abi', 'r').read()

class GNTCrowdfundingTest():
    def __init__(self):
        self.state = tester.state()

    # Test account monitor.
    # The ethereum.tester predefines 10 Ethereum accounts
    # (tester.accounts, tester.keys).
    class Monitor:
        def __init__(self, state, account_idx, params=0):
            self.addr = tester.accounts[account_idx]
            self.key = tester.keys[account_idx]
            self.state = state
            self.params = params
            self.initial = state.block.get_balance(self.addr)
            assert self.initial > 0
            assert self.addr != state.block.coinbase

        def gas(self):
            b = self.state.block.get_balance(self.addr)
            total = self.initial - b
            g = (total - self.params) / tester.gas_price
            return g

    def monitor(self, addr, params=0):
        return self.Monitor(self.state, addr, params)

    def deploy_contract(self, founder, start, end, creator_idx=9):
        owner = self.monitor(creator_idx)
        t = abi.ContractTranslator(GNT_ABI)
        args = t.encode_constructor_arguments((founder, start, end))
        self.c_addr = self.state.evm(GNT_INIT + args,
                                     sender=owner.key)
        self.c = tester.ABIContract(self.state, GNT_ABI, self.c_addr)
        return owner.gas()

START=1
FINISH=3
MAXCAP=820000 * denoms.ether
MINCAP=150000 * denoms.ether
TOKENCREATIONRATE=1000

class Contract(GenericStateMachine, unittest.TestCase):
    def __init__(self):
        self.m = GNTCrowdfundingTest()
        self.gathered = 0
        self.finalized = False
        self.founder = tester.accounts[2]
        self.m.deploy_contract(self.founder, START, FINISH)
        self.tokens = [ self.m.c.balanceOf(tester.accounts[x]) for x in range(len(tester.keys)) ]

    def steps(self):
        mine_st = tuples(just("mine"), integers(min_value=1, max_value=3))
        fund_st = tuples(just("fund"), tuples(sampled_from(range(len(tester.keys))),
                                              integers(min_value=2000)))
        transfer_st = tuples(just("transfer"), tuples(sampled_from(range(len(tester.keys))),
                                                      sampled_from(range(len(tester.accounts))),
                                                      integers(min_value=2000)))
        finalize_st = tuples(just("finalize"), sampled_from(range(len(tester.keys))))
        return mine_st | fund_st | transfer_st

    def execute_step(self, step):
        n = self.m.state.block.number
        b = self.m.state.block
        action, params = step
        if action == "mine":
            self.m.state.mine(params)
            return
        if action == "fund":
            src, amount = params
            if (n >= START) and (n <= FINISH) and (self.gathered <= MAXCAP) and (not self.finalized):
                self.m.state.send(tester.keys[src], self.m.c_addr, amount)
                self.tokens[src] += amount * TOKENCREATIONRATE
            else:
                with self.assertRaises(TransactionFailed):
                    self.m.state.send(tester.keys[src], self.m.c_addr, amount)
            return
        if action == "transfer":
            src, dst, amount = params
            if ((n > FINISH) or (self.gathered == MAXCAP)) and (self.gathered >= MINCAP) and (self.tokens[src] >= amount):
                assert self.m.c.transfer(tester.accounts[dst], amount, sender=tester.keys[src])
                self.tokens[src] -= amount
                self.tokens[dst] += amount
            else:
                with self.assertRaises(TransactionFailed):
                    self.m.c.transfer(tester.accounts[dst], amount, sender=tester.keys[src])
            return

TestSet = Contract.TestCase
