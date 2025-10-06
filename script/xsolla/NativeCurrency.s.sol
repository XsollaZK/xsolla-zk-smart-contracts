// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";

import { WETH9 } from "src/xsolla/WETH9.sol";
import { Faucet } from "src/xsolla/Faucet.sol";

import { DeployStage } from "./base/DeployStage.s.sol";

/// @title NativeCurrency Deployment Script
/// @notice Minimal deployment for WETH9 and Faucet contracts
contract NativeCurrency is DeployStage {
    error FaucetNotDeployed();
    error WETH9NotDeployed();
    error InsufficientETH();

    WETH9 public weth9;
    Faucet public faucet;

    function setUp() public { }

    function run() public {
        vm.startBroadcast();
        weth9 = new WETH9();
        faucet = new Faucet();
        vm.stopBroadcast();

        console.log("WETH9:", address(weth9));
        console.log("Faucet:", address(faucet));
    }

    /// @notice Helper function to claim from faucet (for testing)
    /// @param destination Address to receive the ETH
    function claimFromFaucet(address destination) external payable {
        if (address(faucet) == address(0)) {
            revert FaucetNotDeployed();
        }
        faucet.faucet{ value: msg.value }(destination);
    }

    /// @notice Helper function to deposit ETH to WETH9
    /// @param amount Amount of ETH to wrap
    function wrapETH(uint256 amount) external payable {
        if (address(weth9) == address(0)) {
            revert WETH9NotDeployed();
        }
        if (msg.value < amount) {
            revert InsufficientETH();
        }
        weth9.deposit{ value: amount }();
    }

    /// @notice Helper function to withdraw WETH9 back to ETH
    /// @param amount Amount of WETH to unwrap
    function unwrapETH(uint256 amount) external {
        if (address(weth9) == address(0)) {
            revert WETH9NotDeployed();
        }
        weth9.withdraw(amount);
    }

    function getDeployedAddresses() external view returns (address, address) {
        return (address(weth9), address(faucet));
    }
}
