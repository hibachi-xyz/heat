// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {console2} from "forge-std/console2.sol";

import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import {HEAT} from "../src/HEAT.sol";
import {NetworkAwareScript} from "./NetworkAwareScript.s.sol";

/*
 * Sets the send library for a specific dst EID.
 * Must be called once for each dst EID.
 */
contract UpdateLayerZeroPeers is NetworkAwareScript {
    error InvalidLzEid();

    function run() public {
        uint256 _ownerPrivateKey = vm.envUint("PRIVATE_KEY");

        uint256 _chainId = block.chainid;
        console2.log("Chain ID", _chainId);

        HEAT _heat = HEAT(vm.envAddress(_heatEnvVar(_chainId)));

        ILayerZeroEndpointV2 _lzEndpoint = _heat.endpoint();

        uint32 _eid = _lzEndpoint.eid();
        if (_eid != _lzEid(block.chainid)) {
            revert InvalidLzEid();
        }
        console2.log("EID", _eid);

        uint256[] memory allChainIds = _allChainIds(_chainId);

        vm.startBroadcast(_ownerPrivateKey);

        for (uint256 i = 0; i < allChainIds.length; i += 1) {
            uint256 _dstChainId = allChainIds[i];
            if (_dstChainId == _chainId) {
                continue;
            }

            console2.log("Dst Chain ID", _dstChainId);
            uint32 _dstEid = _lzEid(_dstChainId);
            console2.log("Dst EID", _dstEid);

            address _dstHeat = vm.envAddress(_heatEnvVar(_dstChainId));

            _heat.setPeer(_dstEid, bytes32(uint256(uint160(_dstHeat))));

            console2.log("Set peer", _dstHeat, "for dst EID", _dstEid);
        }

        vm.stopBroadcast();
    }
}
