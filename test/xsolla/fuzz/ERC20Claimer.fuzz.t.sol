// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { ERC20Claimer } from "src/xsolla/token/ERC20/ERC20Claimer.sol";
import { ERC20Modular } from "src/xsolla/token/ERC20/extensions/ERC20Modular.sol";

/// @title ERC20Claimer Fuzz Tests
/// @notice Comprehensive fuzz testing for the ERC20Claimer contract
contract ERC20ClaimerFuzzTest is Test {
    ERC20Claimer public claimer;
    ERC20Modular public token;
    address public owner;
    address public pauser;
    address public minter;
    address public user1;
    address public user2;

    event Claimed(address indexed claimer, uint256 indexed amount);
    error AlreadyClaimed(address claimer);

    function setUp() public {
        owner = address(this);
        pauser = makeAddr("pauser");
        minter = makeAddr("minter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy token
        token = new ERC20Modular("Test Token", "TEST", owner, pauser, minter);

        // Deploy claimer
        claimer = new ERC20Claimer(token);

        // Grant minter role to claimer
        token.grantRole(token.MINTER_ROLE(), address(claimer));
    }

    /// @notice Fuzz test for successful claiming
    function testFuzz_Claim_Success(address claimant) public {
        vm.assume(claimant != address(0));
        vm.assume(!claimer.isClaimed(claimant));

        uint256 initialBalance = token.balanceOf(claimant);
        uint256 initialSupply = token.totalSupply();
        uint256 claimAmount = claimer.amountToClaim();

        vm.expectEmit(true, true, false, false);
        emit Claimed(claimant, claimAmount);

        vm.prank(claimant);
        claimer.claim();

        assertTrue(claimer.isClaimed(claimant), "Should mark address as claimed");
        assertEq(token.balanceOf(claimant), initialBalance + claimAmount, "Should receive claim amount");
        assertEq(token.totalSupply(), initialSupply + claimAmount, "Total supply should increase");
    }

    /// @notice Fuzz test for claiming for another address
    function testFuzz_ClaimFor_Success(address caller, address recipient) public {
        vm.assume(caller != address(0) && recipient != address(0));
        vm.assume(!claimer.isClaimed(recipient));

        uint256 initialBalance = token.balanceOf(recipient);
        uint256 claimAmount = claimer.amountToClaim();

        vm.expectEmit(true, true, false, false);
        emit Claimed(recipient, claimAmount);

        vm.prank(caller);
        claimer.claimFor(recipient);

        assertTrue(claimer.isClaimed(recipient), "Should mark recipient as claimed");
        assertEq(token.balanceOf(recipient), initialBalance + claimAmount, "Recipient should receive claim amount");
    }

    /// @notice Fuzz test for double claiming (should fail)
    function testFuzz_Claim_AlreadyClaimed(address claimant) public {
        vm.assume(claimant != address(0));

        // First claim should succeed
        vm.prank(claimant);
        claimer.claim();

        // Second claim should fail
        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(AlreadyClaimed.selector, claimant));
        claimer.claim();
    }

    /// @notice Fuzz test for setting claim amount by owner
    function testFuzz_SetAmountToClaim_Owner(uint256 newAmount) public {
        vm.assume(newAmount > 0 && newAmount <= type(uint128).max);

        vm.prank(owner);
        claimer.setAmountToClaim(newAmount);

        assertEq(claimer.amountToClaim(), newAmount, "Claim amount should be updated");
    }

    /// @notice Fuzz test for setting claim amount by non-owner (should fail)
    function testFuzz_SetAmountToClaim_NonOwner(address caller, uint256 newAmount) public {
        vm.assume(caller != owner);
        vm.assume(newAmount > 0);

        vm.prank(caller);
        vm.expectRevert();
        claimer.setAmountToClaim(newAmount);
    }

    /// @notice Fuzz test for claiming with different amounts
    function testFuzz_ClaimWithDifferentAmounts(address claimant, uint256 claimAmount) public {
        vm.assume(claimant != address(0));
        vm.assume(claimAmount > 0 && claimAmount <= type(uint128).max);

        // Set custom claim amount
        vm.prank(owner);
        claimer.setAmountToClaim(claimAmount);

        uint256 initialBalance = token.balanceOf(claimant);

        vm.prank(claimant);
        claimer.claim();

        assertEq(token.balanceOf(claimant), initialBalance + claimAmount, "Should receive custom claim amount");
    }

    /// @notice Fuzz test for multiple users claiming
    function testFuzz_MultipleClaims(address[] memory claimants) public {
        vm.assume(claimants.length > 0 && claimants.length <= 10); // Reasonable
            // batch size

        uint256 claimAmount = claimer.amountToClaim();
        uint256 totalClaimed = 0;
        uint256 initialSupply = token.totalSupply();

        for (uint256 i = 0; i < claimants.length; i++) {
            vm.assume(claimants[i] != address(0));

            // Skip if already claimed (to handle duplicate addresses)
            if (claimer.isClaimed(claimants[i])) {
                continue;
            }

            vm.prank(claimants[i]);
            claimer.claim();

            totalClaimed += claimAmount;
            assertTrue(claimer.isClaimed(claimants[i]), "Address should be marked as claimed");
        }

        // Verify total supply increased by total claimed amount
        assertEq(token.totalSupply(), initialSupply + totalClaimed, "Total supply should increase by total claimed");
    }

    /// @notice Fuzz test for ownership transfer
    function testFuzz_OwnershipTransfer(address newOwner, uint256 newAmount) public {
        vm.assume(newOwner != address(0) && newOwner != owner);
        vm.assume(newAmount > 0 && newAmount <= type(uint128).max);

        // Transfer ownership
        vm.prank(owner);
        claimer.transferOwnership(newOwner);

        // Old owner should not be able to set claim amount
        vm.prank(owner);
        vm.expectRevert();
        claimer.setAmountToClaim(newAmount);

        // New owner should be able to set claim amount
        vm.prank(newOwner);
        claimer.setAmountToClaim(newAmount);

        assertEq(claimer.amountToClaim(), newAmount, "New owner should be able to set claim amount");
    }

    /// @notice Fuzz test for claiming when token is paused
    function testFuzz_ClaimWhenTokenPaused(address claimant) public {
        vm.assume(claimant != address(0));

        // Pause the token
        vm.prank(pauser);
        token.pause();

        // Claiming should fail when token is paused
        vm.prank(claimant);
        vm.expectRevert();
        claimer.claim();
    }

    /// @notice Fuzz test for claiming when claimer doesn't have minter role
    function testFuzz_ClaimWithoutMinterRole(address claimant) public {
        vm.assume(claimant != address(0));

        // Revoke minter role from claimer
        vm.prank(owner);
        token.revokeRole(token.MINTER_ROLE(), address(claimer));

        // Claiming should fail without minter role
        vm.prank(claimant);
        vm.expectRevert();
        claimer.claim();
    }

    /// @notice Fuzz test for edge case: zero claim amount
    function testFuzz_ZeroClaimAmount(address claimant) public {
        vm.assume(claimant != address(0));

        // Set claim amount to zero
        vm.prank(owner);
        claimer.setAmountToClaim(0);

        uint256 initialBalance = token.balanceOf(claimant);

        vm.prank(claimant);
        claimer.claim();

        assertEq(token.balanceOf(claimant), initialBalance, "Balance should not change with zero claim");
        assertTrue(claimer.isClaimed(claimant), "Should still mark as claimed");
    }

    /// @notice Fuzz test for maximum claim amount
    function testFuzz_MaxClaimAmount(address claimant) public {
        vm.assume(claimant != address(0));

        uint256 maxAmount = type(uint128).max;

        vm.prank(owner);
        claimer.setAmountToClaim(maxAmount);

        vm.prank(claimant);
        claimer.claim();

        assertEq(token.balanceOf(claimant), maxAmount, "Should receive maximum claim amount");
    }

    /// @notice Fuzz test for claim status checking
    function testFuzz_ClaimStatus(address claimant) public {
        vm.assume(claimant != address(0));

        assertFalse(claimer.isClaimed(claimant), "Should not be claimed initially");

        vm.prank(claimant);
        claimer.claim();

        assertTrue(claimer.isClaimed(claimant), "Should be claimed after claiming");
    }

    /// @notice Fuzz test for contract initialization
    function testFuzz_Initialization() public view {
        assertEq(address(claimer.tokenToClaim()), address(token), "Token address should be set correctly");
        assertEq(claimer.amountToClaim(), 100 ether, "Default claim amount should be 100 ether");
        assertEq(claimer.owner(), owner, "Owner should be set correctly");
    }

    /// @notice Fuzz test for gas consumption analysis
    function testFuzz_GasConsumption(address claimant) public {
        vm.assume(claimant != address(0));

        uint256 gasBefore = gasleft();
        vm.prank(claimant);
        claimer.claim();
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for claim:", gasUsed);
        assertLt(gasUsed, 150_000, "Gas usage should be reasonable");
    }

    /// @notice Fuzz test for claim batch operations
    function testFuzz_BatchClaiming(uint8 claimCount) public {
        claimCount = uint8(bound(claimCount, 1, 20));

        uint256 totalGas = 0;
        uint256 claimAmount = claimer.amountToClaim();
        uint256 initialSupply = token.totalSupply();

        for (uint8 i = 0; i < claimCount; i++) {
            address claimant = makeAddr(string(abi.encodePacked("claimant", vm.toString(i))));

            uint256 gasBefore = gasleft();
            vm.prank(claimant);
            claimer.claim();
            uint256 gasUsed = gasBefore - gasleft();
            totalGas += gasUsed;
        }

        assertEq(
            token.totalSupply(), initialSupply + (claimAmount * claimCount), "Total supply should increase correctly"
        );
        console.log("Average gas per claim:", totalGas / claimCount);
    }

    /// @notice Fuzz test for claiming with contract as recipient
    function testFuzz_ClaimToContract() public {
        // Deploy a simple contract to receive tokens
        TestReceiver receiver = new TestReceiver();

        vm.prank(address(receiver));
        claimer.claim();

        assertTrue(claimer.isClaimed(address(receiver)), "Contract should be able to claim");
        assertEq(token.balanceOf(address(receiver)), claimer.amountToClaim(), "Contract should receive tokens");
    }

    /// @notice Fuzz test for claim amount updates affecting pending claims
    function testFuzz_ClaimAmountUpdate(address claimant, uint256 newAmount) public {
        vm.assume(claimant != address(0));
        vm.assume(newAmount > 0 && newAmount <= type(uint128).max);
        vm.assume(newAmount != claimer.amountToClaim());

        // Update claim amount
        vm.prank(owner);
        claimer.setAmountToClaim(newAmount);

        // Claim with new amount
        vm.prank(claimant);
        claimer.claim();

        assertEq(token.balanceOf(claimant), newAmount, "Should claim with updated amount");
    }
}

/// @notice Simple contract for testing contract recipients
contract TestReceiver {
    // Empty contract that can receive tokens

    }
