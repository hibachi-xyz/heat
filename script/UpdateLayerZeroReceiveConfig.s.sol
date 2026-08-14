// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {console2} from "forge-std/console2.sol";

import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";

import {HEAT} from "../src/HEAT.sol";
import {NetworkAwareScript} from "./NetworkAwareScript.s.sol";

/*
 * Sets the receive config (DVN) for a specific dst EID.
 * Must be called once for each dst EID.
 */
contract UpdateLayerZeroReceiveConfig is NetworkAwareScript {
    error InvalidLzEid();

    uint32 internal constant RECEIVE_CONFIG_TYPE = 2;

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

        uint256[] memory allChainIds = _allChainIds();

        address _receiveLib = vm.envAddress(_lzReceiveLibEnvVar(block.chainid));

        console2.log("ReceiveLib", _receiveLib);

        address[] memory _requiredDvns = new address[](2);
        address[] memory _optionalDvns = new address[](0);

        {

            address _dvnA = vm.envAddress(_lzDvnAEnvVar(_chainId));
            address _dvnB = vm.envAddress(_lzDvnBEnvVar(_chainId));

            console2.log("DVN A", _dvnA);
            console2.log("DVN B", _dvnB);

            _requiredDvns[0] = _dvnA;
            _requiredDvns[1] = _dvnB;
        }

        vm.startBroadcast(_ownerPrivateKey);

        for (uint256 i = 0; i < allChainIds.length; i += 1) {
            uint256 _dstChainId = allChainIds[i];
            if (_dstChainId == _chainId) {
                continue;
            }

            console2.log("Dst Chain ID", _dstChainId);
            uint32 _dstEid = _lzEid(_dstChainId);
            console2.log("Dst EID", _dstEid);

            uint64 _confirmations = uint64(vm.envUint(_lzConfirmationsEnvVar(_dstChainId)));
            console2.log("Confirmations", _confirmations);

            SetConfigParam[] memory _params = new SetConfigParam[](1);

            UlnConfig memory uln = UlnConfig({
                confirmations: _confirmations,
                requiredDVNCount: 2,
                optionalDVNCount: type(uint8).max, // NIL_DVN_COUNT, to override the default (0)
                optionalDVNThreshold: 0,
                requiredDVNs: _requiredDvns, // this list MUST be sorted
                optionalDVNs: _optionalDvns // sorted list of optional DVNs
            });

            bytes memory _encodedUln = abi.encode(uln);

            _params[0] = SetConfigParam({eid: _dstEid, configType: RECEIVE_CONFIG_TYPE, config: _encodedUln});

            _lzEndpoint.setConfig(address(_heat), _receiveLib, _params);

            console2.log("Updated receive config for Dst Chain ID", _dstChainId);
        }

        vm.stopBroadcast();
    }
}
