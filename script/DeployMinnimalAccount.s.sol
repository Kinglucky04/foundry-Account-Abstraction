// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinnimalAccount} from "../src/Ethereum/MinnimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMinnimalAccount is Script {
    function run() external {
        deployMinnimalAccount();
    }

    function deployMinnimalAccount() public returns (MinnimalAccount, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        MinnimalAccount minnimalAccount = new MinnimalAccount(config.entryPoint);
        minnimalAccount.transferOwnership(config.account);
        vm.stopBroadcast();
        return (minnimalAccount, helperConfig);
    }
}
