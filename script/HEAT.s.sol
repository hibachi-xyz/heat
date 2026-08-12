// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {Script} from "forge-std/Script.sol";
import {HEAT} from "../src/HEAT.sol";

contract CounterScript is Script {
    HEAT public counter;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        counter = new HEAT(address(0));

        vm.stopBroadcast();
    }
}
