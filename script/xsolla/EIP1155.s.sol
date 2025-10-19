// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";

import { ERC1155Factory } from "src/xsolla/token/ERC1155/ERC1155Factory.sol";
import { ERC1155Modular } from "src/xsolla/token/ERC1155/extensions/ERC1155Modular.sol";
import { ERC1155Claimer } from "src/xsolla/token/ERC1155/ERC1155Claimer.sol";

import { DeployStage } from "xsolla/scripts/di/DeployStage.s.sol";

contract EIP1155 is DeployStage {
    error ERC1155ModularNotDeployed();

    ERC1155Factory public erc1155Factory;
    ERC1155Modular public modularERC1155;
    ERC1155Claimer public erc1155Claimer;

    function setUp() public { }

    function run() public {
        vm.startBroadcast();

        erc1155Factory = new ERC1155Factory();
        modularERC1155 = new ERC1155Modular();

        modularERC1155.setBaseURI("https://api.xsolla.com/metadata/");
        modularERC1155.toggleMinting();
        modularERC1155.toggleBurning();

        erc1155Claimer = new ERC1155Claimer(modularERC1155);
        erc1155Claimer.setAmountToClaim(100 ether);
        erc1155Claimer.setTokenIdToClaim(0);

        modularERC1155.grantRole(modularERC1155.MINTER_ROLE(), address(erc1155Claimer));

        vm.stopBroadcast();

        console.log("ERC1155Factory:", address(erc1155Factory));
        console.log("ERC1155Modular:", address(modularERC1155));
        console.log("ERC1155Claimer:", address(erc1155Claimer));
    }

    function deployWithCustomConfig(
        string memory baseURI,
        uint256 claimAmount,
        uint256 tokenIdToClaim,
        bool enableMinting,
        bool enableBurning
    ) external {
        vm.startBroadcast();

        erc1155Factory = new ERC1155Factory();
        modularERC1155 = new ERC1155Modular();

        modularERC1155.setBaseURI(baseURI);
        if (enableMinting) modularERC1155.toggleMinting();
        if (enableBurning) modularERC1155.toggleBurning();

        erc1155Claimer = new ERC1155Claimer(modularERC1155);
        erc1155Claimer.setAmountToClaim(claimAmount);
        erc1155Claimer.setTokenIdToClaim(tokenIdToClaim);

        modularERC1155.grantRole(modularERC1155.MINTER_ROLE(), address(erc1155Claimer));

        vm.stopBroadcast();
    }

    function deployBasicERC1155(string memory baseURI) external returns (ERC1155Modular) {
        vm.startBroadcast();

        modularERC1155 = new ERC1155Modular();
        modularERC1155.setBaseURI(baseURI);
        modularERC1155.toggleMinting();

        vm.stopBroadcast();
        return modularERC1155;
    }

    function deployERC1155WithClaimer(string memory baseURI, uint256 claimAmount, uint256 tokenIdToClaim)
        external
        returns (ERC1155Modular, ERC1155Claimer)
    {
        vm.startBroadcast();

        modularERC1155 = new ERC1155Modular();
        modularERC1155.setBaseURI(baseURI);
        modularERC1155.toggleMinting();

        erc1155Claimer = new ERC1155Claimer(modularERC1155);
        erc1155Claimer.setAmountToClaim(claimAmount);
        erc1155Claimer.setTokenIdToClaim(tokenIdToClaim);
        modularERC1155.grantRole(modularERC1155.MINTER_ROLE(), address(erc1155Claimer));

        vm.stopBroadcast();
        return (modularERC1155, erc1155Claimer);
    }

    function deployERC1155WithBurning(string memory baseURI) external returns (ERC1155Modular) {
        vm.startBroadcast();

        modularERC1155 = new ERC1155Modular();
        modularERC1155.setBaseURI(baseURI);
        modularERC1155.toggleMinting();
        modularERC1155.toggleBurning();

        vm.stopBroadcast();
        return modularERC1155;
    }

    function deployERC1155WithMultipleClaimers(
        string memory baseURI,
        uint256[] memory claimAmounts,
        uint256[] memory tokenIds
    ) external returns (ERC1155Modular, ERC1155Claimer[] memory) {
        require(claimAmounts.length == tokenIds.length, "Arrays length mismatch");

        vm.startBroadcast();

        modularERC1155 = new ERC1155Modular();
        modularERC1155.setBaseURI(baseURI);
        modularERC1155.toggleMinting();

        ERC1155Claimer[] memory claimers = new ERC1155Claimer[](claimAmounts.length);
        for (uint256 i = 0; i < claimAmounts.length; i++) {
            claimers[i] = new ERC1155Claimer(modularERC1155);
            claimers[i].setAmountToClaim(claimAmounts[i]);
            claimers[i].setTokenIdToClaim(tokenIds[i]);
            modularERC1155.grantRole(modularERC1155.MINTER_ROLE(), address(claimers[i]));
        }

        vm.stopBroadcast();
        return (modularERC1155, claimers);
    }

    function deployCompleteEcosystem(
        string memory baseURI,
        uint256 claimAmount,
        uint256 tokenIdToClaim,
        bool enableBurning
    ) external returns (ERC1155Factory, ERC1155Modular, ERC1155Claimer) {
        vm.startBroadcast();

        erc1155Factory = new ERC1155Factory();
        modularERC1155 = new ERC1155Modular();

        modularERC1155.setBaseURI(baseURI);
        modularERC1155.toggleMinting();
        if (enableBurning) modularERC1155.toggleBurning();

        erc1155Claimer = new ERC1155Claimer(modularERC1155);
        erc1155Claimer.setAmountToClaim(claimAmount);
        erc1155Claimer.setTokenIdToClaim(tokenIdToClaim);
        modularERC1155.grantRole(modularERC1155.MINTER_ROLE(), address(erc1155Claimer));

        vm.stopBroadcast();
        return (erc1155Factory, modularERC1155, erc1155Claimer);
    }

    function deployMinimalERC1155() external returns (ERC1155Modular) {
        vm.startBroadcast();
        modularERC1155 = new ERC1155Modular();
        vm.stopBroadcast();
        return modularERC1155;
    }

    function deployERC1155WithCustomMinter(string memory baseURI, address customMinter)
        external
        returns (ERC1155Modular)
    {
        vm.startBroadcast();

        modularERC1155 = new ERC1155Modular();
        modularERC1155.setBaseURI(baseURI);
        modularERC1155.grantRole(modularERC1155.MINTER_ROLE(), customMinter);
        modularERC1155.toggleMinting();

        vm.stopBroadcast();
        return modularERC1155;
    }

    function deployERC1155GameAssets(string memory baseURI, uint256[] memory tokenIds, uint256[] memory claimAmounts)
        external
        returns (ERC1155Modular, ERC1155Claimer[] memory)
    {
        require(tokenIds.length == claimAmounts.length, "Arrays length mismatch");

        vm.startBroadcast();

        modularERC1155 = new ERC1155Modular();
        modularERC1155.setBaseURI(baseURI);
        modularERC1155.toggleMinting();
        modularERC1155.toggleBurning();

        ERC1155Claimer[] memory claimers = new ERC1155Claimer[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            claimers[i] = new ERC1155Claimer(modularERC1155);
            claimers[i].setAmountToClaim(claimAmounts[i]);
            claimers[i].setTokenIdToClaim(tokenIds[i]);
            modularERC1155.grantRole(modularERC1155.MINTER_ROLE(), address(claimers[i]));
        }

        vm.stopBroadcast();
        return (modularERC1155, claimers);
    }
}
