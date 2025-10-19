// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { Variable, TypeKind, LibVariable } from "forge-std/LibVariable.sol";
import { Config } from "forge-std/Config.sol";
import { console } from "forge-std/console.sol";

import { Sources } from "xsolla/scripts/di/libraries/Sources.s.sol";
import { IWiringMechanism } from "xsolla/scripts/di/interfaces/IWiringMechanism.s.sol";

abstract contract StdConfigBasedWiring is IWiringMechanism, Config {
    using Sources for Sources.Source;
    using ShortStrings for ShortString;
    using LibVariable for Variable;

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
            Sources.Source source = Sources.Source(abi.decode(
                wiringInfo,
                (uint256)
            ));
            result[0] = config.get(source.toString()).toAddress();
        } else if (wiringType == SupportedWiring.PLAIN_NICKNAMED) {
            (Sources.Source source, ShortString nickname) = abi.decode(
                wiringInfo,
                (Sources.Source, ShortString)
            );
            string memory sourceKey = string.concat(string.concat(source.toString(), "_"), nickname.toString());
            result[0] = config.get(sourceKey).toAddress();
        } else {
            revert UnsupportedWiringType();
        }
    }
}
