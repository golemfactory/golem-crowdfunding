.PHONY: tests unit proxy clean

tests: build
	pytest tests

unit: build
	pytest tests/test_gnt.py

proxy: build
	pytest tests/test_proxy.py

build: tests/GolemNetworkToken.abi tests/GolemNetworkToken.bin tests/GNTTargetToken.bin tests/GNTTargetToken.abi tests/MigrationAgent.bin tests/MigrationAgent.abi tests/BadWallet.bin tests/BadWallet.abi tests/ProxyAccount.bin tests/ProxyAccount.abi tests/ProxyFactoryAccount.bin tests/ProxyFactoryAccount.abi tests/GNTAllocation.bin tests/GNTAllocation.abi

tests/GolemNetworkToken.bin: contracts/Token.sol
	solc --bin --abi --optimize contracts/Token.sol | awk '/======= GolemNetworkToken =======/,/======= MigrationAgent =======/' | grep '[01-9a-f]\{10,\}' > tests/GolemNetworkToken.bin

tests/GolemNetworkToken.abi: contracts/Token.sol
	solc --bin --abi --optimize contracts/Token.sol | awk '/======= GolemNetworkToken =======/,/======= MigrationAgent =======/' | grep '\[.*\]' > tests/GolemNetworkToken.abi

tests/GNTTargetToken.bin: contracts/ExampleMigration.sol
	solc --bin --abi --optimize contracts/ExampleMigration.sol | awk '/======= GNTTargetToken =======/,/======= GolemNetworkToken =======/' | grep '[01-9a-f]\{10,\}' > tests/GNTTargetToken.bin

tests/GNTTargetToken.abi: contracts/ExampleMigration.sol
	solc --bin --abi --optimize contracts/ExampleMigration.sol | awk '/======= GNTTargetToken =======/,/======= GolemNetworkToken =======/' | grep '\[.*\]' > tests/GNTTargetToken.abi

tests/MigrationAgent.bin: contracts/ExampleMigration.sol
	solc --bin --abi --optimize contracts/ExampleMigration.sol | awk '/======= MigrationAgent =======/,0' | grep '[01-9a-f]\{10,\}' > tests/MigrationAgent.bin

tests/MigrationAgent.abi: contracts/ExampleMigration.sol
	solc --bin --abi --optimize contracts/ExampleMigration.sol | awk '/======= MigrationAgent =======/,0' | grep '\[.*\]' > tests/MigrationAgent.abi

tests/BadWallet.bin: contracts/BadWallet.sol
	solc --bin --abi --optimize contracts/BadWallet.sol | awk '/======= BadWallet =======/,/======= GNTAllocation =======/' | grep '[01-9a-f]\{10,\}' > tests/BadWallet.bin

tests/BadWallet.abi: contracts/BadWallet.sol
	solc --bin --abi --optimize contracts/BadWallet.sol | awk '/======= BadWallet =======/,/======= GNTAllocation =======/' | grep '\[.*\]' > tests/BadWallet.abi

tests/ProxyAccount.bin: contracts/ProxyAccount.sol
	solc --bin --abi --optimize contracts/ProxyAccount.sol | awk '/======= TimeLockedGNTProxyAccount =======/,/======= TimeLockedGolemFactoryProxyAccount =======/' | grep '[01-9a-f]\{10,\}' > tests/ProxyAccount.bin

tests/ProxyAccount.abi: contracts/ProxyAccount.sol
	solc --bin --abi --optimize contracts/ProxyAccount.sol | awk '/======= TimeLockedGNTProxyAccount =======/,/======= TimeLockedGolemFactoryProxyAccount =======/' | grep '\[.*\]' > tests/ProxyAccount.abi

tests/ProxyFactoryAccount.bin: contracts/ProxyAccount.sol
	solc --bin --abi --optimize contracts/ProxyAccount.sol | awk '/======= TimeLockedGolemFactoryProxyAccount =======/,0' | grep '[01-9a-f]\{10,\}' > tests/ProxyFactoryAccount.bin

tests/ProxyFactoryAccount.abi: contracts/ProxyAccount.sol
	solc --bin --abi --optimize contracts/ProxyAccount.sol | awk '/======= TimeLockedGolemFactoryProxyAccount =======/,0' | grep '\[.*\]' > tests/ProxyFactoryAccount.abi

tests/GNTAllocation.bin: contracts/GNTAllocation.sol
	solc --bin --abi --optimize contracts/GNTAllocation.sol | awk '/======= GNTAllocation =======/,/======= GolemNetworkToken =======/' | grep '[01-9a-f]\{10,\}' > tests/GNTAllocation.bin

tests/GNTAllocation.abi: contracts/GNTAllocation.sol
	solc --bin --abi --optimize contracts/GNTAllocation.sol | awk '/======= GNTAllocation =======/,/======= GolemNetworkToken =======/' | grep '\[.*\]' > tests/GNTAllocation.abi

clean:
	rm -f tests/*.bin tests/*.abi
