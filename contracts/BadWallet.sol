pragma solidity ^0.4.4;

import * as Source from "./Token.sol";

contract BadWallet {
    uint16 extra_work = 0; // amount of work to be done when accepting payment
    uint16 public out_i;
    address wallet;

    function BadWallet() {
    }

    function get_out_i() returns (uint16 a) {
        return out_i;
    }

    function set_extra_work(uint16 _extra_work) {
        extra_work = _extra_work;
    }

    function get_extra_work() returns (uint16 a) {
        return extra_work;
    }

    function deploy_contract(address _golemFactory, uint256 _fundingStartBlock,
                             uint256 _fundingEndBlock)
        returns (address a) {

        wallet = new Source.GolemNetworkToken(_golemFactory, _golemFactory,
                                              _fundingStartBlock,
                                              _fundingEndBlock);
        return wallet;
    }

    function finalize(address _crowdfundingContract) {
        Source.GolemNetworkToken(_crowdfundingContract).finalize();
    }

    /* trap function which will burn gas, causing send to fail */
    function() payable {
        for (uint16 i = 1; i <= extra_work; i++) {
            out_i = i;
        }
    }
}
