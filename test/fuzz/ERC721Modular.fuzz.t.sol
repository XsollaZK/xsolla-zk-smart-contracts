// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";

import { ERC721Modular } from "src/token/ERC721/extensions/ERC721Modular.sol";
import { SVGIconsLib } from "src/libraries/SVGIconsLib.sol";

contract ERC721ModularFuzzTest is Test {
    ERC721Modular public token;
    address public minter = makeAddr("minter");
    address public user = makeAddr("user");

    function setUp() public {
        token = new ERC721Modular("Test NFT", "TEST", 10_000);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.toggleMinting();
    }

    function testFuzz_MintTokens(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        vm.assume(amount > 0 && amount <= 100);
        vm.assume(amount <= token.maxSupply());

        vm.startPrank(minter);
        for (uint256 i = 0; i < amount; i++) {
            token.mint(to);
        }
        vm.stopPrank();

        assertEq(token.balanceOf(to), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testFuzz_SetBaseUri(string memory baseUri) public {
        vm.assume(bytes(baseUri).length > 0 && bytes(baseUri).length <= 200);

        token.setBaseUri(baseUri);

        vm.prank(minter);
        token.mint(user);

        string memory tokenUri = token.tokenURI(1);
        assertTrue(bytes(tokenUri).length > 0);
    }

    function testFuzz_SetIpfsDefaultImage(string memory ipfsHash) public {
        vm.assume(bytes(ipfsHash).length > 0 && bytes(ipfsHash).length <= 100);

        token.setIpfsDefaultImage(ipfsHash);

        vm.prank(minter);
        token.mint(user);

        string memory tokenUri = token.tokenURI(1);
        assertTrue(bytes(tokenUri).length > 0);
    }

    function testFuzz_SetDefaultFields(
        string[8] memory fieldNames,
        string[8] memory fieldValues,
        string[8] memory fieldTypes
    ) public {
        SVGIconsLib.Field[8] memory fields;

        for (uint256 i = 0; i < 8; i++) {
            // Bound string lengths instead of using vm.assume
            bytes memory nameBytes = bytes(fieldNames[i]);
            bytes memory valueBytes = bytes(fieldValues[i]);
            bytes memory typeBytes = bytes(fieldTypes[i]);

            // Truncate strings if they're too long
            if (nameBytes.length > 50) {
                assembly {
                    mstore(nameBytes, 50)
                }
            }
            if (valueBytes.length > 100) {
                assembly {
                    mstore(valueBytes, 100)
                }
            }
            if (typeBytes.length > 20) {
                assembly {
                    mstore(typeBytes, 20)
                }
            }

            fields[i] = SVGIconsLib.Field(string(nameBytes), string(valueBytes), string(typeBytes));
        }

        token.setDefaultFields(fields);

        vm.prank(minter);
        token.mint(user);

        string memory tokenUri = token.tokenURI(1);
        assertTrue(bytes(tokenUri).length > 0);
    }

    function testFuzz_TransferTokens(address from, address to) public {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(from != to);
        vm.assume(from.code.length == 0);
        vm.assume(to.code.length == 0);

        // Mint token to 'from' address
        vm.prank(minter);
        token.mint(from);

        uint256 tokenId = token.nextTokenId();

        // Transfer token
        vm.prank(from);
        token.transferFrom(from, to, tokenId);

        assertEq(token.ownerOf(tokenId), to);
        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(to), 1);
    }

    function testFuzz_ApproveAndTransfer(address owner, address spender, address to) public {
        vm.assume(owner != address(0));
        vm.assume(spender != address(0));
        vm.assume(to != address(0));
        vm.assume(owner != spender);
        vm.assume(spender != to);
        vm.assume(owner.code.length == 0);
        vm.assume(spender.code.length == 0);
        vm.assume(to.code.length == 0);

        // Mint token to owner
        vm.prank(minter);
        token.mint(owner);

        uint256 tokenId = token.nextTokenId();

        // Approve spender
        vm.prank(owner);
        token.approve(spender, tokenId);

        assertEq(token.getApproved(tokenId), spender);

        // Transfer by approved spender
        vm.prank(spender);
        token.transferFrom(owner, to, tokenId);

        assertEq(token.ownerOf(tokenId), to);
    }

    function testFuzz_MaxSupplyLimit(uint256 maxSupply) public {
        vm.assume(maxSupply > 0 && maxSupply <= 1000);

        ERC721Modular limitedToken = new ERC721Modular("Limited", "LTD", maxSupply);
        limitedToken.grantRole(limitedToken.MINTER_ROLE(), minter);
        limitedToken.toggleMinting();

        // Mint up to max supply
        vm.startPrank(minter);
        for (uint256 i = 0; i < maxSupply; i++) {
            limitedToken.mint(user);
        }
        vm.stopPrank();

        assertEq(limitedToken.totalSupply(), maxSupply);

        // Should revert when trying to mint beyond max supply
        vm.prank(minter);
        vm.expectRevert(ERC721Modular.MaxSupplyReached.selector);
        limitedToken.mint(user);
    }

    function testFuzz_TokenURIGeneration(uint256 tokenId) public {
        vm.assume(tokenId > 0 && tokenId <= 10);

        // Mint token
        vm.prank(minter);
        token.mint(user);

        uint256 actualTokenId = token.nextTokenId();

        // Test with SVG disabled (default)
        string memory uriWithoutSvg = token.tokenURI(actualTokenId);
        assertTrue(bytes(uriWithoutSvg).length > 0);

        // Test with SVG enabled
        token.toggleSvg();
        string memory uriWithSvg = token.tokenURI(actualTokenId);
        assertTrue(bytes(uriWithSvg).length > 0);

        // URI should be different when SVG is enabled
        assertNotEq(keccak256(bytes(uriWithoutSvg)), keccak256(bytes(uriWithSvg)));
    }

    function testFuzz_SVGToggle() public {
        // Test SVG toggle functionality
        bool initialSvgState = token.utilizeSvg();

        token.toggleSvg();
        assertEq(token.utilizeSvg(), !initialSvgState);

        token.toggleSvg();
        assertEq(token.utilizeSvg(), initialSvgState);
    }

    function testFuzz_SelfMint(address to) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);

        // Grant minter role to the address
        token.grantRole(token.MINTER_ROLE(), to);

        vm.prank(to);
        token.mint();

        assertEq(token.balanceOf(to), 1);
        assertEq(token.ownerOf(token.nextTokenId()), to);
    }

    function testFuzz_RoleManagement(address newMinter) public {
        vm.assume(newMinter != address(0));
        vm.assume(newMinter != address(this));
        vm.assume(newMinter.code.length == 0);

        // Grant minter role
        token.grantRole(token.MINTER_ROLE(), newMinter);
        assertTrue(token.hasRole(token.MINTER_ROLE(), newMinter));

        // New minter can mint
        vm.prank(newMinter);
        token.mint(user);

        assertEq(token.balanceOf(user), 1);

        // Revoke minter role
        token.revokeRole(token.MINTER_ROLE(), newMinter);
        assertFalse(token.hasRole(token.MINTER_ROLE(), newMinter));

        // Should fail to mint after role revoked
        vm.prank(newMinter);
        vm.expectRevert();
        token.mint(user);
    }
}
