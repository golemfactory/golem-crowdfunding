import sys
from ethereum import abi

GNT_ABI = open('tests/GolemNetworkToken.abi', 'r').read()
MIGRATION_ABI = open('tests/MigrationAgent.abi', 'r').read()
TARGET_ABI = open('tests/GNTTargetToken.abi', 'r').read()
ALLOC_ABI = open('tests/GNTAllocation.abi', 'r').read()
WALLET_ABI = open('tests/BadWallet.abi', 'r').read()

FMT = '{0:<24}{1:}'


def methods(name, contract_abi, sought=None, args=None):
    translator = abi.ContractTranslator(contract_abi)
    args = args or []
    printed = False

    for fn in translator.function_data:
        if not sought or fn.lower() == sought.lower():

            if not printed:
                print "\n----", name, "----\n"
                printed = True

            try:
                encoded = translator.encode_function_call(fn, args).encode('hex')
                print FMT.format(fn, encoded)
            except Exception:
                print FMT.format(fn, "INVALID ARGUMENTS")

sought_method = None
arguments = None

if len(sys.argv) > 1:
    sought_method = sys.argv[1]

if len(sys.argv) == 3:
    arguments = eval(sys.argv[2])
elif len(sys.argv) > 3:
    print "Invalid number of arguments"

print FMT.format("-- Method", sought_method)
print FMT.format("-- Arguments", arguments)

methods("GNT", GNT_ABI, sought=sought_method, args=arguments)
methods("MIGRATION", MIGRATION_ABI, sought=sought_method, args=arguments)
methods("TARGET TOKEN", TARGET_ABI, sought=sought_method, args=arguments)
methods("ALLOCATION", ALLOC_ABI, sought=sought_method, args=arguments)
methods("WALLET", WALLET_ABI, sought=sought_method, args=arguments)
