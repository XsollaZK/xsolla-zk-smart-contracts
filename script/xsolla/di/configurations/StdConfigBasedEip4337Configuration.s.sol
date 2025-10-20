// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { Vm } from "forge-std/Vm.sol";
import { StdConfig } from "forge-std/StdConfig.sol";
import { LibVariable, Variable } from "forge-std/LibVariable.sol";

import { MSAFactory } from "src/MSAFactory.sol";
import { ModularSmartAccount } from "src/ModularSmartAccount.sol";

import { Sources } from "xsolla/scripts/di/libraries/Sources.s.sol";
import { IConfiguration } from "xsolla/scripts/di/interfaces/IConfiguration.s.sol";

contract StdConfigBasedEip4337Configuration is IConfiguration {
    using ShortStrings for ShortString;
    using Sources for Sources.Source;
    using LibVariable for Variable;

    StdConfig private config;
    address private owner;
    ShortString private nickname;
    Vm private vm;

    constructor(Vm _vm, StdConfig _config, address _owner, ShortString _nickname) {
        config = _config;
        owner = _owner;
        nickname = _nickname;
        vm = _vm;
    }

    function name() external view override returns (string memory) {
        return "Simple EIP-4337 smart account deployment Configuration";
    }

    function startAutowiringSources() external override {
        address factory = config.get(
                Sources.Source.TransparentUpgradeableProxy
                .getFullNicknamedName(ShortStrings.toShortString("MSAFactory"))
            ).toAddress();
        address eoaKeyValidator = config.get(Sources.Source.EOAKeyValidator.toString()).toAddress();
        address sessionKeyValidator = config.get(Sources.Source.SessionKeyValidator.toString()).toAddress();
        address webAuthnValidator = config.get(Sources.Source.WebAuthnValidator.toString()).toAddress();
        address recoveryExecutor = config.get(Sources.Source.XsollaRecoveryExecutor.toString()).toAddress();
        address guardianExecutor = config.get(Sources.Source.GuardianExecutor.toString()).toAddress();
        address[] memory modules = new address[](5);
        modules[0] = eoaKeyValidator;
        modules[1] = sessionKeyValidator;
        modules[2] = webAuthnValidator;
        modules[3] = recoveryExecutor;
        modules[4] = guardianExecutor;
        bytes32 accountId = keccak256(abi.encodePacked(nickname, owner));
        // initData must align 1:1 with modules. Fill non-EOA modules with empty bytes.
        bytes[] memory initData = new bytes[](5);
        address[] memory accountOwners = new address[](1);
        accountOwners[0] = owner;
        initData[0] = abi.encode(accountOwners);
        bytes memory data = abi.encodeCall(ModularSmartAccount.initializeAccount, (modules, initData));
        vm.broadcast();
        address account = MSAFactory(factory).deployAccount(accountId, data);
        config.set(getAccountSourceKey(), account);
    }

    function getAccountSourceKey() public view returns (string memory) {
        return Sources.Source.ModularSmartAccount.getFullNicknamedName(nickname);
    }
}
