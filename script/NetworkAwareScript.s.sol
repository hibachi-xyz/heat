// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {Script} from "forge-std/Script.sol";

abstract contract NetworkAwareScript is Script {
    error UnrecognizedChainId(uint256);

    function _allChainIds(uint256 _chainId) internal view returns (uint256[] memory) {
        if (_isTestnet(_chainId)) {
            return vm.parseJsonUintArray(vm.envString("ALL_CHAIN_IDS_TESTNET"), ".");
        } else {
            return vm.parseJsonUintArray(vm.envString("ALL_CHAIN_IDS_MAINNET"), ".");
        }
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

    function _isTestnet(uint256 chainId) internal pure returns (bool) {
        if (chainId == 8453) return false;
        if (chainId == 42161) return false;

        return true;
    }

    function _lzEid(uint256 chainId) internal pure returns (uint32) {
        if (chainId == 8453) return 30184;
        if (chainId == 42161) return 30110;

        // testnets
        if (chainId == 84532) return 40245;
        if (chainId == 11155111) return 40161;

        revert UnrecognizedChainId(chainId);
    }

    function _networkEnvVarId(uint256 chainId) private pure returns (string memory) {
        if (chainId == 8453) return "BASE";
        if (chainId == 42161) return "ARBITRUM";

        // testnets
        if (chainId == 84532) return "BASE_SEPOLIA";
        if (chainId == 11155111) return "SEPOLIA";

        revert UnrecognizedChainId(chainId);
    }
}
