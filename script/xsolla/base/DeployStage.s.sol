// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { Script } from "forge-std/Script.sol";
import { Config } from "forge-std/Config.sol";
import { console } from "forge-std/console.sol";

import { MSAFactory } from "src/MSAFactory.sol";
import { ModularSmartAccount } from "src/ModularSmartAccount.sol";

// 1) Historical proxies - automatic
// 2) Cross-chain and cross-stage configs

abstract contract DeployStage is Script, Config {
    enum Configuration {
        PRODUCTION,
        DEBUG
    }

    string public constant DEFAULT_CONFIG_FOLDER = "./configurations/";

    modifier withConfiguration(Configuration config) {
        if (config == Configuration.PRODUCTION) {
            _loadConfig(string(abi.encodePacked(DEFAULT_CONFIG_FOLDER, "production.toml")), true);
        } else {
            _loadConfig(string(abi.encodePacked(DEFAULT_CONFIG_FOLDER, "debug.toml")), true);
        }
        _;
    }

    function _makeTUP(address impl) internal virtual returns (address) {
        return address(new TransparentUpgradeableProxy(impl, msg.sender, ""));
    }

    function _deployAccount(address factory, address[] memory modules, bytes32 accountId, uint256 amount)
        internal
        virtual
    {
        bytes[] memory initData = new bytes[](4);
        address[] memory accountOwners = new address[](1);
        accountOwners[0] = msg.sender;
        initData[0] = abi.encode(accountOwners);
        bytes memory data = abi.encodeCall(ModularSmartAccount.initializeAccount, (modules, initData));

        vm.startBroadcast();

        address account = MSAFactory(factory).deployAccount(accountId, data);
        if (amount > 0) {
            Address.sendValue(payable(account), amount);
            console.log("Sent", amount, "wei (ETH) to account", account);
        }

        vm.stopBroadcast();

        console.log("Initialized account:", account);
    }
}
