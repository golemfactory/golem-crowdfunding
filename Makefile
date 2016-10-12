.PHONY: tests clean

tests: tests/abi tests/bin
	pytest tests

tests/bin: contracts/Token.sol
	solc --bin --abi --optimize --optimize_runs=1000 contracts/Token.sol | awk '/======= GolemNetworkToken =======/,/======= MigrationAgent =======/' | grep '[01-9a-f]\{10,\}' > tests/bin

tests/abi: contracts/Token.sol
	solc --bin --abi --optimize --optimize_runs=1000 contracts/Token.sol | awk '/======= GolemNetworkToken =======/,/======= MigrationAgent =======/' | grep '\[.*\]' > tests/abi

clean:
	git checkout -- tests/bin tests/abi
