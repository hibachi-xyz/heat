// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {Script} from "forge-std/Script.sol";

abstract contract NetworkAwareScript is Script {
    error UnrecognizedChainId(uint256);

    function _allChainIds() internal view returns (uint256[] memory) {
        string memory allChainIds = vm.envString("ALL_CHAIN_IDS");
        return vm.parseJsonUintArray(allChainIds, ".");
    }

    function _initialSupplyEnvVar(uint256 chainId) internal pure returns (string memory) {
        return string(abi.encodePacked("INITIAL_SUPPLY_", _networkEnvVarId(chainId)));
    }

    function _heatEnvVar(uint256 chainId) internal pure returns (string memory) {
        return string(abi.encodePacked("HEAT_", _networkEnvVarId(chainId)));
    }

    function _lzEndpointEnvVar(uint256 chainId) internal pure returns (string memory) {
        return string(abi.encodePacked("LZ_ENDPOINT_", _networkEnvVarId(chainId)));
    }

    function _lzExecutorEnvVar(uint256 chainId) internal pure returns (string memory) {
        return string(abi.encodePacked("LZ_EXECUTOR_", _networkEnvVarId(chainId)));
    }

    function _lzSendLibEnvVar(uint256 chainId) internal pure returns (string memory) {
        return string(abi.encodePacked("LZ_SEND_LIB_", _networkEnvVarId(chainId)));
    }

    function _lzReceiveLibEnvVar(uint256 chainId) internal pure returns (string memory) {
        return string(abi.encodePacked("LZ_RECEIVE_LIB_", _networkEnvVarId(chainId)));
    }

    function _lzDvnAEnvVar(uint256 chainId) internal pure returns (string memory) {
        return string(abi.encodePacked("LZ_DVN_A_", _networkEnvVarId(chainId)));
    }

    function _lzDvnBEnvVar(uint256 chainId) internal pure returns (string memory) {
        return string(abi.encodePacked("LZ_DVN_B_", _networkEnvVarId(chainId)));
    }

    function _lzConfirmationsEnvVar(uint256 chainId) internal pure returns (string memory) {
        return string(abi.encodePacked("LZ_CONFIRMATIONS_", _networkEnvVarId(chainId)));
    }

    function _lzEid(uint256 chainId) internal pure returns (uint32) {
        if (chainId == 8453) return 30184;
        if (chainId == 42161) return 30110;

        revert UnrecognizedChainId(chainId);
    }

    function _networkEnvVarId(uint256 chainId) private pure returns (string memory) {
        if (chainId == 8453) return "BASE";
        if (chainId == 42161) return "ARBITRUM";

        revert UnrecognizedChainId(chainId);
    }
}
