// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { MSAFactory } from "src/MSAFactory.sol";
import { ModularSmartAccount } from "src/ModularSmartAccount.sol";

import { Configuration } from "./Configuration.s.sol";
import { Artifacts } from "./Artifacts.s.sol";

abstract contract DeployStage is Script, Configuration {
    using Artifacts for Artifacts.Artifact;

    function _makeTUPWithId(address impl, bytes32 uniqueId) internal virtual returns (address) {
        return address(new TransparentUpgradeableProxy{salt: Artifacts.Artifact.TransparentUpgradeableProxy.toSalt(uniqueId)}(impl, msg.sender, ""));
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
