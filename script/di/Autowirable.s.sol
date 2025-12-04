// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { Sources } from "script/di/libraries/Sources.s.sol";
import { IWiringMechanism } from "script/di/interfaces/IWiringMechanism.s.sol";
import { IConfiguration } from "script/di/interfaces/IConfiguration.s.sol";
import { StdConfigBasedWiring } from "script/di/wiring/StdConfigBasedWiring.s.sol";

abstract contract Autowirable is Script {
    using ShortStrings for ShortString;
    using Sources for Sources.Source;

    IWiringMechanism internal wiringMechanism;

    error SourceHasNotBeenAutowired(Sources.Source source);

    constructor() {
        wiringMechanism = IWiringMechanism(address(new StdConfigBasedWiring()));
    }

    modifier configwire(IConfiguration configContract) {
        // Using abi.encode(address) here; StdConfigBasedWiring supports both 20-byte packed and 32-byte ABI-encoded
        // addresses.
        wiringMechanism.wire(abi.encode(address(configContract)), IWiringMechanism.SupportedWiring.CONFIGURATION_BASED);
        console.log(
            "Configuration (", configContract.name(), ") utilized:", Strings.toHexString(address(configContract))
        );
        _;
    }

    modifier autowire(Sources.Source source) {
        address injectedAddress =
            wiringMechanism.wire(abi.encode(uint256(source)), IWiringMechanism.SupportedWiring.PLAIN);
        console.log(
            string(abi.encodePacked("Autowired ", source.toString(), " to ", Strings.toHexString(injectedAddress)))
        );
        _;
    }

    modifier proxywire(Sources.Source source) {
        // Proper ABI encoding to match decoder: (bytes32 flag, bytes (address deployer, bytes (source)))
        address injectedAddress = wiringMechanism.wire(
            abi.encode(Sources.NICKNAMED_PROXY_FLAG, abi.encode(msg.sender, abi.encode(source))),
            IWiringMechanism.SupportedWiring.CONFIGURATION_BASED
        );
        console.log(
            string(
                abi.encodePacked(
                    "Autowired (as TransparentUpgradeableProxy) ",
                    source.toString(),
                    " to ",
                    Strings.toHexString(injectedAddress)
                )
            )
        );
        _;
    }

    modifier accountwire(string memory nickname) {
        // Proper ABI encoding to match decoder: (bytes32 flag, bytes (address owner, bytes (string nickname)))
        address injectedAddress = wiringMechanism.wire(
            abi.encode(Sources.EIP4337_FLAG, abi.encode(msg.sender, abi.encode(nickname))),
            IWiringMechanism.SupportedWiring.CONFIGURATION_BASED
        );
        console.log(
            string(
                abi.encodePacked(
                    "Autowired new smart account: ", Strings.toHexString(injectedAddress), " under nickname ", nickname
                )
            )
        );
        _;
    }

    modifier nickwire(Sources.Source source, ShortString nickname) {
        address injectedAddress = wiringMechanism.wire(
            abi.encode(uint256(source), nickname), IWiringMechanism.SupportedWiring.PLAIN_NICKNAMED
        );
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
        console.log("Autowired lookup for source:", source.toString());
        address[] memory sortedInjectedAddresses =
            wiringMechanism.getWiredVariants(abi.encodePacked(uint256(source)), IWiringMechanism.SupportedWiring.PLAIN);
        if (sortedInjectedAddresses.length == 0 || sortedInjectedAddresses[0] == address(0)) {
            revert SourceHasNotBeenAutowired(source);
        }
        return sortedInjectedAddresses[0];
    }

    function autowired(Sources.Source source, string memory nickname) public view virtual returns (address) {
        console.log("Autowired lookup for source:", source.toString(), "and nickname:", nickname);
        address[] memory sortedInjectedAddresses = wiringMechanism.getWiredVariants(
            abi.encodePacked(uint256(source), ShortStrings.toShortString(nickname)),
            IWiringMechanism.SupportedWiring.PLAIN_NICKNAMED
        );
        if (sortedInjectedAddresses.length == 0 || sortedInjectedAddresses[0] == address(0)) {
            revert SourceHasNotBeenAutowired(source);
        }
        return sortedInjectedAddresses[0];
    }
}
