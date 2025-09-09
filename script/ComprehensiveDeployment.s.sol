// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { EIP20 } from "./EIP20.s.sol";
import { EIP721 } from "./EIP721.s.sol";
import { EIP1155 } from "./EIP1155.s.sol";
import { Reports } from "./Reports.s.sol";
import { NativeCurrency } from "./NativeCurrency.s.sol";
import { SeaportFeesCollectors } from "./SeaportFeesCollectors.s.sol";
import { SVGIconsLib } from "../src/product/libraries/SVGIconsLib.sol";

/// @title ComprehensiveDeployment
/// @notice Example script demonstrating how to deploy all token types and reports together
contract ComprehensiveDeployment is Script {
    
    // Deployment contracts
    EIP20 public erc20Deployer;
    EIP721 public erc721Deployer;
    EIP1155 public erc1155Deployer;
    Reports public reportsDeployer;
    NativeCurrency public nativeCurrencyDeployer;
    SeaportFeesCollectors public feeCollectorsDeployer;
    
    // Configuration
    address public constant ADMIN = 0x1234567890123456789012345678901234567890;
    address public constant MAINTAINER = 0x2345678901234567890123456789012345678901;
    
    function run() external {
        console.log("=== Starting Comprehensive Deployment ===");
        
        // Deploy Reports system first
        deployReports();
        
        // Deploy native currency infrastructure
        deployNativeCurrency();
        
        // Deploy fee collectors for marketplace operations
        deployFeeCollectors();
        
        // Deploy all token types
        deployERC20Tokens();
        deployERC721Collections();
        deployERC1155Collections();
        
        // Register all deployed contracts in reports
        registerDeployments();
        
        console.log("=== Comprehensive Deployment Complete ===");
    }
    
    function deployReports() internal {
        console.log("Deploying AddressesReportConfig...");
        
        reportsDeployer = new Reports();
        reportsDeployer.deployWithBasicConfig(ADMIN, MAINTAINER);
    }
    
    function deployNativeCurrency() internal {
        console.log("Deploying Native Currency ecosystem...");
        
        nativeCurrencyDeployer = new NativeCurrency();
        nativeCurrencyDeployer.deployWithDefaults();
    }
    
    function deployFeeCollectors() internal {
        console.log("Deploying Seaport Fee Collectors...");
        
        feeCollectorsDeployer = new SeaportFeesCollectors();
        feeCollectorsDeployer.deployWithDefaults();
    }
    
    function deployERC20Tokens() internal {
        console.log("Deploying ERC20 ecosystem...");
        
        erc20Deployer = new EIP20();
        erc20Deployer.deployWithCustomConfig(
            "Xsolla Game Token",      // name
            "XGT",                    // symbol
            ADMIN,                    // defaultAdmin
            ADMIN,                    // pauser
            ADMIN,                    // minter
            1000 ether                // claimAmount
        );
    }
    
    function deployERC721Collections() internal {
        console.log("Deploying ERC721 ecosystem...");
        
        // Create custom SVG fields for gaming NFTs
        SVGIconsLib.Field[8] memory gameFields = [
            SVGIconsLib.Field('Game: ', 'Xsolla Adventure', 'none'),
            SVGIconsLib.Field('Rarity: ', 'Epic', 'none'),
            SVGIconsLib.Field('Level: ', '100', 'number'),
            SVGIconsLib.Field('Power: ', '9001', 'number'),
            SVGIconsLib.Field('Element: ', 'Fire', 'none'),
            SVGIconsLib.Field('Class: ', 'Warrior', 'none'),
            SVGIconsLib.Field('', '', 'none'),
            SVGIconsLib.Field('', '', 'none')
        ];
        
        erc721Deployer = new EIP721();
        erc721Deployer.deployWithCustomConfig(
            "Xsolla Game Heroes",                                 // name
            "XGH",                                               // symbol
            50000,                                               // maxSupply
            "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi", // ipfsDefaultImage
            gameFields,                                          // defaultFields
            3,                                                   // claimAmount
            true,                                               // enableMinting
            true,                                               // enableSvg
            "https://api.xsolla.com/heroes/"                    // baseURI
        );
    }
    
    function deployERC1155Collections() internal {
        console.log("Deploying ERC1155 ecosystem...");
        
        erc1155Deployer = new EIP1155();
        erc1155Deployer.deployWithCustomConfig(
            "https://api.xsolla.com/items/",  // baseURI
            100 ether,                        // claimAmount
            1,                               // tokenIdToClaim (Sword item)
            true,                            // enableMinting
            true                             // enableBurning
        );
    }
    
    function registerDeployments() internal {
        console.log("Registering deployments in AddressesReportConfig...");
        
        // Get the current network ID (assuming we're on ZK Sync Era = ID 2)
        uint256 networkId = 2;
        
        // Register ERC20 contracts
        reportsDeployer.addContract(
            networkId,
            "ERC20Factory",
            "ERC20Factory",
            address(erc20Deployer.erc20Factory())
        );
        
        reportsDeployer.addContract(
            networkId,
            "XsollaGameToken",
            "ERC20Modular", 
            address(erc20Deployer.modularERC20())
        );
        
        reportsDeployer.addContract(
            networkId,
            "ERC20Claimer",
            "ERC20Claimer",
            address(erc20Deployer.erc20Claimer())
        );
        
        // Register ERC721 contracts
        reportsDeployer.addContract(
            networkId,
            "ERC721Factory",
            "ERC721Factory",
            address(erc721Deployer.erc721Factory())
        );
        
        reportsDeployer.addContract(
            networkId,
            "XsollaGameHeroes",
            "ERC721Modular",
            address(erc721Deployer.modularERC721())
        );
        
        reportsDeployer.addContract(
            networkId,
            "ERC721Claimer",
            "ERC721Claimer",
            address(erc721Deployer.erc721Claimer())
        );
        
        // Register ERC1155 contracts
        reportsDeployer.addContract(
            networkId,
            "ERC1155Factory",
            "ERC1155Factory",
            address(erc1155Deployer.erc1155Factory())
        );
        
        reportsDeployer.addContract(
            networkId,
            "XsollaGameItems",
            "ERC1155Modular",
            address(erc1155Deployer.modularERC1155())
        );
        
        reportsDeployer.addContract(
            networkId,
            "ERC1155Claimer", 
            "ERC1155Claimer",
            address(erc1155Deployer.erc1155Claimer())
        );
        
        // Register Native Currency contracts
        (address weth9Address, address faucetAddress) = nativeCurrencyDeployer.getDeployedAddresses();
        
        if (weth9Address != address(0)) {
            reportsDeployer.addContract(
                networkId,
                "WETH9",
                "WETH9",
                weth9Address
            );
        }
        
        if (faucetAddress != address(0)) {
            reportsDeployer.addContract(
                networkId,
                "EthFaucet",
                "Faucet",
                faucetAddress
            );
        }
        
        // Register Fee Collector contracts
        (address baseFeeCollectorAddress, address ethereumFeeCollectorAddress) = feeCollectorsDeployer.getDeployedAddresses();
        
        if (baseFeeCollectorAddress != address(0)) {
            reportsDeployer.addContract(
                networkId,
                "BaseFeeCollector",
                "BaseFeeCollector",
                baseFeeCollectorAddress
            );
        }
        
        if (ethereumFeeCollectorAddress != address(0)) {
            reportsDeployer.addContract(
                networkId,
                "EthereumFeeCollector",
                "EthereumFeeCollector",
                ethereumFeeCollectorAddress
            );
        }
        
        console.log("All contracts registered successfully!");
    }
    
    function getDeploymentSummary() external view returns (
        address reportsConfig,
        address erc20Factory,
        address gameToken,
        address erc721Factory, 
        address gameHeroes,
        address erc1155Factory,
        address gameItems,
        address weth9,
        address faucet,
        address baseFeeCollector,
        address ethereumFeeCollector
    ) {
        (address weth9Address, address faucetAddress) = nativeCurrencyDeployer.getDeployedAddresses();
        (address baseFeeCollectorAddress, address ethereumFeeCollectorAddress) = feeCollectorsDeployer.getDeployedAddresses();
        
        return (
            address(reportsDeployer.addressesReportConfig()),
            address(erc20Deployer.erc20Factory()),
            address(erc20Deployer.modularERC20()),
            address(erc721Deployer.erc721Factory()),
            address(erc721Deployer.modularERC721()),
            address(erc1155Deployer.erc1155Factory()),
            address(erc1155Deployer.modularERC1155()),
            weth9Address,
            faucetAddress,
            baseFeeCollectorAddress,
            ethereumFeeCollectorAddress
        );
    }
}
