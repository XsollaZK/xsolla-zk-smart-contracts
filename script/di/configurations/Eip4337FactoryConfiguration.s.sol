// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { Vm } from "forge-std/Vm.sol";
import { StdConfig } from "forge-std/StdConfig.sol";
import { LibVariable, Variable } from "forge-std/LibVariable.sol";

import { MSAFactory } from "src/MSAFactory.sol";
import { ModularSmartAccount } from "src/ModularSmartAccount.sol";

import { Sources } from "xsolla/scripts/di/libraries/Sources.s.sol";
import { IConfiguration } from "xsolla/scripts/di/interfaces/IConfiguration.s.sol";
import { IWiringMechanism } from "xsolla/scripts/di/interfaces/IWiringMechanism.s.sol";
import { StdConfigBasedWiring } from "xsolla/scripts/di/wiring/StdConfigBasedWiring.s.sol";
import { TUPConfiguration } from "xsolla/scripts/di/configurations/TUPConfiguration.s.sol";

contract Eip4337FactoryConfiguration is IConfiguration {
    using ShortStrings for ShortString;
    using Sources for Sources.Source;
    using LibVariable for Variable;

    StdConfig private config;
    address private beaconOwner;
    Vm private vm;

    constructor(Vm _vm, IWiringMechanism _configBasedWiringMechanism, address _beaconOwner) {
        config = StdConfigBasedWiring(address(_configBasedWiringMechanism)).getConfig();
        beaconOwner = _beaconOwner;
        vm = _vm;
    }

    function name() external view override returns (string memory) {
        return "Simple EIP-4337 smart account Factory deployment Configuration";
    }

    function startAutowiringSources() external override {
        vm.startBroadcast();
        address accountImpl = address(new ModularSmartAccount());
        config.set(Sources.Source.ModularSmartAccount.toString(), accountImpl);
        address beacon = address(new UpgradeableBeacon(accountImpl, beaconOwner));
        config.set(Sources.Source.UpgradeableBeacon.toString(), beacon);
        address factoryImpl = address(new MSAFactory(beacon));
        config.set(Sources.Source.MSAFactory.toString(), factoryImpl);
        vm.stopBroadcast();
        TUPConfiguration tupConfig =
            new TUPConfiguration(vm, config, beaconOwner, factoryImpl, Sources.Source.MSAFactory);
        tupConfig.startAutowiringSources();
    }
}
