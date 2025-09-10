// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";

import { DeployStage } from "./DeployStage.s.sol";
import { AddressesReportConfig } from "../src/product/AddressesReportConfig.sol";

contract Reports is DeployStage {
    error AddressesReportConfigNotDeployed();
    
    AddressesReportConfig public addressesReportConfig;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        addressesReportConfig = new AddressesReportConfig();
        vm.stopBroadcast();
        
        console.log("AddressesReportConfig:", address(addressesReportConfig));
    }

    function deployWithBasicConfig(address admin, address maintainer) external {
        vm.startBroadcast();
        addressesReportConfig = new AddressesReportConfig();
        
        if (admin != msg.sender) {
            addressesReportConfig.grantRole(addressesReportConfig.DEFAULT_ADMIN_ROLE(), admin);
            addressesReportConfig.revokeRole(addressesReportConfig.DEFAULT_ADMIN_ROLE(), msg.sender);
        }
        
        if (maintainer != msg.sender && maintainer != admin) {
            addressesReportConfig.grantRole(addressesReportConfig.MAINTAINER_ROLE(), maintainer);
        }
        
        vm.stopBroadcast();
        console.log("AddressesReportConfig:", address(addressesReportConfig));
    }
    
    function addContract(uint256 networkId, string memory name, string memory artifact, address addr) external {
        if (address(addressesReportConfig) == address(0)) {
            revert AddressesReportConfigNotDeployed();
        }
        vm.startBroadcast();
        addressesReportConfig.insertContractReport(networkId, 0, name, artifact, addr);
        vm.stopBroadcast();
    }
}