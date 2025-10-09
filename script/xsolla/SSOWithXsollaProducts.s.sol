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
import { XsollaRecoveryExecutor } from "src/xsolla/modules/XsollaRecoveryExecutor.sol";
import { ModularSmartAccount } from "src/ModularSmartAccount.sol";

import { DeployStage } from "./base/DeployStage.s.sol";
import { Artifacts } from "./base/Artifacts.s.sol";
import { SSO } from "./SSO.s.sol";

contract SSOWithXsollaProducts is DeployStage {
    using Artifacts for Artifacts.Artifact;

    // Simple example of unique ID usage
    bytes32 private constant ID_OF_TUP_XSOLLA_RECOVERY_EXECUTOR = keccak256("TransparentUpgradeableProxy:xsolla-recovery-executor");

    function deployFactory() 
        public 
        withConfiguration(Kind.DEBUG)
        defineUniqueInjection(
            Artifacts.Artifact.TransparentUpgradeableProxy, ID_OF_TUP_XSOLLA_RECOVERY_EXECUTOR
        )
        returns (
            address factory, 
            address[] memory extendedModules
        )
    {
        SSO ssoStage = new SSO();
        address[] memory defaultModules = new address[](4);
        extendedModules = new address[](5);
        (factory, defaultModules) = ssoStage.deployFactory();
        for (uint256 i = 0; i < defaultModules.length; i++) {
            extendedModules[i] = defaultModules[i];
        }
        vm.startBroadcast();
        extendedModules[4] = _makeTUPWithId(
            address(
                new XsollaRecoveryExecutor(defaultModules[2], defaultModules[0], msg.sender, msg.sender, msg.sender)
            ),
            ID_OF_TUP_XSOLLA_RECOVERY_EXECUTOR
        );

        vm.stopBroadcast();
        console.log("XsollaRecoveryExecutor:", extendedModules[4]);
    }

    function setUp() public { }

    function run() public {
        (address factoryAddr, address[] memory modules) = deployFactory();
        _deployAccount(factoryAddr, modules, keccak256(abi.encodePacked(block.timestamp)), 0);
    }
}
