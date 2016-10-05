import unittest
from ethereum import tester
from rlp.utils import decode_hex

tester.serpent = True  # tester tries to load serpent module, prevent that.

GNT_INIT = decode_hex('60a060405260096060527f546f6b656e20302e3100000000000000000000000000000000000000000000006080526003805460008290527f546f6b656e20302e31000000000000000000000000000000000000000000001282556100b5907fc2575a0e9e593c00f959f8c92f12db2869c3395a3b0502d05e2516446f71f85b602060026001841615610100026000190190931692909204601f01919091048101905b8082111561011257600081556001016100a1565b50506040516060806108898339810160405280805190602001909190805190602001909190805190602001909190505060068054600160a060020a0319168417905560048290556005819055505050610773806101166000396000f35b509056606060405236156100c45760e060020a600035046306fdde0381146100e8578063095ea7b31461012757806315f19f5c146101a157806318160ddd146101ae57806323b872dd146101bc57806327ea06b8146102ae578063313ce567146102bb5780635a3b7e42146102c857806370a082311461032b57806393c32e061461035e57806395d89b41146103a2578063a19ed39d146103e1578063a9059cbb146103fb578063c87877af146104a7578063dd62ed3e146104ca578063eac35fed14610503575b610510600061056f5b60006106455b60055460009043111561065e5750600161059e565b34610002576105ad60408051808201909152601381527f476f6c656d204e6574776f726b20546f6b656e00000000000000000000000000602082015281565b346100025761061b60043560243533600160a060020a03908116600081815260026020908152604080832094871680845294825280832086905580518681529051929493927f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925929181900390910190a35060015b92915050565b346100025761061b6100d3565b346100025761034c60005481565b346100025761061b600435602435604435600160a060020a038316600090815260016020526040812054829010801590610214575060026020908152604080832033600160a060020a03168452909152812054829010155b80156102205750600082115b1561067357600160a060020a03838116600081815260016020908152604080832080548801905588851680845281842080548990039055600283528184203390961684529482529182902080548790039055815186815291519293927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9281900390910190a3506001610677565b346100025761034c61058e565b346100025761062f601881565b34610002576040805160038054602060026001831615610100026000190190921691909104601f81018290048202840182019094528383526105ad93908301828280156106a95780601f1061067e576101008083540402835291602001916106a9565b3461000257600435600160a060020a03166000908152600160205260409020545b60408051918252519081900360200190f35b346100025761051060043560065433600160a060020a039081169116141561056c576006805473ffffffffffffffffffffffffffffffffffffffff19168217905550565b34610002576105ad60408051808201909152600381527f474e540000000000000000000000000000000000000000000000000000000000602082015281565b34610002576105106005546000908114156106b157610002565b346100025761061b60043560243533600160a060020a03166000908152600160205260408120548290108015906104325750600082115b156107215733600160a060020a03908116600081815260016020908152604080832080548890039055938716808352918490208054870190558351868152935191937fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef929081900390910190a350600161019b565b346100025761051060065433600160a060020a0390811691161461072957610002565b346100025761034c600435602435600160a060020a0380831660009081526002602090815260408083209385168352929052205461019b565b346100025761061b6100cd565b005b33600160a060020a03166000818152600160209081526040808320805486019055825485018355805185815290517fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef929181900390910190a35b50565b151561057a57610002565b5034600081141561058a57610002565b6105a15b60005469b374c5201176f0938683035b90565b81111561051257610002565b60405180806020018281038252838181518152602001915080519060200190808383829060006004602084601f0104600302600f01f150905090810190601f16801561060d5780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b604080519115158252519081900360200190f35b6040805160ff9092168252519081900360200190f35b156106525750600061059e565b5060045443101561059e565b5060005469b374c5201176f09386831461059e565b5060005b9392505050565b820191906000526020600020905b81548152906001019060200180831161068c57829003601f168201915b505050505081565b60065433600160a060020a039081169116146106cc57610002565b6106d46100d3565b15156106df57610002565b600054605290601202600654600160a060020a031660009081526001602052604081208054939092049283019091558054820181556004819055600555905050565b50600061019b565b6107316100d3565b151561073c57610002565b600654604051600160a060020a039182169130163180156108fc02916000818181858888f19350505050151561077157610002565b56')  # noqa
GNT_ABI = '[{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_value","type":"uint256"}],"name":"approve","outputs":[{"name":"success","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"fundingHasEnded","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_from","type":"address"},{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transferFrom","outputs":[{"name":"success","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"numberOfTokensLeft","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"standard","outputs":[{"name":"","type":"string"}],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_newFounder","type":"address"}],"name":"changeFounder","outputs":[],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"type":"function"},{"constant":false,"inputs":[],"name":"finalizeFunding","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"success","type":"bool"}],"payable":false,"type":"function"},{"constant":false,"inputs":[],"name":"transferEtherToFounder","outputs":[],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"},{"name":"_spender","type":"address"}],"name":"allowance","outputs":[{"name":"remaining","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"fundingOngoing","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"inputs":[{"name":"_founder","type":"address"},{"name":"_fundingStart","type":"uint256"},{"name":"_fundingEnd","type":"uint256"}],"type":"constructor"},{"payable":true,"type":"fallback"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_from","type":"address"},{"indexed":true,"name":"_to","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_owner","type":"address"},{"indexed":true,"name":"_spender","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Approval","type":"event"}]'  # noqa


class GNTCrowdfundingTest(unittest.TestCase):

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

    def deploy_contract(self, owner_idx=9):
        owner = self.monitor(owner_idx)
        # FIXME: How to add constructor arguments?
        addr = self.state.evm(GNT_INIT,
                              sender=owner.key)
        self.c = tester.ABIContract(self.state, GNT_ABI, addr)
        return addr, owner.gas()

    def contract_balance(self):
        return self.state.block.get_balance(self.c.address)

    def deposit(self, addr_idx, value):
        m = self.monitor(addr_idx, value)
        self.c.deposit(sender=m.key, value=value)
        return m.gas()

    def balance_of(self, addr_idx):
        return self.c.balanceOf(tester.accounts[addr_idx])

    def test_deployment(self):
        c, g = self.deploy_contract()
        assert len(c) == 20
        assert g <= 850000
        assert self.contract_balance() == 0

    def test_initial_balance(self):
        self.deploy_contract()
        assert self.balance_of(8) == 0
