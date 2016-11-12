from __future__ import print_function
import json
import subprocess
from ethereum._solidity import compile_contract
from ethereum.abi import ContractTranslator

GOLEM_FACTORY = '0x7da82C7AB4771ff031b66538D2fB9b0B047f6CF9'
MIGRATION_MASTER = '0x7da82C7AB4771ff031b66538D2fB9b0B047f6CF9'
START_BLOCK = 2607800
END_BLOCK = 2734100

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
