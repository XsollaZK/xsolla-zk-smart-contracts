// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";

import { ERC20Factory } from "src/xsolla/token/ERC20/ERC20Factory.sol";
import { ERC20Modular } from "src/xsolla/token/ERC20/extensions/ERC20Modular.sol";
import { ERC20Claimer } from "src/xsolla/token/ERC20/ERC20Claimer.sol";

import { DeployStage } from "xsolla/scripts/di/DeployStage.s.sol";

contract EIP20 is DeployStage {
    error ERC20ModularNotDeployed();

    ERC20Factory public erc20Factory;
    ERC20Modular public modularERC20;
    ERC20Claimer public erc20Claimer;

    function setUp() public { }

    function run() public {
        vm.startBroadcast();
        erc20Factory = new ERC20Factory();
        modularERC20 = new ERC20Modular("Xsolla Token", "XSOLLA", msg.sender, msg.sender, msg.sender);
        erc20Claimer = new ERC20Claimer(modularERC20);
        erc20Claimer.setAmountToClaim(100 ether);
        modularERC20.grantRole(modularERC20.MINTER_ROLE(), address(erc20Claimer));
        vm.stopBroadcast();
        console.log("ERC20Factory:", address(erc20Factory));
        console.log("ERC20Modular:", address(modularERC20));
        console.log("ERC20Claimer:", address(erc20Claimer));
    }

    function deployUtilizingFactoryWithCustomConfig(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser,
        address minter,
        uint256 claimAmount
    ) external returns (ERC20Modular, ERC20Claimer) {
        vm.startBroadcast();

        erc20Factory = new ERC20Factory();
        modularERC20 = new ERC20Modular(name, symbol, defaultAdmin, pauser, minter);
        erc20Claimer = new ERC20Claimer(modularERC20);
        erc20Claimer.setAmountToClaim(claimAmount);
        modularERC20.grantRole(modularERC20.MINTER_ROLE(), address(erc20Claimer));

        vm.stopBroadcast();
        return (modularERC20, erc20Claimer);
    }

    function deployBasicERC20(string memory name, string memory symbol, address owner) external returns (ERC20Modular) {
        vm.startBroadcast();
        modularERC20 = new ERC20Modular(name, symbol, owner, owner, owner);
        vm.stopBroadcast();
        return modularERC20;
    }

    function deployERC20WithSeparateRoles(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser,
        address minter
    ) external returns (ERC20Modular) {
        vm.startBroadcast();
        modularERC20 = new ERC20Modular(name, symbol, defaultAdmin, pauser, minter);
        vm.stopBroadcast();
        return modularERC20;
    }

    function deployERC20WithClaimer(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser,
        address minter,
        uint256 claimAmount
    ) external returns (ERC20Modular, ERC20Claimer) {
        vm.startBroadcast();

        modularERC20 = new ERC20Modular(name, symbol, defaultAdmin, pauser, minter);
        erc20Claimer = new ERC20Claimer(modularERC20);
        erc20Claimer.setAmountToClaim(claimAmount);
        modularERC20.grantRole(modularERC20.MINTER_ROLE(), address(erc20Claimer));

        vm.stopBroadcast();
        return (modularERC20, erc20Claimer);
    }

    function deployERC20WithMultipleClaimers(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser,
        address minter,
        uint256[] memory claimAmounts
    ) external returns (ERC20Modular, ERC20Claimer[] memory) {
        vm.startBroadcast();

        modularERC20 = new ERC20Modular(name, symbol, defaultAdmin, pauser, minter);
        ERC20Claimer[] memory claimers = new ERC20Claimer[](claimAmounts.length);
        for (uint256 i = 0; i < claimAmounts.length; i++) {
            claimers[i] = new ERC20Claimer(modularERC20);
            claimers[i].setAmountToClaim(claimAmounts[i]);
            modularERC20.grantRole(modularERC20.MINTER_ROLE(), address(claimers[i]));
        }

        vm.stopBroadcast();
        return (modularERC20, claimers);
    }

    function deployCompleteEcosystem(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser,
        address minter,
        uint256 claimAmount
    ) external returns (ERC20Factory, ERC20Modular, ERC20Claimer) {
        vm.startBroadcast();

        erc20Factory = new ERC20Factory();
        modularERC20 = new ERC20Modular(name, symbol, defaultAdmin, pauser, minter);
        erc20Claimer = new ERC20Claimer(modularERC20);
        erc20Claimer.setAmountToClaim(claimAmount);
        modularERC20.grantRole(modularERC20.MINTER_ROLE(), address(erc20Claimer));
        vm.stopBroadcast();

        return (erc20Factory, modularERC20, erc20Claimer);
    }

    function deployMinimalERC20(string memory name, string memory symbol) external returns (ERC20Modular) {
        vm.startBroadcast();
        modularERC20 = new ERC20Modular(name, symbol, msg.sender, msg.sender, msg.sender);
        vm.stopBroadcast();
        return modularERC20;
    }

    function deployERC20WithCustomMinter(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser,
        address customMinter
    ) external returns (ERC20Modular) {
        vm.startBroadcast();

        modularERC20 = new ERC20Modular(name, symbol, defaultAdmin, pauser, defaultAdmin);
        modularERC20.grantRole(modularERC20.MINTER_ROLE(), customMinter);

        vm.stopBroadcast();
        return modularERC20;
    }
}
