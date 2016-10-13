.PHONY: tests clean

tests: tests/GolemNetworkToken.abi tests/GolemNetworkToken.bin
	pytest tests

tests/GolemNetworkToken.bin: contracts/Token.sol
	solc --bin --abi --optimize --optimize_runs=1000 contracts/Token.sol | awk '/======= GolemNetworkToken =======/,/======= MigrationAgent =======/' | grep '[01-9a-f]\{10,\}' > tests/GolemNetworkToken.bin

tests/GolemNetworkToken.abi: contracts/Token.sol
	solc --bin --abi --optimize --optimize_runs=1000 contracts/Token.sol | awk '/======= GolemNetworkToken =======/,/======= MigrationAgent =======/' | grep '\[.*\]' > tests/GolemNetworkToken.abi

clean:
	git checkout -- tests/GolemNetworkToken.bin tests/GolemNetworkToken.abi
