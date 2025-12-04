// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { Vm } from "forge-std/Vm.sol";
import { StdConfig } from "forge-std/StdConfig.sol";

import { GuardianExecutor } from "src/modules/GuardianExecutor.sol";

import { Sources } from "xsolla/scripts/di/libraries/Sources.s.sol";
import { IConfiguration } from "xsolla/scripts/di/interfaces/IConfiguration.s.sol";
import { IWiringMechanism } from "xsolla/scripts/di/interfaces/IWiringMechanism.s.sol";
import { StdConfigBasedWiring } from "xsolla/scripts/di/wiring/StdConfigBasedWiring.s.sol";
import { TUPConfiguration } from "xsolla/scripts/di/configurations/TUPConfiguration.s.sol";

contract GuardianExecutorConfiguration is IConfiguration {
    using ShortStrings for ShortString;
    using Sources for Sources.Source;

    StdConfig private config;
    address private proxyOwner;
    Vm private vm;

    constructor(Vm _vm, IWiringMechanism _configBasedWiringMechanism, address _proxyOwner) {
        config = StdConfigBasedWiring(address(_configBasedWiringMechanism)).getConfig();
        proxyOwner = _proxyOwner;
        vm = _vm;
    }

    function name() external view override returns (string memory) {
        return "GuardianExecutor Configuration";
    }

    function startAutowiringSources() external override {
        address webAuthnValidator = config.get(
                Sources.Source.TransparentUpgradeableProxy
                    .getFullNicknamedName(ShortStrings.toShortString(Sources.Source.WebAuthnValidator.toString()))
            ).toAddress();
        address eoaKeyValidator = config.get(
                Sources.Source.TransparentUpgradeableProxy
                    .getFullNicknamedName(ShortStrings.toShortString(Sources.Source.EOAKeyValidator.toString()))
            ).toAddress();

        vm.broadcast();
        address guardianExecutorImpl = address(new GuardianExecutor(webAuthnValidator, eoaKeyValidator));
        config.set(Sources.Source.GuardianExecutor.toString(), guardianExecutorImpl);

        TUPConfiguration tupConfig =
            new TUPConfiguration(vm, config, proxyOwner, guardianExecutorImpl, Sources.Source.GuardianExecutor);
        tupConfig.startAutowiringSources();
    }
}
