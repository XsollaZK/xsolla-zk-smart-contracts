// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {
    StdConfigBasedEip4337FactoryConfiguration
} from "xsolla/scripts/di/configurations/StdConfigBasedEip4337FactoryConfiguration.s.sol";
import {
    StdConfigBasedGuardianExecutorConfiguration
} from "xsolla/scripts/di/configurations/StdConfigBasedGuardianExecutorConfiguration.s.sol";
import {
    StdConfigBasedXsollaRecoveryExecutorConfiguration
} from "xsolla/scripts/di/configurations/StdConfigBasedXsollaRecoveryExecutorConfiguration.s.sol";

import { console } from "forge-std/console.sol";

import { Autowirable } from "xsolla/scripts/di/Autowirable.s.sol";
import { Sources } from "xsolla/scripts/di/libraries/Sources.s.sol";

contract SSO is Autowirable {
    using ShortStrings for ShortString;
    using Sources for Sources.Source;

    string public constant ALICE_SMART_ACC = "Alice";

    StdConfigBasedEip4337FactoryConfiguration private eip4337FactoryConfig;
    StdConfigBasedGuardianExecutorConfiguration private guardianExecutorConfig;
    StdConfigBasedXsollaRecoveryExecutorConfiguration private xsollaRecoveryConfig;

    function deployFactory()
        public
        proxywire(Sources.Source.EOAKeyValidator)
        proxywire(Sources.Source.SessionKeyValidator)
        proxywire(Sources.Source.WebAuthnValidator)
        configwire(guardianExecutorConfig)
        configwire(xsollaRecoveryConfig)
        configwire(eip4337FactoryConfig)
        accountwire(ALICE_SMART_ACC)
    {
        console.log(
            "EOAKeyValidator:",
            autowired(Sources.Source.TransparentUpgradeableProxy, Sources.Source.EOAKeyValidator.toString())
        );
        console.log(
            "SessionKeyValidator:",
            autowired(Sources.Source.TransparentUpgradeableProxy, Sources.Source.SessionKeyValidator.toString())
        );
        console.log(
            "WebAuthnValidator:",
            autowired(Sources.Source.TransparentUpgradeableProxy, Sources.Source.WebAuthnValidator.toString())
        );
        console.log(
            "GuardianExecutor:",
            autowired(Sources.Source.TransparentUpgradeableProxy, Sources.Source.GuardianExecutor.toString())
        );
        console.log("UpgradeableBeacon:", autowired(Sources.Source.UpgradeableBeacon));
        console.log(
            "MSAFactory:", autowired(Sources.Source.TransparentUpgradeableProxy, Sources.Source.MSAFactory.toString())
        );
        console.log(
            "ModularSmartAccount implementation:", autowired(Sources.Source.ModularSmartAccount, ALICE_SMART_ACC)
        );
    }

    function setUp() public {
        eip4337FactoryConfig = new StdConfigBasedEip4337FactoryConfiguration(vm, wiringMechanism, msg.sender);
        guardianExecutorConfig = new StdConfigBasedGuardianExecutorConfiguration(vm, wiringMechanism, msg.sender);
        xsollaRecoveryConfig = new StdConfigBasedXsollaRecoveryExecutorConfiguration(
            vm, wiringMechanism, msg.sender, msg.sender, msg.sender
        );
    }

    function run() public {
        deployFactory();
    }
}
