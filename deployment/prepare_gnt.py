from __future__ import print_function
import json
import subprocess
from ethereum._solidity import compile_contract
from ethereum.abi import ContractTranslator

GOLEM_FACTORY = 'eab3377047c242d8dd2a8d8a4aa1e9f77cf809bb'
MIGRATION_MASTER = '0x7e2a4fe6e8f1c243d2b7e547d517834989e8e463'
START_BLOCK = 2000000
END_BLOCK = 2000001

version_info = subprocess.check_output(['solc', '--version'])
print(version_info)

contract = compile_contract('contracts/Token.sol', 'GolemNetworkToken')

init = contract['bin_hex']
abi = contract['abi']

translator = ContractTranslator(abi)
args = translator.encode_constructor_arguments(
    (GOLEM_FACTORY, MIGRATION_MASTER, START_BLOCK, END_BLOCK)
).encode('hex')

print('\nGolem Network Token')
print('- Factory: ' + GOLEM_FACTORY)
print('- Migration Master: ' + MIGRATION_MASTER)
print('- Start: ', START_BLOCK)
print('- End: ', END_BLOCK)
print()
print('Deploy:')
print(init + args)
print()
print('Args:')
print(args)
print()
print('ABI:')
print(json.dumps(abi))
