// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";

import { DeployStage } from "./DeployStage.s.sol";
import { ERC1155Factory } from "../src/product/token/ERC1155/ERC1155Factory.sol";
import { ERC1155Modular } from "../src/product/token/ERC1155/extensions/ERC1155Modular.sol";
import { ERC1155Claimer } from "../src/product/token/ERC1155/ERC1155Claimer.sol";

contract EIP1155 is DeployStage {
    error ERC1155ModularNotDeployed();
    
    ERC1155Factory public erc1155Factory;
    ERC1155Modular public modularERC1155;
    ERC1155Claimer public erc1155Claimer;

    function setUp() public {}

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
}
