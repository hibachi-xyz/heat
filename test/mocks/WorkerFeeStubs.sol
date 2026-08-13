// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {ILayerZeroDVN} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/interfaces/ILayerZeroDVN.sol";
import {ILayerZeroExecutor} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/interfaces/ILayerZeroExecutor.sol";

/// @title Worker fee stubs for local-node LayerZero testing.
/// @notice The real `SendUln302` quotes and pays its configured workers on
/// every `send()`. These stubs satisfy that payment rail with a fixed fee so
/// the REAL endpoint + ULN302 libraries run unmodified on anvil, while the
/// actual verification (DVN) and delivery (executor) roles are played by an
/// off-chain harness EOA:
///   - verification: the harness is registered as the required DVN in the
///     RECEIVE-side ULN config (a plain address — it calls
///     `ReceiveUln302.verify` + `commitVerification` as normal txs);
///   - delivery: `EndpointV2.lzReceive` is permissionless.
/// Only the SEND-side fee-quoting surface needs contracts, and that is all
/// these stubs are.
contract DVNFeeStub is ILayerZeroDVN {
    uint256 public fee;

    constructor(uint256 _fee) {
        fee = _fee;
    }

    function setFee(uint256 _fee) external {
        fee = _fee;
    }

    function assignJob(AssignJobParam calldata, bytes calldata) external payable returns (uint256) {
        return fee;
    }

    function getFee(uint32, uint64, address, bytes calldata) external view returns (uint256) {
        return fee;
    }
}

contract ExecutorFeeStub is ILayerZeroExecutor {
    uint256 public fee;

    constructor(uint256 _fee) {
        fee = _fee;
    }

    function setFee(uint256 _fee) external {
        fee = _fee;
    }

    function assignJob(uint32, address, uint256, bytes calldata) external returns (uint256) {
        return fee;
    }

    function getFee(uint32, address, uint256, bytes calldata) external view returns (uint256) {
        return fee;
    }
}
