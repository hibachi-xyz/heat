// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {HEAT} from "../src/HEAT.sol";
import {DVNFeeStub, ExecutorFeeStub} from "../test/mocks/WorkerFeeStubs.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {EndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/EndpointV2.sol";
import {SendUln302} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/uln302/SendUln302.sol";
import {ReceiveUln302} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/uln302/ReceiveUln302.sol";
import {UlnConfig, SetDefaultUlnConfigParam} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {
    ExecutorConfig,
    SetDefaultExecutorConfigParam
} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";

/// @title Local LayerZero stack for HEAT bridge integration testing.
/// @notice Deploys the REAL protocol contracts (`EndpointV2`, `SendUln302`,
/// `ReceiveUln302`) plus HEAT behind its proxy on a local node (anvil), with
/// the only mocked pieces being the two send-side worker fee stubs. An
/// off-chain harness EOA plays DVN + executor:
///   - it is registered as the required DVN in the receive-side ULN config,
///     so `ReceiveUln302.verify` + `commitVerification` are plain txs;
///   - delivery is the permissionless `EndpointV2.lzReceive`.
///
/// Two phases (peers can only be wired once both chains are deployed):
///
///   1. `run()` per chain — deploy + configure everything local:
///        forge script script/SetupLocalLz.s.sol --rpc-url $RPC --broadcast
///      env: PRIVATE_KEY, LOCAL_EID, REMOTE_EID, HARNESS_DVN,
///           INITIAL_SUPPLY (wei), WORKER_FEE_WEI (optional, default 1e14)
///
///   2. `wire()` per chain — connect the two deployments:
///        forge script script/SetupLocalLz.s.sol --sig "wire()" --rpc-url $RPC --broadcast
///      env: PRIVATE_KEY, LOCAL_OFT, REMOTE_OFT, REMOTE_EID,
///           ENFORCED_LZ_RECEIVE_GAS (optional, default 80_000)
///
/// Addresses are logged as `SETUP_LZ:<key>=<address>` lines for the Rust
/// fixture to parse from stdout.
contract SetupLocalLz is Script {
    using OptionsBuilder for bytes;

    uint256 internal constant DEFAULT_WORKER_FEE_WEI = 1e14; // 0.0001 ETH
    uint256 internal constant TREASURY_GAS_LIMIT = 200_000;
    uint256 internal constant TREASURY_GAS_FOR_FEE_CAP = 200_000;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerKey);
        uint32 localEid = uint32(vm.envUint("LOCAL_EID"));
        uint32 remoteEid = uint32(vm.envUint("REMOTE_EID"));
        address harnessDvn = vm.envAddress("HARNESS_DVN");
        uint256 initialSupply = vm.envUint("INITIAL_SUPPLY");
        uint256 workerFee = vm.envOr("WORKER_FEE_WEI", DEFAULT_WORKER_FEE_WEI);

        vm.startBroadcast(deployerKey);

        // ── Real protocol stack ─────────────────────────────────────────
        EndpointV2 endpoint = new EndpointV2(localEid, owner);
        SendUln302 sendUln = new SendUln302(address(endpoint), TREASURY_GAS_LIMIT, TREASURY_GAS_FOR_FEE_CAP);
        ReceiveUln302 receiveUln = new ReceiveUln302(address(endpoint));
        DVNFeeStub dvnFeeStub = new DVNFeeStub(workerFee);
        ExecutorFeeStub executorFeeStub = new ExecutorFeeStub(workerFee);

        endpoint.registerLibrary(address(sendUln));
        endpoint.registerLibrary(address(receiveUln));

        // ── Send-side defaults: fee-stub workers, 1 confirmation ────────
        // NOTE: default ULN/executor configs MUST be set on the libraries
        // before `setDefault{Send,Receive}Library` — a ULN lib reports
        // `isSupportedEid == false` (⇒ `LZ_UnsupportedEid`) until a default
        // config exists for that eid.
        address[] memory sendDvns = new address[](1);
        sendDvns[0] = address(dvnFeeStub);
        SetDefaultUlnConfigParam[] memory sendUlnCfg = new SetDefaultUlnConfigParam[](1);
        sendUlnCfg[0] = SetDefaultUlnConfigParam({
            eid: remoteEid,
            config: UlnConfig({
                confirmations: 1,
                requiredDVNCount: 1,
                optionalDVNCount: 0,
                optionalDVNThreshold: 0,
                requiredDVNs: sendDvns,
                optionalDVNs: new address[](0)
            })
        });
        sendUln.setDefaultUlnConfigs(sendUlnCfg);

        SetDefaultExecutorConfigParam[] memory execCfg = new SetDefaultExecutorConfigParam[](1);
        execCfg[0] = SetDefaultExecutorConfigParam({
            eid: remoteEid,
            config: ExecutorConfig({maxMessageSize: 10_000, executor: address(executorFeeStub)})
        });
        sendUln.setDefaultExecutorConfigs(execCfg);

        // ── Receive-side defaults: the HARNESS EOA is the required DVN ──
        address[] memory receiveDvns = new address[](1);
        receiveDvns[0] = harnessDvn;
        SetDefaultUlnConfigParam[] memory receiveUlnCfg = new SetDefaultUlnConfigParam[](1);
        receiveUlnCfg[0] = SetDefaultUlnConfigParam({
            eid: remoteEid,
            config: UlnConfig({
                confirmations: 1,
                requiredDVNCount: 1,
                optionalDVNCount: 0,
                optionalDVNThreshold: 0,
                requiredDVNs: receiveDvns,
                optionalDVNs: new address[](0)
            })
        });
        receiveUln.setDefaultUlnConfigs(receiveUlnCfg);

        endpoint.setDefaultSendLibrary(remoteEid, address(sendUln));
        endpoint.setDefaultReceiveLibrary(remoteEid, address(receiveUln), 0);

        // ── HEAT behind its proxy ───────────────────────────────────────
        HEAT implementation = new HEAT(address(endpoint));
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation), abi.encodeCall(HEAT.initialize, (owner, owner, initialSupply))
        );

        vm.stopBroadcast();

        console2.log("SETUP_LZ:endpoint=%s", address(endpoint));
        console2.log("SETUP_LZ:send_uln=%s", address(sendUln));
        console2.log("SETUP_LZ:receive_uln=%s", address(receiveUln));
        console2.log("SETUP_LZ:dvn_fee_stub=%s", address(dvnFeeStub));
        console2.log("SETUP_LZ:executor_fee_stub=%s", address(executorFeeStub));
        console2.log("SETUP_LZ:heat_impl=%s", address(implementation));
        console2.log("SETUP_LZ:heat=%s", address(proxy));
    }

    /// Phase 2: wire this chain's HEAT to the remote deployment.
    function wire() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address localOft = vm.envAddress("LOCAL_OFT");
        address remoteOft = vm.envAddress("REMOTE_OFT");
        uint32 remoteEid = uint32(vm.envUint("REMOTE_EID"));
        uint128 enforcedGas = uint128(vm.envOr("ENFORCED_LZ_RECEIVE_GAS", uint256(80_000)));

        vm.startBroadcast(deployerKey);

        HEAT heat = HEAT(localOft);
        heat.setPeer(remoteEid, bytes32(uint256(uint160(remoteOft))));

        EnforcedOptionParam[] memory enforced = new EnforcedOptionParam[](1);
        enforced[0] = EnforcedOptionParam({
            eid: remoteEid,
            msgType: 1, // SEND
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(enforcedGas, 0)
        });
        heat.setEnforcedOptions(enforced);

        vm.stopBroadcast();

        console2.log("SETUP_LZ:wired_peer=%s", remoteOft);
    }
}
