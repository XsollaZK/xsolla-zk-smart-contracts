// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { Sources } from "xsolla/scripts/di/libraries/Sources.s.sol";
import { IWiringMechanism } from "xsolla/scripts/di/interfaces/IWiringMechanism.s.sol";
import { IConfiguration } from "xsolla/scripts/di/interfaces/IConfiguration.s.sol";
import { StdConfigBasedWiring } from "xsolla/scripts/di/wiring/StdConfigBasedWiring.s.sol";
import { StdConfigBasedTUPConfiguration } from "xsolla/scripts/di/StdConfigBasedTUPConfiguration.s.sol";

abstract contract Autowirable is Script {
    using ShortStrings for ShortString;
    using Sources for Sources.Source;

    IWiringMechanism public wiringMechanism;

    error SourceHasNotBeenAutowired(Sources.Source source);

    modifier configuration(IConfiguration configContract) {
        wiringMechanism.wire(
            abi.encodePacked(address(configContract)), IWiringMechanism.SupportedWiring.CONFIGURATION_BASED
        );
        console.log(
            "Configuration (", configContract.name(), ") utilized:", Strings.toHexString(address(configContract))
        );
        _;
    }

    modifier autowire(Sources.Source source) {
        address injectedAddress = wiringMechanism.wire(abi.encodePacked(source), IWiringMechanism.SupportedWiring.PLAIN);
        console.log(
            string(abi.encodePacked("Autowired ", source.toString(), " to ", Strings.toHexString(injectedAddress)))
        );
        _;
    }

    modifier proxywire(Sources.Source source) {
        address injectedAddress = wiringMechanism.wire(
            abi.encodePacked(Sources.NICKNAMED_PROXY_FLAG, msg.sender, source),
            IWiringMechanism.SupportedWiring.CONFIGURATION_BASED
        );
        console.log(
            string(
                abi.encodePacked(
                    "Autowired (as proxy) ", source.toString(), " to ", Strings.toHexString(injectedAddress)
                )
            )
        );
        _;
    }

    modifier nickwire(Sources.Source source, ShortString nickname) {
        address injectedAddress =
            wiringMechanism.wire(abi.encodePacked(source, nickname), IWiringMechanism.SupportedWiring.PLAIN_NICKNAMED);
        console.log(
            string(
                abi.encodePacked(
                    "Autowired (with nickname ",
                    nickname.toString(),
                    ")",
                    source.toString(),
                    " to ",
                    Strings.toHexString(injectedAddress)
                )
            )
        );
        _;
    }

    function setWiringMechanism(IWiringMechanism mechanism) public {
        wiringMechanism = mechanism;
    }

    function autowired(Sources.Source source) public view virtual returns (address) {
        address[] memory sortedInjectedAddresses =
            wiringMechanism.getWiredVariants(abi.encodePacked(source), IWiringMechanism.SupportedWiring.PLAIN);
        if (sortedInjectedAddresses.length == 0 || sortedInjectedAddresses[0] == address(0)) {
            revert SourceHasNotBeenAutowired(source);
        }
        return sortedInjectedAddresses[0];
    }

    function autowired(Sources.Source source, ShortString nickname) public view virtual returns (address) {
        address[] memory sortedInjectedAddresses = wiringMechanism.getWiredVariants(
            abi.encodePacked(source, nickname), IWiringMechanism.SupportedWiring.PLAIN_NICKNAMED
        );
        if (sortedInjectedAddresses.length == 0 || sortedInjectedAddresses[0] == address(0)) {
            revert SourceHasNotBeenAutowired(source);
        }
        return sortedInjectedAddresses[0];
    }
}
