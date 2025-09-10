// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";

import { DeployStage } from "./DeployStage.s.sol";
import { ERC20Factory } from "../src/product/token/ERC20/ERC20Factory.sol";
import { ERC20Modular } from "../src/product/token/ERC20/extensions/ERC20Modular.sol";
import { ERC20Claimer } from "../src/product/token/ERC20/ERC20Claimer.sol";

contract EIP20 is DeployStage {
    error ERC20ModularNotDeployed();
    
    ERC20Factory public erc20Factory;
    ERC20Modular public modularERC20;
    ERC20Claimer public erc20Claimer;

    function setUp() public {}

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

    function deployWithCustomConfig(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser,
        address minter,
        uint256 claimAmount
    ) external {
        vm.startBroadcast();
        
        erc20Factory = new ERC20Factory();
        modularERC20 = new ERC20Modular(name, symbol, defaultAdmin, pauser, minter);
        
        erc20Claimer = new ERC20Claimer(modularERC20);
        erc20Claimer.setAmountToClaim(claimAmount);
        modularERC20.grantRole(modularERC20.MINTER_ROLE(), address(erc20Claimer));
        
        vm.stopBroadcast();
    }
}
