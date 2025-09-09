// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";

import { DeployStage } from "./DeployStage.s.sol";
import { AddressesReportConfig } from "../src/product/AddressesReportConfig.sol";

contract Reports is DeployStage {
    AddressesReportConfig public addressesReportConfig;

    // Customizable parameters
    struct ReportsConfig {
        address defaultAdmin;
        address maintainer;
        bool setupInitialNetworks;
        NetworkConfig[] initialNetworks;
    }

    struct NetworkConfig {
        string name;
        string explorerUrl;
        ContractConfig[] contracts;
    }

    struct ContractConfig {
        string name;
        string artifact;
        address addr;
    }

    ReportsConfig public config;

    function _setupDefaultConfig() internal {
        // Create default network configurations
        NetworkConfig[] memory networks = new NetworkConfig[](3);
        
        // Mainnet configuration
        ContractConfig[] memory mainnetContracts = new ContractConfig[](0);
        networks[0] = NetworkConfig({
            name: "Ethereum Mainnet",
            explorerUrl: "https://etherscan.io",
            contracts: mainnetContracts
        });

        // ZK Sync Era configuration
        ContractConfig[] memory zkSyncContracts = new ContractConfig[](0);
        networks[1] = NetworkConfig({
            name: "ZK Sync Era",
            explorerUrl: "https://explorer.zksync.io",
            contracts: zkSyncContracts
        });

        // Sepolia Testnet configuration
        ContractConfig[] memory sepoliaContracts = new ContractConfig[](0);
        networks[2] = NetworkConfig({
            name: "Sepolia Testnet",
            explorerUrl: "https://sepolia.etherscan.io",
            contracts: sepoliaContracts
        });

        config = ReportsConfig({
            defaultAdmin: msg.sender,
            maintainer: msg.sender,
            setupInitialNetworks: true,
            initialNetworks: networks
        });
    }

    function _setupCustomConfig(
        address _defaultAdmin,
        address _maintainer,
        bool _setupInitialNetworksFlag,
        NetworkConfig[] memory _initialNetworks
    ) internal {
        config = ReportsConfig({
            defaultAdmin: _defaultAdmin,
            maintainer: _maintainer,
            setupInitialNetworks: _setupInitialNetworksFlag,
            initialNetworks: _initialNetworks
        });
    }

    function _deployAddressesReportConfig() internal {
        vm.startBroadcast();
        
        addressesReportConfig = new AddressesReportConfig();
        
        // Set up roles if different from deployer
        if (config.defaultAdmin != msg.sender) {
            addressesReportConfig.grantRole(addressesReportConfig.DEFAULT_ADMIN_ROLE(), config.defaultAdmin);
            addressesReportConfig.revokeRole(addressesReportConfig.DEFAULT_ADMIN_ROLE(), msg.sender);
        }
        
        if (config.maintainer != msg.sender && config.maintainer != config.defaultAdmin) {
            addressesReportConfig.grantRole(addressesReportConfig.MAINTAINER_ROLE(), config.maintainer);
        }
        
        vm.stopBroadcast();
        
        console.log("AddressesReportConfig deployed at:", address(addressesReportConfig));
        console.log("Default Admin:", config.defaultAdmin);
        console.log("Maintainer:", config.maintainer);
    }

    function _setupInitialNetworks() internal {
        if (!config.setupInitialNetworks) {
            console.log("Skipping initial network setup");
            return;
        }

        vm.startBroadcast();
        
        for (uint256 i = 0; i < config.initialNetworks.length; i++) {
            NetworkConfig memory network = config.initialNetworks[i];
            
            // Create network report
            uint256 networkId = addressesReportConfig.insertNetworkReport(
                0, // 0 for new network
                network.name,
                network.explorerUrl
            );
            
            console.log("Created network report:", network.name, "with ID:", networkId);
            
            // Add contracts to network if any
            for (uint256 j = 0; j < network.contracts.length; j++) {
                ContractConfig memory contractInfo = network.contracts[j];
                
                uint256 contractId = addressesReportConfig.insertContractReport(
                    networkId,
                    0, // 0 for new contract
                    contractInfo.name,
                    contractInfo.artifact,
                    contractInfo.addr
                );
                
                console.log("Added contract:", contractInfo.name, "with ID:", contractId);
            }
        }
        
        vm.stopBroadcast();
    }

    function _deployAll() internal {
        _deployAddressesReportConfig();
        _setupInitialNetworks();
        
        console.log("=== Reports Deployment Summary ===");
        console.log("AddressesReportConfig: ", address(addressesReportConfig));
        console.log("=== Configuration Used ===");
        console.log("Default Admin:         ", config.defaultAdmin);
        console.log("Maintainer:            ", config.maintainer);
        console.log("Setup Initial Networks:", config.setupInitialNetworks);
        console.log("Initial Networks Count:", config.initialNetworks.length);
        
        // Display current state
        console.log("=== Current State ===");
        console.log("Total Networks:        ", addressesReportConfig.getNetworkReportCount());
    }

    // Public functions for customization
    function deployWithDefaults() external {
        _setupDefaultConfig();
        _deployAll();
    }

    function deployWithCustomConfig(
        address _defaultAdmin,
        address _maintainer,
        bool _setupInitialNetworksFlag,
        NetworkConfig[] memory _initialNetworks
    ) external {
        _setupCustomConfig(_defaultAdmin, _maintainer, _setupInitialNetworksFlag, _initialNetworks);
        _deployAll();
    }

    // Convenience function for basic customization
    function deployWithBasicConfig(
        address _defaultAdmin,
        address _maintainer
    ) external {
        _setupDefaultConfig();
        config.defaultAdmin = _defaultAdmin;
        config.maintainer = _maintainer;
        _deployAll();
    }

    // Function to deploy without initial networks
    function deployEmpty() external {
        _setupDefaultConfig();
        config.setupInitialNetworks = false;
        config.initialNetworks = new NetworkConfig[](0);
        _deployAll();
    }

    // Helper function to add network after deployment
    function addNetwork(
        string memory _name,
        string memory _explorerUrl
    ) external returns (uint256 networkId) {
        require(address(addressesReportConfig) != address(0), "AddressesReportConfig not deployed");
        
        vm.startBroadcast();
        networkId = addressesReportConfig.insertNetworkReport(0, _name, _explorerUrl);
        vm.stopBroadcast();
        
        console.log("Added network:", _name, "with ID:", networkId);
    }

    // Helper function to add contract to existing network
    function addContract(
        uint256 _networkId,
        string memory _name,
        string memory _artifact,
        address _addr
    ) external returns (uint256 contractId) {
        require(address(addressesReportConfig) != address(0), "AddressesReportConfig not deployed");
        
        vm.startBroadcast();
        contractId = addressesReportConfig.insertContractReport(_networkId, 0, _name, _artifact, _addr);
        vm.stopBroadcast();
        
        console.log("Added contract:", _name, "to network ID:", _networkId);
        console.log("Contract ID:", contractId);
    }

    function setUp() public {
        _setupDefaultConfig();
    }

    function run() public {
        _deployAll();
    }
}
