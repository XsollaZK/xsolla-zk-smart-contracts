// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";

import { DeployStage } from "./DeployStage.s.sol";
import { ERC20Factory } from "../src/product/token/ERC20/ERC20Factory.sol";
import { ERC20Modular } from "../src/product/token/ERC20/extensions/ERC20Modular.sol";
import { ERC20Claimer } from "../src/product/token/ERC20/ERC20Claimer.sol";

contract EIP20 is DeployStage {
    ERC20Factory public erc20Factory;
    ERC20Modular public modularERC20;
    ERC20Claimer public erc20Claimer;

    // Customizable parameters
    struct ERC20Config {
        string name;
        string symbol;
        address defaultAdmin;
        address pauser;
        address minter;
        uint256 claimAmount;
    }

    ERC20Config public config;

    function _setupDefaultConfig() internal {
        config = ERC20Config({
            name: "Xsolla Token",
            symbol: "XSOLLA",
            defaultAdmin: msg.sender,
            pauser: msg.sender,
            minter: msg.sender,
            claimAmount: 100 ether
        });
    }

    function _setupCustomConfig(
        string memory _name,
        string memory _symbol,
        address _defaultAdmin,
        address _pauser,
        address _minter,
        uint256 _claimAmount
    ) internal {
        config = ERC20Config({
            name: _name,
            symbol: _symbol,
            defaultAdmin: _defaultAdmin,
            pauser: _pauser,
            minter: _minter,
            claimAmount: _claimAmount
        });
    }

    function _deployERC20Factory() internal {
        vm.startBroadcast();
        
        erc20Factory = new ERC20Factory();
        
        vm.stopBroadcast();
        
        console.log("ERC20Factory deployed at:", address(erc20Factory));
    }
    
    function _deployModularERC20() internal {
        vm.startBroadcast();
        
        // Deploy ERC20 token with customizable configuration
        modularERC20 = new ERC20Modular(
            config.name,              // name
            config.symbol,            // symbol
            config.defaultAdmin,      // defaultAdmin
            config.pauser,            // pauser
            config.minter             // minter
        );
        
        vm.stopBroadcast();
        
        console.log("ERC20Modular deployed at:", address(modularERC20));
        console.log("Token name:", modularERC20.name());
        console.log("Token symbol:", modularERC20.symbol());
    }

    function _deployERC20Claimer() internal {
        // ERC20Claimer requires an existing ERC20Modular token
        require(address(modularERC20) != address(0), "ERC20Modular must be deployed first");
        
        vm.startBroadcast();
        
        erc20Claimer = new ERC20Claimer(modularERC20);
        
        // Set custom claim amount
        erc20Claimer.setAmountToClaim(config.claimAmount);
        
        // Grant MINTER_ROLE to the claimer so it can mint tokens
        modularERC20.grantRole(modularERC20.MINTER_ROLE(), address(erc20Claimer));
        
        vm.stopBroadcast();
        
        console.log("ERC20Claimer deployed at:", address(erc20Claimer));
        console.log("Claim amount:", erc20Claimer.amountToClaim());
    }

    function _deployAll() internal {
        _deployERC20Factory();
        _deployModularERC20();
        _deployERC20Claimer();
        
        console.log("=== ERC20 Deployment Summary ===");
        console.log("ERC20Factory:     ", address(erc20Factory));
        console.log("ERC20Modular:     ", address(modularERC20));
        console.log("ERC20Claimer:     ", address(erc20Claimer));
        console.log("=== Configuration Used ===");
        console.log("Name:             ", config.name);
        console.log("Symbol:           ", config.symbol);
        console.log("Default Admin:    ", config.defaultAdmin);
        console.log("Pauser:           ", config.pauser);
        console.log("Minter:           ", config.minter);
        console.log("Claim Amount:     ", config.claimAmount);
    }

    // Public functions for customization
    function deployWithDefaults() external {
        _setupDefaultConfig();
        _deployAll();
    }

    function deployWithCustomConfig(
        string memory _name,
        string memory _symbol,
        address _defaultAdmin,
        address _pauser,
        address _minter,
        uint256 _claimAmount
    ) external {
        _setupCustomConfig(_name, _symbol, _defaultAdmin, _pauser, _minter, _claimAmount);
        _deployAll();
    }

    function setUp() public {
        _setupDefaultConfig();
    }

    function run() public {
        _deployAll();
    }
}
