// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { MSAFactory } from "src/MSAFactory.sol";
import { ModularSmartAccount } from "src/ModularSmartAccount.sol";
import { AddressesReportConfig } from "src/product/AddressesReportConfig.sol";

abstract contract DeployStage is Script {
    bytes32 public constant UNIFIED_ADDRESSES_REPORT_CONFIG = keccak256("unified-addresses-report-config");
    bytes32 public constant DEFAULT_ACCOUNT_ID = keccak256("my-account-id");

    function _makeTUP(address impl) internal virtual returns (address) {
        return address(new TransparentUpgradeableProxy(impl, msg.sender, ""));
    }

    /// @dev This function is used for tests only
    function _deployAccount(address factory, address[] memory modules, bytes32 accountId) internal virtual {
        bytes[] memory initData = new bytes[](4);
        address[] memory accountOwners = new address[](1);
        accountOwners[0] = msg.sender;
        initData[0] = abi.encode(accountOwners);
        bytes memory data = abi.encodeCall(ModularSmartAccount.initializeAccount, (modules, initData));

        vm.startBroadcast();

        address account = MSAFactory(factory).deployAccount(accountId, data);
        payable(account).transfer(1 ether);

        vm.stopBroadcast();

        console.log("Initialized account:", account);
    }

    function _getOrDeployReportConfig() internal virtual returns (AddressesReportConfig) {
        address addressesReportConfig = Create2.computeAddress(UNIFIED_ADDRESSES_REPORT_CONFIG, keccak256(type(AddressesReportConfig).creationCode));
        if (addressesReportConfig.code.length == 0) {
            vm.startBroadcast();
            addressesReportConfig = Create2.deploy(0, UNIFIED_ADDRESSES_REPORT_CONFIG, type(AddressesReportConfig).creationCode);
            vm.stopBroadcast();
            console.log("Deployed AddressesReportConfig:", addressesReportConfig);
        } else {
            console.log("Using existing AddressesReportConfig:", addressesReportConfig);
        }
    }

    function _addContractIntoAddressesReportConfig(uint256 networkId, string memory name, string memory artifact, address addr) internal virtual {
        AddressesReportConfig addressesReportConfig = _getOrDeployReportConfig();
        vm.startBroadcast();
        addressesReportConfig.insertContractReport(networkId, 0, name, artifact, addr);
        vm.stopBroadcast();
    }
}
