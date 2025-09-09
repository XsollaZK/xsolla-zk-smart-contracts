// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";

import { DeployStage } from "./DeployStage.s.sol";
import { ERC721Factory } from "../src/product/token/ERC721/ERC721Factory.sol";
import { ERC721Modular } from "../src/product/token/ERC721/extensions/ERC721Modular.sol";
import { ERC721Claimer } from "../src/product/token/ERC721/ERC721Claimer.sol";
import { SVGIconsLib } from "../src/product/libraries/SVGIconsLib.sol";

contract EIP721 is DeployStage {
    ERC721Factory public erc721Factory;
    ERC721Modular public modularERC721;
    ERC721Claimer public erc721Claimer;

    // Customizable parameters
    struct ERC721Config {
        string name;
        string symbol;
        uint256 maxSupply;
        string ipfsDefaultImage;
        SVGIconsLib.Field[8] defaultFields;
        uint256 claimAmount;
        bool enableMinting;
        bool enableSvg;
        string baseURI;
    }

    ERC721Config public config;

    function _setupDefaultConfig() internal {
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

        config = ERC721Config({
            name: "Xsolla NFT Collection",
            symbol: "XSOLLA_NFT",
            maxSupply: 10000,
            ipfsDefaultImage: "bafkreie7ohywtosou76tasm7j63yigtzxe7d5zqus4zu3j6oltvgtibeom",
            defaultFields: defaultFields,
            claimAmount: 1,
            enableMinting: true,
            enableSvg: false,
            baseURI: ""
        });
    }

    function _setupCustomConfig(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _ipfsDefaultImage,
        SVGIconsLib.Field[8] memory _defaultFields,
        uint256 _claimAmount,
        bool _enableMinting,
        bool _enableSvg,
        string memory _baseURI
    ) internal {
        config = ERC721Config({
            name: _name,
            symbol: _symbol,
            maxSupply: _maxSupply,
            ipfsDefaultImage: _ipfsDefaultImage,
            defaultFields: _defaultFields,
            claimAmount: _claimAmount,
            enableMinting: _enableMinting,
            enableSvg: _enableSvg,
            baseURI: _baseURI
        });
    }

    function _deployERC721Factory() internal {
        vm.startBroadcast();
        
        erc721Factory = new ERC721Factory();
        
        vm.stopBroadcast();
        
        console.log("ERC721Factory deployed at:", address(erc721Factory));
    }
    
    function _deployModularERC721() internal {
        vm.startBroadcast();
        
        // Deploy ERC721 collection with customizable configuration
        modularERC721 = new ERC721Modular(
            config.name,              // name
            config.symbol,            // symbol
            config.maxSupply          // maxSupply
        );
        
        // Set up configuration
        modularERC721.setDefaultFields(config.defaultFields);
        modularERC721.setIpfsDefaultImage(config.ipfsDefaultImage);
        
        if (bytes(config.baseURI).length > 0) {
            modularERC721.setBaseUri(config.baseURI);
        }
        
        if (config.enableMinting) {
            modularERC721.toggleMinting(); // Enable minting
        }
        
        if (config.enableSvg) {
            modularERC721.toggleSvg(); // Enable SVG
        }
        
        vm.stopBroadcast();
        
        console.log("ERC721Modular deployed at:", address(modularERC721));
        console.log("Collection name:", modularERC721.name());
        console.log("Collection symbol:", modularERC721.symbol());
        console.log("Max supply:", modularERC721.maxSupply());
        console.log("Minting enabled:", modularERC721.mintingEnabled());
        console.log("SVG enabled:", modularERC721.utilizeSvg());
    }

    function _deployERC721Claimer() internal {
        // ERC721Claimer requires an existing ERC721Modular token
        require(address(modularERC721) != address(0), "ERC721Modular must be deployed first");
        
        vm.startBroadcast();
        
        erc721Claimer = new ERC721Claimer(modularERC721);
        
        // Set custom claim amount
        if (config.claimAmount != 1) { // Only set if different from default
            erc721Claimer.setAmountToClaim(config.claimAmount);
        }
        
        // Grant MINTER_ROLE to the claimer so it can mint tokens
        modularERC721.grantRole(modularERC721.MINTER_ROLE(), address(erc721Claimer));
        
        vm.stopBroadcast();
        
        console.log("ERC721Claimer deployed at:", address(erc721Claimer));
        console.log("Claim amount:", erc721Claimer.amountToClaim());
    }

    function _deployAll() internal {
        _deployERC721Factory();
        _deployModularERC721();
        _deployERC721Claimer();
        
        console.log("=== ERC721 Deployment Summary ===");
        console.log("ERC721Factory:     ", address(erc721Factory));
        console.log("ERC721Modular:     ", address(modularERC721));
        console.log("ERC721Claimer:     ", address(erc721Claimer));
        console.log("=== Configuration Used ===");
        console.log("Name:              ", config.name);
        console.log("Symbol:            ", config.symbol);
        console.log("Max Supply:        ", config.maxSupply);
        console.log("Claim Amount:      ", config.claimAmount);
        console.log("Minting Enabled:   ", config.enableMinting);
        console.log("SVG Enabled:       ", config.enableSvg);
        console.log("IPFS Image:        ", config.ipfsDefaultImage);
    }

    // Public functions for customization
    function deployWithDefaults() external {
        _setupDefaultConfig();
        _deployAll();
    }

    function deployWithCustomConfig(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _ipfsDefaultImage,
        SVGIconsLib.Field[8] memory _defaultFields,
        uint256 _claimAmount,
        bool _enableMinting,
        bool _enableSvg,
        string memory _baseURI
    ) external {
        _setupCustomConfig(_name, _symbol, _maxSupply, _ipfsDefaultImage, _defaultFields, _claimAmount, _enableMinting, _enableSvg, _baseURI);
        _deployAll();
    }

    // Convenience function for basic customization
    function deployWithBasicConfig(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _claimAmount
    ) external {
        _setupDefaultConfig();
        config.name = _name;
        config.symbol = _symbol;
        config.maxSupply = _maxSupply;
        config.claimAmount = _claimAmount;
        _deployAll();
    }

    function setUp() public {
        _setupDefaultConfig();
    }

    function run() public {
        _deployAll();
    }
}
