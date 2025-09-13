// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";
import { DeployStage } from "./DeployStage.s.sol";
import { BaseFeeCollector } from "../src/product/collector/BaseFeeCollector.sol";
import { EthereumFeeCollector } from "../src/product/collector/EthereumFeeCollector.sol";

/// @title SeaportFeesCollectors Deployment Script
/// @notice Minimal deployment for BaseFeeCollector and EthereumFeeCollector
contract SeaportFeesCollectors is DeployStage {
    
    error BaseFeeCollectorNotDeployed();
    error EthereumFeeCollectorNotDeployed();
    error InvalidCollectorType();

    BaseFeeCollector public baseFeeCollector;
    EthereumFeeCollector public ethereumFeeCollector;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        baseFeeCollector = new BaseFeeCollector();
        ethereumFeeCollector = new EthereumFeeCollector();
        vm.stopBroadcast();
        
        console.log("BaseFeeCollector:", address(baseFeeCollector));
        console.log("EthereumFeeCollector:", address(ethereumFeeCollector));
    }

    /// @notice Helper function to withdraw native tokens from BaseFeeCollector
    /// @param withdrawalWallet The wallet to receive the tokens
    /// @param amount Amount to withdraw
    function withdrawFromBaseFeeCollector(address withdrawalWallet, uint256 amount) external {
        if (address(baseFeeCollector) == address(0)) {
            revert BaseFeeCollectorNotDeployed();
        }
        baseFeeCollector.withdraw(withdrawalWallet, amount);
    }

    /// @notice Helper function to withdraw ERC20 tokens from BaseFeeCollector
    /// @param withdrawalWallet The wallet to receive the tokens
    /// @param tokenContract The ERC20 token contract address
    /// @param amount Amount to withdraw
    function withdrawERC20FromBaseFeeCollector(address withdrawalWallet, address tokenContract, uint256 amount) external {
        if (address(baseFeeCollector) == address(0)) {
            revert BaseFeeCollectorNotDeployed();
        }
        baseFeeCollector.withdrawERC20Tokens(withdrawalWallet, tokenContract, amount);
    }

    /// @notice Helper function to unwrap and withdraw WETH from EthereumFeeCollector
    /// @param withdrawalWallet The wallet to receive the ETH
    /// @param wrappedTokenContract The WETH contract address
    /// @param amount Amount to unwrap and withdraw
    function unwrapAndWithdrawFromEthereumFeeCollector(
        address withdrawalWallet, 
        address wrappedTokenContract, 
        uint256 amount
    ) external {
        if (address(ethereumFeeCollector) == address(0)) {
            revert EthereumFeeCollectorNotDeployed();
        }
        ethereumFeeCollector.unwrapAndWithdraw(withdrawalWallet, wrappedTokenContract, amount);
    }

    /// @notice Add withdrawal wallet to fee collector
    /// @param collector The fee collector contract (0 = Base, 1 = Ethereum)
    /// @param withdrawalWallet The wallet address to add
    function addWithdrawalWallet(uint8 collector, address withdrawalWallet) external {
        if (collector == 0) {
            if (address(baseFeeCollector) == address(0)) {
                revert BaseFeeCollectorNotDeployed();
            }
            baseFeeCollector.addWithdrawAddress(withdrawalWallet);
        } else if (collector == 1) {
            if (address(ethereumFeeCollector) == address(0)) {
                revert EthereumFeeCollectorNotDeployed();
            }
            ethereumFeeCollector.addWithdrawAddress(withdrawalWallet);
        } else {
            revert InvalidCollectorType();
        }
    }

    /// @notice Remove withdrawal wallet from fee collector
    /// @param collector The fee collector contract (0 = Base, 1 = Ethereum)
    /// @param withdrawalWallet The wallet address to remove
    function removeWithdrawalWallet(uint8 collector, address withdrawalWallet) external {
        if (collector == 0) {
            if (address(baseFeeCollector) == address(0)) {
                revert BaseFeeCollectorNotDeployed();
            }
            baseFeeCollector.removeWithdrawAddress(withdrawalWallet);
        } else if (collector == 1) {
            if (address(ethereumFeeCollector) == address(0)) {
                revert EthereumFeeCollectorNotDeployed();
            }
            ethereumFeeCollector.removeWithdrawAddress(withdrawalWallet);
        } else {
            revert InvalidCollectorType();
        }
    }

    /// @notice Assign operator to fee collector
    /// @param collector The fee collector contract (0 = Base, 1 = Ethereum)
    /// @param operatorToAssign The operator address to assign
    function assignOperator(uint8 collector, address operatorToAssign) external {
        if (collector == 0) {
            if (address(baseFeeCollector) == address(0)) {
                revert BaseFeeCollectorNotDeployed();
            }
            baseFeeCollector.assignOperator(operatorToAssign);
        } else if (collector == 1) {
            if (address(ethereumFeeCollector) == address(0)) {
                revert EthereumFeeCollectorNotDeployed();
            }
            ethereumFeeCollector.assignOperator(operatorToAssign);
        } else {
            revert InvalidCollectorType();
        }
    }

    /// @notice Check if address is a withdrawal wallet
    /// @param collector The fee collector contract (0 = Base, 1 = Ethereum)
    /// @param wallet The wallet address to check
    /// @return Whether the wallet is a valid withdrawal wallet
    function isWithdrawalWallet(uint8 collector, address wallet) external view returns (bool) {
        if (collector == 0) {
            if (address(baseFeeCollector) == address(0)) {
                revert BaseFeeCollectorNotDeployed();
            }
            return baseFeeCollector.isWithdrawalWallet(wallet);
        } else if (collector == 1) {
            if (address(ethereumFeeCollector) == address(0)) {
                revert EthereumFeeCollectorNotDeployed();
            }
            return ethereumFeeCollector.isWithdrawalWallet(wallet);
        } else {
            revert InvalidCollectorType();
        }
    }

    function getDeployedAddresses() external view returns (address, address) {
        return (address(baseFeeCollector), address(ethereumFeeCollector));
    }
}