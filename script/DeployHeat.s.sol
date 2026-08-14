// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {console2} from "forge-std/console2.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import {NetworkAwareScript} from "./NetworkAwareScript.s.sol";

import {HEAT} from "../src/HEAT.sol";

contract DeployHeat is NetworkAwareScript {
    error InvalidLzEid();

    // slot used for storing the admin address in a TransparentUpgradeableProxy
    // this will be a ProxyAdmin contract address
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function run() public {
        uint256 _deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address _deployerAddress = vm.addr(_deployerPrivateKey);
        ILayerZeroEndpointV2 _layerZeroEndpoint = ILayerZeroEndpointV2(vm.envAddress(_lzEndpointEnvVar(block.chainid)));
        uint256 _initialSupply = vm.envUint(_initialSupplyEnvVar(block.chainid));

        console2.log("Chain ID", block.chainid);

        {
            uint32 _eid = _layerZeroEndpoint.eid();
            if (_eid != _lzEid(block.chainid)) {
                revert InvalidLzEid();
            }
        }

        vm.startBroadcast(_deployerPrivateKey);

        HEAT _heat = new HEAT(address(_layerZeroEndpoint));

        uint8 _decimals = _heat.decimals();

        bytes memory _initData =
            abi.encodeCall(HEAT.initialize, (_deployerAddress, _deployerAddress, _initialSupply * (10 ** _decimals)));

        TransparentUpgradeableProxy _proxy =
            new TransparentUpgradeableProxy(address(_heat), _deployerAddress, _initData);

        vm.stopBroadcast();

        console2.log("HEAT Impl deployed at", address(_heat));
        console2.log("HEAT Proxy deployed at", address(_proxy));

        address _proxyAdmin = address(uint160(uint256(vm.load(address(_proxy), ADMIN_SLOT))));
        console2.log("HEAT Proxy Admin deployed at", _proxyAdmin);

        console2.log("HEAT Owner is ", HEAT(address(_proxy)).owner());
    }
}
