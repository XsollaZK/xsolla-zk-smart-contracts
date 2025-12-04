// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { ERC20Modular } from "src/token/ERC20/extensions/ERC20Modular.sol";

/// @title ERC20Modular Fuzz Tests
/// @notice Comprehensive fuzz testing for the ERC20Modular contract
contract ERC20ModularFuzzTest is Test {
    ERC20Modular public token;
    address public pauser;
    address public minter;
    address public user1;
    address public user2;
    address public randomUser;

    // Role constants
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function setUp() public {
        pauser = makeAddr("pauser");
        minter = makeAddr("minter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        randomUser = makeAddr("randomUser");

        token = new ERC20Modular("Test Token", "TEST", address(this), pauser, minter);
    }

    /// @notice Fuzz test for minting tokens
    function testFuzz_Mint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount <= type(uint128).max); // Reasonable upper bound

        uint256 initialBalance = token.balanceOf(to);
        uint256 initialSupply = token.totalSupply();

        vm.prank(minter);
        token.mint(to, amount);

        assertEq(token.balanceOf(to), initialBalance + amount, "Balance should increase by minted amount");
        assertEq(token.totalSupply(), initialSupply + amount, "Total supply should increase by minted amount");
    }

    /// @notice Fuzz test for minting failure when not minter
    function testFuzz_Mint_OnlyMinter(address caller, address to, uint256 amount) public {
        vm.assume(caller != minter);
        vm.assume(to != address(0));
        vm.assume(amount > 0);
        vm.assume(amount <= type(uint128).max);

        vm.prank(caller);
        vm.expectRevert();
        token.mint(to, amount);
    }

    /// @notice Fuzz test for minting when paused
    function testFuzz_Mint_WhenPaused(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0);
        vm.assume(amount <= type(uint128).max);

        // Pause the contract
        vm.prank(pauser);
        token.pause();

        vm.prank(minter);
        vm.expectRevert();
        token.mint(to, amount);
    }

    /// @notice Fuzz test for pause functionality
    function testFuzz_Pause(address caller) public {
        vm.assume(caller != pauser);

        // Non-pauser should not be able to pause
        vm.prank(caller);
        vm.expectRevert();
        token.pause();

        // Pauser should be able to pause
        vm.prank(pauser);
        token.pause();
        assertTrue(token.paused(), "Token should be paused");
    }

    /// @notice Fuzz test for unpause functionality
    function testFuzz_Unpause(address caller) public {
        // First pause the token
        vm.prank(pauser);
        token.pause();

        vm.assume(caller != pauser);

        // Non-pauser should not be able to unpause
        vm.prank(caller);
        vm.expectRevert();
        token.unpause();

        // Pauser should be able to unpause
        vm.prank(pauser);
        token.unpause();
        assertFalse(token.paused(), "Token should be unpaused");
    }

    /// @notice Fuzz test for transfers when not paused
    function testFuzz_Transfer(address from, address to, uint256 amount) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(amount > 0 && amount <= type(uint128).max);

        // Mint tokens to from address
        vm.prank(minter);
        token.mint(from, amount);

        uint256 fromInitialBalance = token.balanceOf(from);
        uint256 toInitialBalance = token.balanceOf(to);

        vm.prank(from);
        token.transfer(to, amount);

        assertEq(token.balanceOf(from), fromInitialBalance - amount, "From balance should decrease");
        assertEq(token.balanceOf(to), toInitialBalance + amount, "To balance should increase");
    }

    /// @notice Fuzz test for transfers when paused
    function testFuzz_Transfer_WhenPaused(address from, address to, uint256 amount) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(amount > 0 && amount <= type(uint128).max);

        // Mint tokens to from address
        vm.prank(minter);
        token.mint(from, amount);

        // Pause the contract
        vm.prank(pauser);
        token.pause();

        vm.prank(from);
        vm.expectRevert();
        token.transfer(to, amount);
    }

    /// @notice Fuzz test for approve functionality
    function testFuzz_Approve(address owner, address spender, uint256 amount) public {
        vm.assume(owner != address(0) && spender != address(0));
        vm.assume(owner != spender);

        vm.prank(owner);
        token.approve(spender, amount);

        assertEq(token.allowance(owner, spender), amount, "Allowance should be set correctly");
    }

    /// @notice Fuzz test for transferFrom functionality
    function testFuzz_TransferFrom(
        address owner,
        address spender,
        address to,
        uint256 mintAmount,
        uint256 transferAmount
    ) public {
        vm.assume(owner != address(0) && spender != address(0) && to != address(0));
        vm.assume(owner != spender && owner != to && spender != to);
        vm.assume(mintAmount > 0 && mintAmount <= type(uint128).max);
        vm.assume(transferAmount > 0 && transferAmount <= mintAmount);

        // Mint tokens to owner
        vm.prank(minter);
        token.mint(owner, mintAmount);

        // Approve spender
        vm.prank(owner);
        token.approve(spender, transferAmount);

        uint256 ownerInitialBalance = token.balanceOf(owner);
        uint256 toInitialBalance = token.balanceOf(to);

        vm.prank(spender);
        token.transferFrom(owner, to, transferAmount);

        assertEq(token.balanceOf(owner), ownerInitialBalance - transferAmount, "Owner balance should decrease");
        assertEq(token.balanceOf(to), toInitialBalance + transferAmount, "To balance should increase");
        assertEq(token.allowance(owner, spender), 0, "Allowance should be reduced to zero for exact amount");
    }

    /// @notice Fuzz test for role granting
    function testFuzz_GrantRole(address account) public {
        vm.assume(account != address(0));
        vm.assume(account != address(this));
        vm.assume(account != pauser);
        vm.assume(account != minter);

        bytes32 role = PAUSER_ROLE; // Use a fixed role to avoid assumption
            // issues

        token.grantRole(role, account);

        assertTrue(token.hasRole(role, account), "Role should be granted");
    }

    /// @notice Fuzz test for role revoking
    function testFuzz_RevokeRole(address account) public {
        vm.assume(account != address(0));
        vm.assume(account != address(this));
        vm.assume(account != pauser);
        vm.assume(account != minter);

        bytes32 role = MINTER_ROLE; // Use a fixed role to avoid assumption
            // issues

        // First grant the role
        token.grantRole(role, account);

        // Then revoke it
        token.revokeRole(role, account);

        assertFalse(token.hasRole(role, account), "Role should be revoked");
    }

    /// @notice Fuzz test for unauthorized role operations
    function testFuzz_UnauthorizedRoleOperations(address caller, address account) public {
        vm.assume(caller != address(this));
        vm.assume(caller != address(0));
        vm.assume(account != address(0));

        bytes32 role = PAUSER_ROLE; // Use a fixed role to avoid assumption
            // issues

        vm.prank(caller);
        vm.expectRevert();
        token.grantRole(role, account);

        vm.prank(caller);
        vm.expectRevert();
        token.revokeRole(role, account);
    }

    /// @notice Fuzz test for permit functionality
    function testFuzz_Permit(uint256 privateKey, address spender, uint256 amount, uint256 deadline) public {
        vm.assume(privateKey > 0 && privateKey < 2 ** 255); // Valid private key
            // range
        vm.assume(spender != address(0));
        vm.assume(deadline > block.timestamp);

        address owner = vm.addr(privateKey);
        vm.assume(owner != spender);

        uint256 nonce = token.nonces(owner);

        // Create permit signature
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                amount,
                nonce,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);

        token.permit(owner, spender, amount, deadline, v, r, s);

        assertEq(token.allowance(owner, spender), amount, "Permit should set allowance");
        assertEq(token.nonces(owner), nonce + 1, "Nonce should be incremented");
    }

    /// @notice Fuzz test for batch operations
    function testFuzz_BatchMinting(uint8 recipientCount) public {
        recipientCount = uint8(bound(recipientCount, 1, 5)); // Small batch size

        uint256 totalMinted = 0;
        uint256 initialSupply = token.totalSupply();
        uint256 baseAmount = 1e18;

        vm.startPrank(minter);
        for (uint8 i = 0; i < recipientCount; i++) {
            address recipient = makeAddr(string(abi.encodePacked("recipient", vm.toString(i))));
            uint256 amount = baseAmount * (i + 1);

            token.mint(recipient, amount);
            totalMinted += amount;
        }
        vm.stopPrank();

        assertEq(token.totalSupply(), initialSupply + totalMinted, "Total supply should increase by total minted");
    }

    /// @notice Fuzz test for edge case: zero amount operations
    function testFuzz_ZeroAmountOperations(address to) public {
        vm.assume(to != address(0));

        // Minting zero should work
        vm.prank(minter);
        token.mint(to, 0);

        // Transfer zero should work
        vm.prank(to);
        token.transfer(user1, 0);

        // Approve zero should work
        vm.prank(to);
        token.approve(user1, 0);
    }

    /// @notice Fuzz test for maximum supply scenarios
    function testFuzz_MaxSupplyMinting(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 > 0 && amount1 <= type(uint128).max);
        vm.assume(amount2 > 0 && amount2 <= type(uint128).max);
        vm.assume(amount1 + amount2 >= amount1); // No overflow

        vm.startPrank(minter);
        token.mint(user1, amount1);
        token.mint(user2, amount2);
        vm.stopPrank();

        assertEq(token.totalSupply(), amount1 + amount2, "Total supply should equal sum of minted amounts");
    }

    /// @notice Fuzz test for role admin functionality
    function testFuzz_RoleAdmin() public view {
        assertEq(token.getRoleAdmin(PAUSER_ROLE), DEFAULT_ADMIN_ROLE, "Pauser role admin should be default admin");
        assertEq(token.getRoleAdmin(MINTER_ROLE), DEFAULT_ADMIN_ROLE, "Minter role admin should be default admin");
    }

    /// @notice Fuzz test for decimal places
    function testFuzz_Decimals() public view {
        assertEq(token.decimals(), 18, "Should have 18 decimal places");
    }

    /// @notice Fuzz test for token metadata
    function testFuzz_TokenMetadata() public view {
        assertEq(token.name(), "Test Token", "Name should match");
        assertEq(token.symbol(), "TEST", "Symbol should match");
    }

    /// @notice Fuzz test for gas optimization on repeated operations
    function testFuzz_GasOptimization(uint8 operationCount) public {
        operationCount = uint8(bound(operationCount, 1, 20));

        uint256 totalGas = 0;

        vm.startPrank(minter);
        for (uint8 i = 0; i < operationCount; i++) {
            uint256 gasBefore = gasleft();
            token.mint(user1, 1e18);
            uint256 gasUsed = gasBefore - gasleft();
            totalGas += gasUsed;
        }
        vm.stopPrank();

        console.log("Average gas per mint:", totalGas / operationCount);
    }
}
