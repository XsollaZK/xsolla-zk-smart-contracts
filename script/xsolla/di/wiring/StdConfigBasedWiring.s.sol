// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";

import { Variable, TypeKind, LibVariable } from "forge-std/LibVariable.sol";
import { Config } from "forge-std/Config.sol";
import { console } from "forge-std/console.sol";

import { Sources } from "xsolla/scripts/di/libraries/Sources.s.sol";
import { IWiringMechanism } from "xsolla/scripts/di/interfaces/IWiringMechanism.s.sol";
import { IConfiguration } from "xsolla/scripts/di/interfaces/IConfiguration.s.sol";
import { StdConfigBasedTUPConfiguration } from "xsolla/scripts/di/StdConfigBasedTUPConfiguration.s.sol";

abstract contract StdConfigBasedWiring is IWiringMechanism, Config {
    using Sources for Sources.Source;
    using ShortStrings for ShortString;

    enum Kind {
        NONE,
        PRODUCTION,
        DEBUG
    }

    string public constant DEFAULT_CONFIG_FOLDER = "./configurations/";
    string public constant PRODUCTION_CONFIG_FILENAME = "production.toml";
    string public constant DEBUG_CONFIG_FILENAME = "debug.toml";

    error UnsupportedWiringType();
    error ChooseConfigurationFirst();
    error UnknownConfiguration();

    constructor() {
        withConfiguration(Kind.DEBUG);
    }

    function withMultiChainConfiguration(Kind configuration) public {
        if (configuration == Kind.PRODUCTION) {
            _loadConfigAndForks(string(abi.encodePacked(DEFAULT_CONFIG_FOLDER, PRODUCTION_CONFIG_FILENAME)), true);
        } else if (configuration == Kind.DEBUG) {
            _loadConfigAndForks(string(abi.encodePacked(DEFAULT_CONFIG_FOLDER, DEBUG_CONFIG_FILENAME)), true);
        } else {
            revert UnknownConfiguration();
        }
    }

    function withConfiguration(Kind configuration) public {
        if (configuration == Kind.PRODUCTION) {
            _loadConfig(string(abi.encodePacked(DEFAULT_CONFIG_FOLDER, PRODUCTION_CONFIG_FILENAME)), true);
        } else if (configuration == Kind.DEBUG) {
            _loadConfig(string(abi.encodePacked(DEFAULT_CONFIG_FOLDER, DEBUG_CONFIG_FILENAME)), true);
        } else {
            revert UnknownConfiguration();
        }
    }

    function wire(bytes memory wiringInfo, SupportedWiring wiringType) external virtual override returns (address) {
        if (address(config) == address(0)) {
            revert ChooseConfigurationFirst();
        }
        if (wiringType == SupportedWiring.PLAIN) {
            Sources.Source source = Sources.Source(abi.decode(wiringInfo, (uint256)));
            address wiredAddress = Create2.deploy(0, source.toSalt(), source.toCreationCode());
            config.set(source.toString(), wiredAddress);
            return wiredAddress;
        } else if (wiringType == SupportedWiring.PLAIN_NICKNAMED) {
            (Sources.Source source, ShortString nickname) = abi.decode(wiringInfo, (Sources.Source, ShortString));
            address wiredAddress = Create2.deploy(0, source.toSalt(nickname), source.toCreationCode());
            config.set(source.getFullNicknamedName(nickname), wiredAddress);
            return wiredAddress;
        } else if (wiringType == SupportedWiring.CONFIGURATION_BASED) {
            if (wiringInfo.length > 20) {
                (bytes32 proxyFlag, bytes memory deployerAndRestOfInfo) = abi.decode(wiringInfo, (bytes32, bytes));
                if (proxyFlag != Sources.NICKNAMED_PROXY_FLAG) {
                    revert UnsupportedWiringType();
                }
                (address deployerAddress, bytes memory restOfInfo) = abi.decode(deployerAndRestOfInfo, (address, bytes));
                if (deployerAddress == address(0)) {
                    revert UnsupportedWiringType();
                }
                Sources.Source source = Sources.Source(abi.decode(restOfInfo, (uint256)));
                address implAddress = Create2.deploy(0, source.toSalt(), source.toCreationCode());
                StdConfigBasedTUPConfiguration tupConfig =
                    new StdConfigBasedTUPConfiguration(config, deployerAddress, implAddress, source);
                tupConfig.startAutowiringSources();
                return config.get(tupConfig.getImplSourceKey()).toAddress();
            } else {
                (address configuration) = abi.decode(wiringInfo, (address));
                IConfiguration configContract = IConfiguration(configuration);
                configContract.startAutowiringSources();
                return address(0);
            }
        } else {
            revert UnsupportedWiringType();
        }
    }

    function getWiredVariants(bytes memory wiringInfo, SupportedWiring wiringType)
        external
        view
        virtual
        override
        returns (address[] memory result)
    {
        if (address(config) == address(0)) {
            revert ChooseConfigurationFirst();
        }
        result = new address[](1);
        if (wiringType == SupportedWiring.PLAIN) {
            Sources.Source source = Sources.Source(abi.decode(wiringInfo, (uint256)));
            result[0] = config.get(source.toString()).toAddress();
        } else if (wiringType == SupportedWiring.PLAIN_NICKNAMED) {
            (Sources.Source source, ShortString nickname) = abi.decode(wiringInfo, (Sources.Source, ShortString));
            string memory sourceKey = string.concat(string.concat(source.toString(), "_"), nickname.toString());
            result[0] = config.get(sourceKey).toAddress();
        } else {
            revert UnsupportedWiringType();
        }
    }
}
