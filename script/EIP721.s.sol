// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";

import { DeployStage } from "./DeployStage.s.sol";
import { ERC721Factory } from "../src/product/token/ERC721/ERC721Factory.sol";
import { ERC721Modular } from "../src/product/token/ERC721/extensions/ERC721Modular.sol";
import { ERC721Claimer } from "../src/product/token/ERC721/ERC721Claimer.sol";
import { SVGIconsLib } from "../src/product/libraries/SVGIconsLib.sol";

contract EIP721 is DeployStage {
    error ERC721ModularNotDeployed();
    
    ERC721Factory public erc721Factory;
    ERC721Modular public modularERC721;
    ERC721Claimer public erc721Claimer;

    function setUp() public {}

    function run() public {
        SVGIconsLib.Field[8] memory defaultFields = [
            SVGIconsLib.Field('Name: ', 'Xsolla NFT', 'none'),
            SVGIconsLib.Field('Description: ', 'Xsolla ZK NFT Collection', 'none'),
            SVGIconsLib.Field('Creator: ', 'Xsolla Web3', 'none'),
            SVGIconsLib.Field('Network: ', 'ZK Chain', 'none'),
            SVGIconsLib.Field('', '', 'none'),
            SVGIconsLib.Field('', '', 'none'),
            SVGIconsLib.Field('', '', 'none'),
            SVGIconsLib.Field('', '', 'none')
        ];

        vm.startBroadcast();
        
        erc721Factory = new ERC721Factory();
        modularERC721 = new ERC721Modular("Xsolla NFT Collection", "XSOLLA_NFT", 10000);
        
        modularERC721.setDefaultFields(defaultFields);
        modularERC721.setIpfsDefaultImage("bafkreie7ohywtosou76tasm7j63yigtzxe7d5zqus4zu3j6oltvgtibeom");
        modularERC721.toggleMinting();
        
        erc721Claimer = new ERC721Claimer(modularERC721);
        modularERC721.grantRole(modularERC721.MINTER_ROLE(), address(erc721Claimer));
        
        vm.stopBroadcast();
        
        console.log("ERC721Factory:", address(erc721Factory));
        console.log("ERC721Modular:", address(modularERC721));
        console.log("ERC721Claimer:", address(erc721Claimer));
    }

    function deployWithCustomConfig(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        string memory ipfsDefaultImage,
        SVGIconsLib.Field[8] memory defaultFields,
        uint256 claimAmount,
        bool enableMinting,
        bool enableSvg,
        string memory baseURI
    ) external {
        vm.startBroadcast();
        
        erc721Factory = new ERC721Factory();
        modularERC721 = new ERC721Modular(name, symbol, maxSupply);
        
        modularERC721.setDefaultFields(defaultFields);
        modularERC721.setIpfsDefaultImage(ipfsDefaultImage);
        
        if (bytes(baseURI).length > 0) {
            modularERC721.setBaseUri(baseURI);
        }
        
        if (enableMinting) modularERC721.toggleMinting();
        if (enableSvg) modularERC721.toggleSvg();
        
        erc721Claimer = new ERC721Claimer(modularERC721);
        if (claimAmount != 1) {
            erc721Claimer.setAmountToClaim(claimAmount);
        }
        modularERC721.grantRole(modularERC721.MINTER_ROLE(), address(erc721Claimer));
        
        vm.stopBroadcast();
    }

    function deployBasicERC721(
        string memory name,
        string memory symbol,
        uint256 maxSupply
    ) external returns (ERC721Modular) {
        vm.startBroadcast();
        
        modularERC721 = new ERC721Modular(name, symbol, maxSupply);
        modularERC721.toggleMinting();
        
        vm.stopBroadcast();
        return modularERC721;
    }

    function deployERC721WithClaimer(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        uint256 claimAmount
    ) external returns (ERC721Modular, ERC721Claimer) {
        vm.startBroadcast();
        
        modularERC721 = new ERC721Modular(name, symbol, maxSupply);
        modularERC721.toggleMinting();
        
        erc721Claimer = new ERC721Claimer(modularERC721);
        erc721Claimer.setAmountToClaim(claimAmount);
        modularERC721.grantRole(modularERC721.MINTER_ROLE(), address(erc721Claimer));
        
        vm.stopBroadcast();
        return (modularERC721, erc721Claimer);
    }

    function deployERC721WithSVG(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        SVGIconsLib.Field[8] memory fields
    ) external returns (ERC721Modular) {
        vm.startBroadcast();
        
        modularERC721 = new ERC721Modular(name, symbol, maxSupply);
        modularERC721.setDefaultFields(fields);
        modularERC721.toggleMinting();
        modularERC721.toggleSvg();
        
        vm.stopBroadcast();
        return modularERC721;
    }

    function deployERC721WithIPFS(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        string memory ipfsHash,
        string memory baseURI
    ) external returns (ERC721Modular) {
        vm.startBroadcast();
        
        modularERC721 = new ERC721Modular(name, symbol, maxSupply);
        modularERC721.setIpfsDefaultImage(ipfsHash);
        if (bytes(baseURI).length > 0) {
            modularERC721.setBaseUri(baseURI);
        }
        modularERC721.toggleMinting();
        
        vm.stopBroadcast();
        return modularERC721;
    }

    function deployERC721WithMultipleClaimers(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        uint256[] memory claimAmounts
    ) external returns (ERC721Modular, ERC721Claimer[] memory) {
        vm.startBroadcast();
        
        modularERC721 = new ERC721Modular(name, symbol, maxSupply);
        modularERC721.toggleMinting();
        
        ERC721Claimer[] memory claimers = new ERC721Claimer[](claimAmounts.length);
        for (uint i = 0; i < claimAmounts.length; i++) {
            claimers[i] = new ERC721Claimer(modularERC721);
            claimers[i].setAmountToClaim(claimAmounts[i]);
            modularERC721.grantRole(modularERC721.MINTER_ROLE(), address(claimers[i]));
        }
        
        vm.stopBroadcast();
        return (modularERC721, claimers);
    }

    function deployCompleteEcosystem(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        string memory ipfsDefaultImage,
        SVGIconsLib.Field[8] memory defaultFields,
        uint256 claimAmount,
        string memory baseURI
    ) external returns (ERC721Factory, ERC721Modular, ERC721Claimer) {
        vm.startBroadcast();
        
        erc721Factory = new ERC721Factory();
        modularERC721 = new ERC721Modular(name, symbol, maxSupply);
        
        modularERC721.setDefaultFields(defaultFields);
        modularERC721.setIpfsDefaultImage(ipfsDefaultImage);
        if (bytes(baseURI).length > 0) {
            modularERC721.setBaseUri(baseURI);
        }
        modularERC721.toggleMinting();
        
        erc721Claimer = new ERC721Claimer(modularERC721);
        erc721Claimer.setAmountToClaim(claimAmount);
        modularERC721.grantRole(modularERC721.MINTER_ROLE(), address(erc721Claimer));
        
        vm.stopBroadcast();
        return (erc721Factory, modularERC721, erc721Claimer);
    }

    function deployMinimalERC721(
        string memory name,
        string memory symbol,
        uint256 maxSupply
    ) external returns (ERC721Modular) {
        vm.startBroadcast();
        
        modularERC721 = new ERC721Modular(name, symbol, maxSupply);
        
        vm.stopBroadcast();
        return modularERC721;
    }

    function deployERC721WithCustomMinter(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        address customMinter
    ) external returns (ERC721Modular) {
        vm.startBroadcast();
        
        modularERC721 = new ERC721Modular(name, symbol, maxSupply);
        modularERC721.grantRole(modularERC721.MINTER_ROLE(), customMinter);
        modularERC721.toggleMinting();
        
        vm.stopBroadcast();
        return modularERC721;
    }
}