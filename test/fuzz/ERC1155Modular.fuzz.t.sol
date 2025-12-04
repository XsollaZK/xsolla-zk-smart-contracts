// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";

import { ERC1155Modular } from "src/token/ERC1155/extensions/ERC1155Modular.sol";

contract ERC1155ModularFuzzTest is Test {
    ERC1155Modular public token;
    address public owner;
    address public minter;
    address public burner;
    address public user;

    function setUp() public {
        owner = address(this);
        minter = makeAddr("minter");
        burner = makeAddr("burner");
        user = makeAddr("user");

        token = new ERC1155Modular();
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.toggleMinting();
    }

    function testFuzz_setBaseURI(string memory baseURI) public {
        vm.assume(bytes(baseURI).length <= 500); // Reasonable length

        token.setBaseURI(baseURI);

        // Test URI retrieval for various token IDs
        for (uint256 i = 0; i < 10; i++) {
            string memory uri = token.uri(i);
            // URI should be consistent (may be empty if baseURI is empty)
            if (bytes(baseURI).length > 0) {
                assertTrue(bytes(uri).length > 0);
            }
        }
    }

    function testFuzz_mintingToggle(bool initialState, uint8 toggleCount) public {
        vm.assume(toggleCount <= 20); // Reasonable toggle limit

        // Set initial minting state
        if (initialState != token.mintingEnabled()) {
            token.toggleMinting();
        }

        bool expectedState = initialState;

        for (uint256 i = 0; i < toggleCount; i++) {
            token.toggleMinting();
            expectedState = !expectedState;
            assertEq(token.mintingEnabled(), expectedState);
        }
    }

    function testFuzz_burningToggle(bool initialState, uint8 toggleCount) public {
        vm.assume(toggleCount <= 20);

        // Set initial burning state
        if (initialState != token.burningEnabled()) {
            token.toggleBurning();
        }

        bool expectedState = initialState;

        for (uint256 i = 0; i < toggleCount; i++) {
            token.toggleBurning();
            expectedState = !expectedState;
            assertEq(token.burningEnabled(), expectedState);
        }
    }

    function testFuzz_mint(address to, uint256 tokenId, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0); // Only EOA addresses to avoid callback
            // issues
        vm.assume(amount > 0 && amount <= type(uint128).max);
        vm.assume(tokenId <= type(uint128).max);

        vm.prank(minter);
        token.mint(to, tokenId, amount);

        assertEq(token.balanceOf(to, tokenId), amount);
    }

    function testFuzz_burn(uint256 tokenId, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount > 0 && mintAmount <= type(uint64).max);
        vm.assume(burnAmount <= mintAmount);
        vm.assume(tokenId <= type(uint64).max);

        token.toggleBurning();

        // First mint tokens
        vm.prank(minter);
        token.mint(user, tokenId, mintAmount);

        // Then burn some tokens
        vm.prank(burner);
        token.burn(user, tokenId, burnAmount);

        assertEq(token.balanceOf(user, tokenId), mintAmount - burnAmount);
    }

    function testFuzz_roleManagement(address account, bytes32 role) public {
        vm.assume(account != address(0));
        vm.assume(account != owner);

        // Test granting role
        token.grantRole(role, account);
        assertTrue(token.hasRole(role, account));

        // Test revoking role
        token.revokeRole(role, account);
        assertFalse(token.hasRole(role, account));
    }

    function testFuzz_unauthorizedMinting(address unauthorized, uint256 tokenId, uint256 amount) public {
        vm.assume(unauthorized != minter);
        vm.assume(unauthorized != owner);
        vm.assume(!token.hasRole(token.MINTER_ROLE(), unauthorized));

        vm.prank(unauthorized);
        vm.expectRevert();
        token.mint(user, tokenId, amount);
    }

    function testFuzz_unauthorizedBurning(address unauthorized, uint256 tokenId, uint256 amount) public {
        vm.assume(unauthorized != burner);
        vm.assume(unauthorized != owner);
        vm.assume(!token.hasRole(token.BURNER_ROLE(), unauthorized));
        vm.assume(amount > 0);

        // First mint some tokens
        vm.prank(minter);
        token.mint(user, tokenId, amount);

        vm.prank(unauthorized);
        vm.expectRevert();
        token.burn(user, tokenId, amount);
    }

    function testFuzz_mintingDisabled(uint256 tokenId, uint256 amount) public {
        vm.assume(amount > 0);

        // Disable minting
        if (token.mintingEnabled()) {
            token.toggleMinting();
        }

        vm.prank(minter);
        vm.expectRevert(ERC1155Modular.MintingDisabled.selector);
        token.mint(user, tokenId, amount);
    }

    function testFuzz_burningDisabled(uint256 tokenId, uint256 amount) public {
        vm.assume(amount > 0 && amount <= type(uint64).max);

        // First enable burning and mint tokens
        token.toggleBurning();
        vm.prank(minter);
        token.mint(user, tokenId, amount);

        // Then disable burning
        token.toggleBurning();

        vm.prank(burner);
        vm.expectRevert(ERC1155Modular.BurningDisabled.selector);
        token.burn(user, tokenId, amount);
    }

    function testFuzz_unauthorizedAdminFunctions(address unauthorized) public {
        vm.assume(unauthorized != owner);
        vm.assume(!token.hasRole(token.DEFAULT_ADMIN_ROLE(), unauthorized));

        vm.startPrank(unauthorized);

        vm.expectRevert();
        token.toggleMinting();

        vm.expectRevert();
        token.toggleBurning();

        vm.expectRevert();
        token.setBaseURI("unauthorized");

        vm.stopPrank();
    }

    function testFuzz_supportsInterface(bytes4 interfaceId) public view {
        // Test that supportsInterface doesn't revert with any interface ID
        token.supportsInterface(interfaceId);
    }

    function testFuzz_constantRoles() public view {
        // Verify role constants are consistent
        assertTrue(token.MINTER_ROLE() == keccak256("MINTER_ROLE"));
        assertTrue(token.BURNER_ROLE() == keccak256("BURNER_ROLE"));
    }

    function testFuzz_initialRoleAssignment() public view {
        // Verify owner has all necessary roles
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(token.MINTER_ROLE(), owner));
        assertTrue(token.hasRole(token.BURNER_ROLE(), owner));
    }
}
