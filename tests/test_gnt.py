import unittest
from ethereum import abi, tester
from rlp.utils import decode_hex

tester.serpent = True  # tester tries to load serpent module, prevent that.

# GNT contract bytecode (used to create the contract) and ABI.
# This is procudes by solidity compiler from Token.sol file.
# You can use Solidity Browser
# https://ethereum.github.io/browser-solidity/#version=soljson-v0.4.2+commit.af6afb04.js&optimize=true
# to work on and update the Token.
GNT_INIT = decode_hex('60606040526040516060806109ed83395060c06040525160805160a05160028054600160a060020a03191684179055600082905560018190555050506109a4806100496000396000f3606060405236156101115760e060020a600035046306fdde038114610135578063095ea7b31461017457806315f19f5c146101ee57806318160ddd146101fb57806323b872dd1461020b57806325e4c7bf1461022c57806327ea06b814610239578063313ce5671461024657806335b944bf14610253578063454b0608146102605780634cd412d5146102845780634d853ee51461029157806370a08231146102a857806375e2ff65146102dd5780638328dbcd1461030357806393c32e061461031a57806395a0f5eb1461035e57806395d89b411461036c578063a19ed39d146103ab578063a9059cbb146103c4578063c87877af146103dc578063dd62ed3e146103ff578063eac35fed14610438575b61044560006104a65b60006105985b6001546000904311156105b1575060016104d5565b34610002576104e460408051808201909152601381527f476f6c656d204e6574776f726b20546f6b656e00000000000000000000000000602082015281565b346100025761055260043560243533600160a060020a03908116600081815260056020908152604080832094871680845294825280832086905580518681529051929493927f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925929181900390910190a35060015b92915050565b3461000257610552610120565b34610002576102cb6003546104d5565b346100025761055260043560243560443560006105d15b60006107f7610120565b34610002576105526103b9565b34610002576102cb6104c5565b3461000257610566601881565b346100025761055261026f565b34610002576104456004356106c35b600654600160a060020a0316600014156104d5565b3461000257610552610222565b346100025761057c600254600160a060020a031681565b346100025760048035600160a060020a0316600090815260209190915260409020545b60408051918252519081900360200190f35b346100025761044560043560025433600160a060020a039081169116146107fe57610002565b346100025761057c600654600160a060020a031681565b346100025761044560043560025433600160a060020a03908116911614156104a3576002805473ffffffffffffffffffffffffffffffffffffffff19168217905550565b34610002576102cb60075481565b34610002576104e460408051808201909152600381527f474e540000000000000000000000000000000000000000000000000000000000602082015281565b346100025761044560006108325b6001546000146104d5565b346100025761055260043560243560006108ac610222565b346100025761044560025433600160a060020a0390811691161461095a57610002565b34610002576102cb600435602435600160a060020a038083166000908152600560209081526040808320938516835292905220546101e8565b346100025761055261011a565b005b33600160a060020a031660008181526004602090815260408083208054860190556003805486019055805185815290517fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef929181900390910190a35b50565b15156104b157610002565b503460008114156104c157610002565b6104d85b60035469b374c5201176f0938683035b90565b81111561044757610002565b60405180806020018281038252838181518152602001915080519060200190808383829060006004602084601f0104600302600f01f150905090810190601f1680156105445780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b604080519115158252519081900360200190f35b6040805160ff9092168252519081900360200190f35b60408051600160a060020a039092168252519081900360200190f35b156105a5575060006104d5565b506000544310156104d5565b5060035469b374c5201176f0938683146104d5565b5060005b9392505050565b80156105f65750600160a060020a038416600090815260046020526040902054829010155b80156106295750600160a060020a0384811660009081526005602090815260408083203390941683529290522054829010155b80156106355750600082115b156105c657600160a060020a03838116600081815260046020908152604080832080548801905588851680845281842080548990039055600583528184203390961684529482529182902080548790039055815186815291519293927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9281900390910190a35060016105ca565b15156106ce57610002565b6106d6610222565b15156106e157610002565b33600160a060020a03166000908152600460205260409020548190101561070757610002565b806000141561071557610002565b33600160a060020a03908116600081815260046020819052604080832080548790039055600380548790039055600780548701905580516006547f7a3130e3000000000000000000000000000000000000000000000000000000008252928101949094526024840186905251931692637a3130e392604480820193929182900301818387803b156100025760325a03f115610002575050600654604080518481529051600160a060020a03928316935033909216917f18df02dcc52b9c494f391df09661519c0069bd8540141946280399408205ca1a9181900360200190a350565b90506104d5565b61080661026f565b1561081057610002565b6006805473ffffffffffffffffffffffffffffffffffffffff19168217905550565b1561083c57610002565b60025433600160a060020a0390811691161461085757610002565b61085f610120565b151561086a57610002565b600354605290601202600254600160a060020a031660009081526004602052604081208054939092049283019091556003805483019055808055600155905050565b80156108d1575033600160a060020a0316600090815260046020526040902054829010155b80156108dd5750600082115b156109525733600160a060020a03908116600081815260046020908152604080832080548890039055938716808352918490208054870190558351868152935191937fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef929081900390910190a35060016101e8565b5060006101e8565b610962610120565b151561096d57610002565b600254604051600160a060020a039182169130163180156108fc02916000818181858888f1935050505015156109a257610002565b56')  # noqa
GNT_ABI = '[{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_value","type":"uint256"}],"name":"approve","outputs":[{"name":"success","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"fundingHasEnded","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_from","type":"address"},{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transferFrom","outputs":[{"name":"success","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"fundingFinalized","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"numberOfTokensLeft","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"migrationEnabled","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_value","type":"uint256"}],"name":"migrate","outputs":[],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"transferEnabled","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"founder","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_agent","type":"address"}],"name":"setMigrationAgent","outputs":[],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"migrationAgent","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_newFounder","type":"address"}],"name":"changeFounder","outputs":[],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"totalMigrated","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"type":"function"},{"constant":false,"inputs":[],"name":"finalizeFunding","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"success","type":"bool"}],"payable":false,"type":"function"},{"constant":false,"inputs":[],"name":"transferEtherToFounder","outputs":[],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"},{"name":"_spender","type":"address"}],"name":"allowance","outputs":[{"name":"remaining","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"fundingOngoing","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"inputs":[{"name":"_founder","type":"address"},{"name":"_fundingStartBlock","type":"uint256"},{"name":"_fundingEndBlock","type":"uint256"}],"type":"constructor"},{"payable":true,"type":"fallback"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_from","type":"address"},{"indexed":true,"name":"_to","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_owner","type":"address"},{"indexed":true,"name":"_spender","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_from","type":"address"},{"indexed":true,"name":"_to","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Migrate","type":"event"}]'  # noqa


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
	for i in range(13):      
	    self.state.mine()
	    assert not self.c.transferEnabled()  
	assert self.state.block.number == 13
	for i in range(259):
	    self.state.mine()
	    assert self.c.transferEnabled()

    def test_transfer_enabled_after_max_fund_reached(self):
	founder = tester.accounts[2]
        addr, _ = self.deploy_contract(founder, 3, 7)
        assert not self.c.transferEnabled()
        for i in range(3):
            self.state.mine()
        assert not self.c.transferEnabled()
        self.state.send(tester.keys[0], addr, 11)
	assert not self.c.transferEnabled() 
        self.state.send(tester.keys[1], addr, 847457627118644067796600)
	assert self.c.transferEnabled()
	for i in range(8):
	    self.state.mine()
	    assert self.c.transferEnabled()
