// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import {HEAT} from "../src/HEAT.sol";
import {NetworkAwareScript} from "./NetworkAwareScript.s.sol";

/*
 * Sets the send library for a specific dst EID.
 * Must be called once for each dst EID.
 */
contract UpdateLayerZeroSendLib is NetworkAwareScript {
    error InvalidLzEid();

    function run() public {
        uint256 _ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 _dstChainId = vm.envUint("DST_CHAIN_ID");

        HEAT _heat = HEAT(vm.envAddress(_heatEnvVar(block.chainid)));
        address _dstHeat = vm.envAddress(_heatEnvVar(_dstChainId));

        ILayerZeroEndpointV2 _lzEndpoint = _heat.endpoint();

        uint32 _eid = _lzEndpoint.eid();
        if (_eid != _lzEid(block.chainid)) {
            revert InvalidLzEid();
        }
        uint32 _dstEid = _lzEid(_dstChainId);

        vm.startBroadcast(_ownerPrivateKey);

        _heat.setPeer(_dstEid, bytes32(uint256(uint160(_dstHeat))));

        vm.stopBroadcast();
    }
}
