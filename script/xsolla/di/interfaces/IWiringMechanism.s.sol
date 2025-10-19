// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";

import { Sources } from "xsolla/scripts/di/libraries/Sources.s.sol";

interface IWiringMechanism {
    enum SupportedWiring {
        PLAIN_NICKNAMED,
        PLAIN,
        CONFIGURATION_BASED   
    }
    function wire(bytes memory wiringInfo, SupportedWiring wiringType) external returns (address);
    function getWiredVariants(bytes memory wiringInfo, SupportedWiring wiringType) external view returns (address[] memory);

}
