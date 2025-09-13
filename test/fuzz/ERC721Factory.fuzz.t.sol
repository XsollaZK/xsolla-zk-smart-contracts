// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";

import { ERC721Factory } from "../../src/product/token/ERC721/ERC721Factory.sol";
import { ERC721Modular } from "../../src/product/token/ERC721/extensions/ERC721Modular.sol";
import { SVGIconsLib } from "../../src/product/libraries/SVGIconsLib.sol";

contract ERC721FactoryFuzzTest is Test {
    ERC721Factory public factory;
    
    function setUp() public {
        factory = new ERC721Factory();
    }

    function testFuzz_DeployDefaultCollection(
        string memory name,
        string memory symbol
    ) public {
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 100);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 20);

        vm.expectEmit(false, false, false, false);
        emit ERC721Factory.NewCollectionDeployed(address(0));
        
        factory.deployDefaultCollection(name, symbol);
    }

    function testFuzz_DeployCustomCollection(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        string memory ipfsImage
    ) public {
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 100);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 20);
        vm.assume(maxSupply > 0 && maxSupply <= 1000000);
        vm.assume(bytes(ipfsImage).length > 0 && bytes(ipfsImage).length <= 100);

        SVGIconsLib.Field[8] memory customFields = [
            SVGIconsLib.Field('Custom: ', name, 'none'),
            SVGIconsLib.Field('Symbol: ', symbol, 'none'),
            SVGIconsLib.Field('', '', 'none'),
            SVGIconsLib.Field('', '', 'none'),
            SVGIconsLib.Field('', '', 'none'),
            SVGIconsLib.Field('', '', 'none'),
            SVGIconsLib.Field('', '', 'none'),
            SVGIconsLib.Field('', '', 'none')
        ];

        vm.expectEmit(false, false, false, false);
        emit ERC721Factory.NewCollectionDeployed(address(0));
        
        factory.deployCollection(customFields, ipfsImage, name, symbol, maxSupply);
    }

    function testFuzz_FactoryOwnership(address newOwner) public {
        vm.assume(newOwner != address(0));
        vm.assume(newOwner != address(this));
        vm.assume(newOwner.code.length == 0);
        
        factory.transferOwnership(newOwner);
        assertEq(factory.owner(), newOwner);
    }

    function testFuzz_DefaultConstants() public view {
        assertEq(factory.DEFAULT_MAX_SUPPLY(), 100_000);
        assertEq(factory.IPFS_DEFAULT_IMAGE(), "bafkreie7ohywtosou76tasm7j63yigtzxe7d5zqus4zu3j6oltvgtibeom");
    }

    function testFuzz_CustomFieldsValidation(
        string memory fieldName1,
        string memory fieldValue1,
        string memory name,
        string memory symbol
    ) public {
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 100);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 20);
        vm.assume(bytes(fieldName1).length <= 50);
        vm.assume(bytes(fieldValue1).length <= 100);

        SVGIconsLib.Field[8] memory customFields;
        
        // Only customize the first field, leave others as defaults
        customFields[0] = SVGIconsLib.Field(fieldName1, fieldValue1, "none");
        for (uint i = 1; i < 8; i++) {
            customFields[i] = SVGIconsLib.Field("", "", "none");
        }

        factory.deployCollection(
            customFields,
            factory.IPFS_DEFAULT_IMAGE(),
            name,
            symbol,
            1000
        );
    }
}