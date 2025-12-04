// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";

import { Eip4337FactoryConfiguration } from "script/di/configurations/Eip4337FactoryConfiguration.s.sol";
import { GuardianExecutorConfiguration } from "script/di/configurations/GuardianExecutorConfiguration.s.sol";
import {
    GuardianBasedRecoveryExecutorConfiguration
} from "script/di/configurations/GuardianBasedRecoveryExecutorConfiguration.s.sol";
import { console } from "forge-std/console.sol";

import { Autowirable } from "script/di/Autowirable.s.sol";
import { Sources } from "script/di/libraries/Sources.s.sol";

contract SSO is Autowirable {
    using ShortStrings for ShortString;
    using Sources for Sources.Source;

    string public constant ALICE_SMART_ACC = "Alice";

    Eip4337FactoryConfiguration private eip4337FactoryConfig;
    GuardianExecutorConfiguration private guardianExecutorConfig;
    GuardianBasedRecoveryExecutorConfiguration private xsollaRecoveryConfig;

    function setUp() public {
        eip4337FactoryConfig = new Eip4337FactoryConfiguration(vm, wiringMechanism, msg.sender);
        guardianExecutorConfig = new GuardianExecutorConfiguration(vm, wiringMechanism, msg.sender);
        xsollaRecoveryConfig =
            new GuardianBasedRecoveryExecutorConfiguration(vm, wiringMechanism, msg.sender, msg.sender, msg.sender);
    }

    function run()
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
}
