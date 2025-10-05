// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { console } from "forge-std/console.sol";

import { MSAFactory } from "src/MSAFactory.sol";
import { EOAKeyValidator } from "src/modules/EOAKeyValidator.sol";
import { SessionKeyValidator } from "src/modules/SessionKeyValidator.sol";
import { WebAuthnValidator } from "src/modules/WebAuthnValidator.sol";
import { GuardianExecutor } from "src/modules/GuardianExecutor.sol";
import { ModularSmartAccount } from "src/ModularSmartAccount.sol";

contract Deploy is Script {
    function makeProxy(address impl) internal returns (address) {
        return address(new TransparentUpgradeableProxy(impl, msg.sender, ""));
    }

    function deployFactory() internal returns (address factory, address[] memory defaultModules) {
        vm.startBroadcast();

        defaultModules = new address[](4);
        defaultModules[0] = _makeTUP(address(new EOAKeyValidator()));
        defaultModules[1] = _makeTUP(address(new SessionKeyValidator()));
        defaultModules[2] = _makeTUP(address(new WebAuthnValidator()));
        defaultModules[3] = _makeTUP(address(new GuardianExecutor(defaultModules[2], defaultModules[0])));

        address accountImpl = address(new ModularSmartAccount());
        address beacon = address(new UpgradeableBeacon(accountImpl, msg.sender));
        factory = _makeTUP(address(new MSAFactory(beacon)));

        vm.stopBroadcast();

        console.log("EOAKeyValidator:", defaultModules[0]);
        console.log("SessionKeyValidator:", defaultModules[1]);
        console.log("WebAuthnValidator:", defaultModules[2]);
        console.log("GuardianExecutor:", defaultModules[3]);
        console.log("ModularSmartAccount implementation:", accountImpl);
        console.log("UpgradeableBeacon:", beacon);
        console.log("MSAFactory:", factory);
    }

    function setUp() public {}

    function run() public {
        (address factoryAddr, address[] memory modules) = deployFactory();
        _deployAccount(factoryAddr, modules, DEFAULT_ACCOUNT_ID);
    }
}
