.PHONY: tests clean

tests: build
	pytest tests

build: tests/GolemNetworkToken.abi tests/GolemNetworkToken.bin tests/GNTTargetToken.bin tests/GNTTargetToken.abi tests/MigrationAgent.bin tests/MigrationAgent.abi tests/BadWallet.bin tests/BadWallet.abi

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
	solc --bin --abi --optimize contracts/BadWallet.sol | awk '/======= BadWallet =======/,/======= GolemNetworkToken =======/' | grep '[01-9a-f]\{10,\}' > tests/BadWallet.bin

tests/BadWallet.abi: contracts/BadWallet.sol
	solc --bin --abi --optimize contracts/BadWallet.sol | awk '/======= BadWallet =======/,/======= GolemNetworkToken =======/' | grep '\[.*\]' > tests/BadWallet.abi

clean:
	git checkout -- tests/GolemNetworkToken.bin tests/GolemNetworkToken.abi tests/GNTTargetToken.bin tests/GNTTargetToken.abi tests/MigrationAgent.bin tests/MigrationAgent.abi
