// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { MSAFactory } from "src/MSAFactory.sol";
import { EOAKeyValidator } from "src/modules/EOAKeyValidator.sol";
import { SessionKeyValidator } from "src/modules/SessionKeyValidator.sol";
import { WebAuthnValidator } from "src/modules/WebAuthnValidator.sol";
import { GuardianExecutor } from "src/modules/GuardianExecutor.sol";
import { ModularSmartAccount } from "src/ModularSmartAccount.sol";

abstract contract DeployStage is Script {
    function _makeTUP(address impl) internal virtual returns (address) {
        return address(new TransparentUpgradeableProxy(impl, msg.sender, ""));
    }

    /// @dev This function is used for tests only
    function _deployAccount(address factory, address[] memory modules) internal virtual {
        bytes[] memory initData = new bytes[](4);
        address[] memory accountOwners = new address[](1);
        accountOwners[0] = msg.sender;
        initData[0] = abi.encode(accountOwners);
        bytes memory data = abi.encodeCall(ModularSmartAccount.initializeAccount, (modules, initData));

        vm.startBroadcast();

        address account = MSAFactory(factory).deployAccount(keccak256("my-account-id"), data);
        payable(account).transfer(1 ether);

        vm.stopBroadcast();

        console.log("Initialized account:", account);
    }
}
