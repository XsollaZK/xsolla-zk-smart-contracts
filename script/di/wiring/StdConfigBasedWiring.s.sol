// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";

import { Variable, TypeKind, LibVariable } from "forge-std/LibVariable.sol";
import { Config } from "forge-std/Config.sol";
import { StdConfig } from "forge-std/StdConfig.sol";
import { console } from "forge-std/console.sol";

import { Sources } from "xsolla/scripts/di/libraries/Sources.s.sol";
import { IWiringMechanism } from "xsolla/scripts/di/interfaces/IWiringMechanism.s.sol";
import { IConfiguration } from "xsolla/scripts/di/interfaces/IConfiguration.s.sol";
import { Eip4337Configuration } from "xsolla/scripts/di/configurations/Eip4337Configuration.s.sol";
import { TUPConfiguration } from "xsolla/scripts/di/configurations/TUPConfiguration.s.sol";

contract StdConfigBasedWiring is IWiringMechanism, Config {
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

    function getConfig() external view returns (StdConfig) {
        return config;
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
            Sources.Source source = abi.decode(wiringInfo, (Sources.Source));
            address wiredAddress = Create2.deploy(0, source.toSalt(), source.toCreationCode());
            config.set(source.toString(), wiredAddress);
            return wiredAddress;
        } else if (wiringType == SupportedWiring.PLAIN_NICKNAMED) {
            (Sources.Source source, ShortString nickname) = abi.decode(wiringInfo, (Sources.Source, ShortString));
            address wiredAddress = Create2.deploy(0, source.toSalt(nickname), source.toCreationCode());
            config.set(source.getFullNicknamedName(nickname), wiredAddress);
            return wiredAddress;
        } else if (wiringType == SupportedWiring.CONFIGURATION_BASED) {
            // If payload contains at least a bytes32 flag and a dynamic bytes header, treat as flagged std
            // configuration
            if (wiringInfo.length >= 64) {
                (bytes32 stdConfigurationFlag, bytes memory deployerAndRestOfInfo) =
                    abi.decode(wiringInfo, (bytes32, bytes));
                if (stdConfigurationFlag == Sources.NICKNAMED_PROXY_FLAG) {
                    (address deployerAddress, bytes memory restOfInfo) =
                        abi.decode(deployerAndRestOfInfo, (address, bytes));
                    if (deployerAddress == address(0)) {
                        revert UnsupportedWiringType();
                    }
                    Sources.Source source = abi.decode(restOfInfo, (Sources.Source));
                    // Ensure implementation deployment is broadcasted, so the proxy constructor sees code at _logic
                    vm.broadcast();
                    address implAddress = Create2.deploy(0, source.toSalt(), source.toCreationCode());
                    // Save the implementation under the plain source key for consumers expecting the module logic
                    // address
                    config.set(source.toString(), implAddress);
                    TUPConfiguration tupConfig = new TUPConfiguration(vm, config, deployerAddress, implAddress, source);
                    tupConfig.startAutowiringSources();
                    return config.get(tupConfig.getProxySourceKey()).toAddress();
                } else if (stdConfigurationFlag == Sources.EIP4337_FLAG) {
                    (address ownerAddress, bytes memory restOfInfo) =
                        abi.decode(deployerAndRestOfInfo, (address, bytes));
                    if (ownerAddress == address(0)) {
                        revert UnsupportedWiringType();
                    }
                    ShortString nickname = ShortStrings.toShortString(abi.decode(restOfInfo, (string)));
                    Eip4337Configuration eip4337Config = new Eip4337Configuration(vm, config, ownerAddress, nickname);
                    eip4337Config.startAutowiringSources();
                    return config.get(eip4337Config.getAccountSourceKey()).toAddress();
                } else {
                    revert UnsupportedWiringType();
                }
            } else {
                // Support both ABI-encoded (32 bytes) and packed (20 bytes) address encodings
                address configuration;
                if (wiringInfo.length == 32) {
                    (configuration) = abi.decode(wiringInfo, (address));
                } else if (wiringInfo.length == 20) {
                    configuration = address(bytes20(wiringInfo));
                } else {
                    revert UnsupportedWiringType();
                }
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
            Sources.Source source = abi.decode(wiringInfo, (Sources.Source));
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
