// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { Vm } from "forge-std/Vm.sol";
import { StdConfig } from "forge-std/StdConfig.sol";

import { Sources } from "xsolla/scripts/di/libraries/Sources.s.sol";
import { IConfiguration } from "xsolla/scripts/di/interfaces/IConfiguration.s.sol";

contract StdConfigBasedTUPConfiguration is IConfiguration {
    using ShortStrings for ShortString;
    using Sources for Sources.Source;

    address private implementation;
    address private proxyOwner;
    StdConfig private config;
    Vm private vm;
    Sources.Source private implementationSource;

    constructor(
        Vm _vm,
        StdConfig _config,
        address _proxyOwner,
        address _implementation,
        Sources.Source _implementationSource
    ) {
        vm = _vm;
        implementation = _implementation;
        config = _config;
        proxyOwner = _proxyOwner;
        implementationSource = _implementationSource;
    }

    function name() external view override returns (string memory) {
        return "Simple TUP wrapper Configuration";
    }

    function startAutowiringSources() external override {
        vm.broadcast();
        address proxy = address(new TransparentUpgradeableProxy(implementation, proxyOwner, ""));
        config.set(getProxySourceKey(), proxy);
    }

    function getProxySourceKey() public view returns (string memory) {
        return Sources.Source.TransparentUpgradeableProxy
            .getFullNicknamedName(ShortStrings.toShortString(implementationSource.toString()));
    }
}
