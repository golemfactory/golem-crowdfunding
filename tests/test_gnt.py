import unittest
from ethereum import abi, tester
from rlp.utils import decode_hex

tester.serpent = True  # tester tries to load serpent module, prevent that.

GNT_INIT = decode_hex('60a060405260096060527f546f6b656e20302e310000000000000000000000000000000000000000000000608052600080548180527f546f6b656e20302e31000000000000000000000000000000000000000000001282556100b3907f290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563602060026001841615610100026000190190931692909204601f01919091048101905b80821115610110576000815560010161009f565b5050604051606080610b588339810160405280805190602001909190805190602001909190805190602001909190505060038054600160a060020a0319168417905560018290556002819055505050610a44806101146000396000f35b5090566060604052361561011c5760e060020a600035046306fdde038114610140578063095ea7b31461017f57806315f19f5c146101f957806318160ddd146102065780632121dc751461021657806323b872dd1461022357806324f0c4631461024457806325e4c7bf1461025157806326d26d7c1461025e57806327ea06b81461026c578063313ce567146102795780634d853ee5146102865780635a3b7e421461029d578063629323011461030057806370a0823114610317578063937ee3a61461034a57806393c32e0614610370578063940bd856146103b457806395d89b41146103d8578063a19ed39d14610417578063a9059cbb14610430578063c87877af14610448578063dd62ed3e1461046b578063eac35fed146104a4575b6104b160006105125b60006106045b60025460009043111561061d57506001610541565b346100025761055060408051808201909152601381527f476f6c656d204e6574776f726b20546f6b656e00000000000000000000000000602082015281565b34610002576105be60043560243533600160a060020a03908116600081815260066020908152604080832094871680845294825280832086905580518681529051929493927f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925929181900390910190a35060015b92915050565b34610002576105be61012b565b3461000257610338600454610541565b34610002576105be61023a565b34610002576105be60043560243560443560006106445b600061063261012b565b34610002576105be6103c3565b34610002576105be610425565b346100025761033860085481565b3461000257610338610531565b34610002576105d2601881565b34610002576105e8600354600160a060020a031681565b34610002576040805160008054602060026001831615610100026000190190921691909104601f810182900482028401820190945283835261055093908301828280156107615780601f1061073657610100808354040283529160200191610761565b34610002576105e8600754600160a060020a031681565b3461000257600435600160a060020a03166000908152600560205260409020545b60408051918252519081900360200190f35b34610002576104b160043560035433600160a060020a0390811691161461076957610002565b34610002576104b160043560035433600160a060020a039081169116141561050f576003805473ffffffffffffffffffffffffffffffffffffffff19168217905550565b34610002576104b160043561079d5b600754600160a060020a031660001415610541565b346100025761055060408051808201909152600381527f474e540000000000000000000000000000000000000000000000000000000000602082015281565b34610002576104b160006108d05b600254600014610541565b34610002576105be600435602435600061094c61023a565b34610002576104b160035433600160a060020a039081169116146109fa57610002565b3461000257610338600435602435600160a060020a038083166000908152600660209081526040808320938516835292905220546101f3565b34610002576105be610125565b005b33600160a060020a031660008181526005602090815260408083208054860190556004805486019055805185815290517fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef929181900390910190a35b50565b151561051d57610002565b5034600081141561052d57610002565b6105445b60045469b374c5201176f0938683035b90565b8111156104b357610002565b60405180806020018281038252838181518152602001915080519060200190808383829060006004602084601f0104600302600f01f150905090810190601f1680156105b05780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b604080519115158252519081900360200190f35b6040805160ff9092168252519081900360200190f35b60408051600160a060020a039092168252519081900360200190f35b1561061157506000610541565b50600154431015610541565b5060045469b374c5201176f093868314610541565b9050610541565b5060005b9392505050565b80156106695750600160a060020a038416600090815260056020526040902054829010155b801561069c5750600160a060020a0384811660009081526006602090815260408083203390941683529290522054829010155b80156106a85750600082115b1561063957600160a060020a03838116600081815260056020908152604080832080548801905588851680845281842080548990039055600683528184203390961684529482529182902080548790039055815186815291519293927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9281900390910190a350600161063d565b820191906000526020600020905b81548152906001019060200180831161074457829003601f168201915b505050505081565b6107716103c3565b1561077b57610002565b6007805473ffffffffffffffffffffffffffffffffffffffff19168217905550565b15156107a857610002565b6107b061023a565b15156107bb57610002565b33600160a060020a0316600090815260056020526040902054819010156107e157610002565b80600014156107ef57610002565b33600160a060020a0390811660008181526005602052604080822080548690039055600480548690038155600880548701905581516007547ff36b8e430000000000000000000000000000000000000000000000000000000082529181019490945260248401869052905193169263f36b8e4392604480820193929182900301818387803b156100025760325a03f115610002575050600754604080518481529051600160a060020a03928316935033909216917ffef04c7d4eedb6834985177719348986da71cc6db0472e30186496b17a52e71d9181900360200190a350565b156108da57610002565b60035433600160a060020a039081169116146108f557610002565b6108fd61012b565b151561090857610002565b600454605290601202600354600160a060020a0316600090815260056020526040812080549390920492830190915560048054830190556001819055600255905050565b8015610971575033600160a060020a0316600090815260056020526040902054829010155b801561097d5750600082115b156109f25733600160a060020a03908116600081815260056020908152604080832080548890039055938716808352918490208054870190558351868152935191937fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef929081900390910190a35060016101f3565b5060006101f3565b610a0261012b565b1515610a0d57610002565b600354604051600160a060020a039182169130163180156108fc02916000818181858888f193505050501515610a4257610002565b56')  # noqa
GNT_ABI = '[{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_value","type":"uint256"}],"name":"approve","outputs":[{"name":"success","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"fundingHasEnded","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"isTransferable","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_from","type":"address"},{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transferFrom","outputs":[{"name":"success","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"isExportable","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"fundingFinalized","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"totalExported","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"numberOfTokensLeft","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"founder","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"standard","outputs":[{"name":"","type":"string"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"importer","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_importer","type":"address"}],"name":"setImporter","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_newFounder","type":"address"}],"name":"changeFounder","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_value","type":"uint256"}],"name":"export","outputs":[],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"type":"function"},{"constant":false,"inputs":[],"name":"finalizeFunding","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"success","type":"bool"}],"payable":false,"type":"function"},{"constant":false,"inputs":[],"name":"transferEtherToFounder","outputs":[],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"},{"name":"_spender","type":"address"}],"name":"allowance","outputs":[{"name":"remaining","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"fundingOngoing","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"inputs":[{"name":"_founder","type":"address"},{"name":"_fundingStart","type":"uint256"},{"name":"_fundingEnd","type":"uint256"}],"type":"constructor"},{"payable":true,"type":"fallback"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_from","type":"address"},{"indexed":true,"name":"_to","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_owner","type":"address"},{"indexed":true,"name":"_spender","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_from","type":"address"},{"indexed":true,"name":"_to","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Export","type":"event"}]'  # noqa


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

    def deposit(self, addr_idx, value):
        m = self.monitor(addr_idx, value)
        self.c.deposit(sender=m.key, value=value)
        return m.gas()

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
