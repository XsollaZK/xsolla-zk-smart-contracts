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
/// @notice Minimal script for deploying all Xsolla ecosystem contracts
contract ComprehensiveDeployment is Script {
    
    EIP20 public erc20;
    EIP721 public erc721;
    EIP1155 public erc1155;
    Reports public reports;
    NativeCurrency public native;
    SeaportFeesCollectors public fees;
    
    address constant ADMIN = 0x1234567890123456789012345678901234567890;
    
    function run() external {
        vm.startBroadcast();
        
        // Deploy infrastructure
        reports = new Reports();
        reports.deployWithBasicConfig(ADMIN, ADMIN);
        
        native = new NativeCurrency();
        native.run();
        
        fees = new SeaportFeesCollectors();
        fees.run();
        
        // Deploy tokens
        erc20 = new EIP20();
        erc20.deployWithCustomConfig("Xsolla Game Token", "XGT", ADMIN, ADMIN, ADMIN, 1000 ether);
        
        erc721 = new EIP721();
        erc721.deployWithCustomConfig("Xsolla Game Heroes", "XGH", 50000,
            "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
            _gameFields(), 3, true, true, "https://api.xsolla.com/heroes/");
        
        erc1155 = new EIP1155();
        erc1155.deployWithCustomConfig("https://api.xsolla.com/items/", 100 ether, 1, true, true);
        
        // Register deployments
        _register("ERC20Factory", address(erc20.erc20Factory()));
        _register("ERC721Factory", address(erc721.erc721Factory()));
        _register("ERC1155Factory", address(erc1155.erc1155Factory()));
        
        (address weth9, address faucet) = native.getDeployedAddresses();
        if (weth9 != address(0)) _register("WETH9", weth9);
        if (faucet != address(0)) _register("EthFaucet", faucet);
        
        vm.stopBroadcast();
        console.log("Deployment complete");
    }
    
    function _gameFields() private pure returns (SVGIconsLib.Field[8] memory) {
        return [
            SVGIconsLib.Field('Game: ', 'Xsolla Adventure', 'none'),
            SVGIconsLib.Field('Rarity: ', 'Epic', 'none'),
            SVGIconsLib.Field('Level: ', '100', 'number'),
            SVGIconsLib.Field('Power: ', '9001', 'number'),
            SVGIconsLib.Field('Element: ', 'Fire', 'none'),
            SVGIconsLib.Field('Class: ', 'Warrior', 'none'),
            SVGIconsLib.Field('', '', 'none'),
            SVGIconsLib.Field('', '', 'none')
        ];
    }
    
    function _register(string memory name, address addr) private {
        if (addr != address(0)) reports.addContract(2, name, name, addr);
    }
}
