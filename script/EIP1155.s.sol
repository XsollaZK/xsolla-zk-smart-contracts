// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";

import { DeployStage } from "./DeployStage.s.sol";
import { ERC1155Factory } from "../src/product/token/ERC1155/ERC1155Factory.sol";
import { ERC1155Modular } from "../src/product/token/ERC1155/extensions/ERC1155Modular.sol";
import { ERC1155Claimer } from "../src/product/token/ERC1155/ERC1155Claimer.sol";

contract EIP1155 is DeployStage {
    ERC1155Factory public erc1155Factory;
    ERC1155Modular public modularERC1155;
    ERC1155Claimer public erc1155Claimer;

    // Customizable parameters
    struct ERC1155Config {
        string baseURI;
        uint256 claimAmount;
        uint256 tokenIdToClaim;
        bool enableMinting;
        bool enableBurning;
    }

    ERC1155Config public config;

    function _setupDefaultConfig() internal {
        config = ERC1155Config({
            baseURI: "https://api.xsolla.com/metadata/",
            claimAmount: 100 ether,
            tokenIdToClaim: 0,
            enableMinting: true,
            enableBurning: true
        });
    }

    function _setupCustomConfig(
        string memory _baseURI,
        uint256 _claimAmount,
        uint256 _tokenIdToClaim,
        bool _enableMinting,
        bool _enableBurning
    ) internal {
        config = ERC1155Config({
            baseURI: _baseURI,
            claimAmount: _claimAmount,
            tokenIdToClaim: _tokenIdToClaim,
            enableMinting: _enableMinting,
            enableBurning: _enableBurning
        });
    }

    function _deployERC1155Factory() internal {
        vm.startBroadcast();
        
        erc1155Factory = new ERC1155Factory();
        
        vm.stopBroadcast();
        
        console.log("ERC1155Factory deployed at:", address(erc1155Factory));
    }
    
    function _deployModularERC1155() internal {
        vm.startBroadcast();
        
        // Deploy ERC1155 collection with customizable configuration
        modularERC1155 = new ERC1155Modular();
        
        // Set up configuration
        modularERC1155.setBaseURI(config.baseURI);
        
        if (config.enableMinting) {
            modularERC1155.toggleMinting(); // Enable minting
        }
        
        if (config.enableBurning) {
            modularERC1155.toggleBurning(); // Enable burning
        }
        
        vm.stopBroadcast();
        
        console.log("ERC1155Modular deployed at:", address(modularERC1155));
        console.log("Base URI:", config.baseURI);
        console.log("Minting enabled:", modularERC1155.mintingEnabled());
        console.log("Burning enabled:", modularERC1155.burningEnabled());
    }

    function _deployERC1155Claimer() internal {
        // ERC1155Claimer requires an existing ERC1155Modular token
        require(address(modularERC1155) != address(0), "ERC1155Modular must be deployed first");
        
        vm.startBroadcast();
        
        erc1155Claimer = new ERC1155Claimer(modularERC1155);
        
        // Set custom claim configuration
        erc1155Claimer.setAmountToClaim(config.claimAmount);
        erc1155Claimer.setTokenIdToClaim(config.tokenIdToClaim);
        
        // Grant MINTER_ROLE to the claimer so it can mint tokens
        modularERC1155.grantRole(modularERC1155.MINTER_ROLE(), address(erc1155Claimer));
        
        vm.stopBroadcast();
        
        console.log("ERC1155Claimer deployed at:", address(erc1155Claimer));
        console.log("Claim amount:", erc1155Claimer.amountToClaim());
        console.log("Token ID to claim:", erc1155Claimer.tokenIdToClaim());
    }

    function _deployAll() internal {
        _deployERC1155Factory();
        _deployModularERC1155();
        _deployERC1155Claimer();
        
        console.log("=== ERC1155 Deployment Summary ===");
        console.log("ERC1155Factory:     ", address(erc1155Factory));
        console.log("ERC1155Modular:     ", address(modularERC1155));
        console.log("ERC1155Claimer:     ", address(erc1155Claimer));
        console.log("=== Configuration Used ===");
        console.log("Base URI:          ", config.baseURI);
        console.log("Claim Amount:      ", config.claimAmount);
        console.log("Token ID to Claim: ", config.tokenIdToClaim);
        console.log("Minting Enabled:   ", config.enableMinting);
        console.log("Burning Enabled:   ", config.enableBurning);
    }

    // Public functions for customization
    function deployWithDefaults() external {
        _setupDefaultConfig();
        _deployAll();
    }

    function deployWithCustomConfig(
        string memory _baseURI,
        uint256 _claimAmount,
        uint256 _tokenIdToClaim,
        bool _enableMinting,
        bool _enableBurning
    ) external {
        _setupCustomConfig(_baseURI, _claimAmount, _tokenIdToClaim, _enableMinting, _enableBurning);
        _deployAll();
    }

    // Convenience function for basic customization
    function deployWithBasicConfig(
        string memory _baseURI,
        uint256 _claimAmount,
        uint256 _tokenIdToClaim
    ) external {
        _setupDefaultConfig();
        config.baseURI = _baseURI;
        config.claimAmount = _claimAmount;
        config.tokenIdToClaim = _tokenIdToClaim;
        _deployAll();
    }

    function setUp() public {
        _setupDefaultConfig();
    }

    function run() public {
        _deployAll();
    }
}
