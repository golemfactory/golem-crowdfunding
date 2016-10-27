import datetime
from random import randint
from web3 import Web3, KeepAliveRPCProvider

# contract address
address = '0xd3CdA913deB6f67967B99D67aCDFa1712C293601'

tokenCreationRate = 1000    # @todo should be taken from the contract
number_of_blocks = 1800000
FMT = '%Y-%m-%d %H:%M:%S'

web3 = Web3(KeepAliveRPCProvider(host='137.74.44.168', port='1234'))
#web3 = Web3(KeepAliveRPCProvider(host='185.25.60.233', port='8545'))

block = web3.eth.blockNumber
balance_eth = web3.fromWei(web3.eth.getBalance(account=address, block_identifier=block), 'ether')
balance_gnt = balance_eth * tokenCreationRate

# Compute avg time needed for new block
block_number = web3.eth.blockNumber
newest = datetime.datetime.fromtimestamp(web3.eth.getBlock(web3.eth.blockNumber)['timestamp']).strftime(FMT)
old = datetime.datetime.fromtimestamp(web3.eth.getBlock(web3.eth.blockNumber - number_of_blocks)['timestamp']).strftime(FMT)
d2 = datetime.datetime.strptime(newest, FMT)
d1 = datetime.datetime.strptime(old, FMT)
delta = ((d2-d1).total_seconds()) / number_of_blocks
print "Avg block chnage in:", delta, "seconds"

# @todo removed - just for tests
start_block = block_number + randint(1000, 10000)
end_block = start_block + randint(1000, 10000)

# compute time to start/end of the crowdfunding0
time_to_begin = (start_block - block_number) * delta
time_to_end = (end_block - block_number) * delta

start_date = str(datetime.timedelta(seconds=time_to_begin) + datetime.datetime.now())
end_date = str(datetime.timedelta(seconds=time_to_end) + datetime.datetime.now())

#print "Current block: ", block_number, "start block:", start_block, "end block:", end_block
#print "Estimated start date: ", start_date
#print "Estimated end date: ", end_date

# write everything to js
with open('data.js', 'w') as f:
    line = 'var block = ' + str(block) + '\n' \
           'var balance_eth = ' + str(balance_eth) + '\n' \
           'var balance_gnt = ' + str(balance_gnt) + '\n' \
           'var start_date = \"' + str(start_date) + '\"\n' \
           'var end_date = \"' + str(end_date) + '\"\n\n' \
           'function updateSite() {\n' + \
           '    document.getElementById(\"block\").innerHTML = \"Block: \" + block;\n' + \
           '    document.getElementById(\"balance_eth\").innerHTML = \"ETH: \" + balance_eth;\n' + \
           '    document.getElementById(\"balance_gnt\").innerHTML = \"GNT: \" + balance_gnt;\n' + \
           '    document.getElementById(\"start_date\").innerHTML = \"Estimated start date: \" + start_date;\n' + \
           '    document.getElementById(\"end_date\").innerHTML = \"Estimated end date: \" + end_date;\n' + \
           '}\n'
    f.write(line)
