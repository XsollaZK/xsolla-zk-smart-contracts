// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Vm } from "forge-std/Vm.sol";
import { StdConfig } from "forge-std/StdConfig.sol";

import { Sources } from "xsolla/scripts/di/libraries/Sources.s.sol";
import { IConfiguration } from "xsolla/scripts/di/interfaces/IConfiguration.s.sol";
import { IWiringMechanism } from "xsolla/scripts/di/interfaces/IWiringMechanism.s.sol";
import { StdConfigBasedWiring } from "xsolla/scripts/di/wiring/StdConfigBasedWiring.s.sol";

import { XsollaRecoveryExecutor } from "src/xsolla/modules/XsollaRecoveryExecutor.sol";

contract StdConfigBasedXsollaRecoveryExecutorConfiguration is IConfiguration {
    using Sources for Sources.Source;

    StdConfig private config;
    Vm private vm;
    address private admin;
    address private finalizer;
    address private submitter;

    constructor(
        Vm _vm,
        IWiringMechanism _configBasedWiringMechanism,
        address _admin,
        address _finalizer,
        address _submitter
    ) {
        config = StdConfigBasedWiring(address(_configBasedWiringMechanism)).getConfig();
        vm = _vm;
        admin = _admin;
        finalizer = _finalizer;
        submitter = _submitter;
    }

    function name() external view override returns (string memory) {
        return "XsollaRecoveryExecutor Configuration";
    }

    function startAutowiringSources() external override {
        // Read required validator implementations from config
        address webAuthnValidator = config.get(Sources.Source.WebAuthnValidator.toString()).toAddress();
        address eoaKeyValidator = config.get(Sources.Source.EOAKeyValidator.toString()).toAddress();

        vm.startBroadcast();
        XsollaRecoveryExecutor recoveryExecutor = new XsollaRecoveryExecutor(webAuthnValidator, eoaKeyValidator);
        recoveryExecutor.initialize(admin, finalizer, submitter);
        vm.stopBroadcast();

        // Store the recovery executor address under the plain source key
        config.set(Sources.Source.XsollaRecoveryExecutor.toString(), address(recoveryExecutor));
    }
}
