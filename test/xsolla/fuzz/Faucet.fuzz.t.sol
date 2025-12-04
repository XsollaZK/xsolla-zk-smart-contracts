// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";

import { Faucet } from "src/xsolla/Faucet.sol";

contract FaucetFuzzTest is Test {
    Faucet public faucet;
    address public owner;

    function setUp() public {
        owner = address(this);
        faucet = new Faucet();
    }

    function testFuzz_FaucetClaim_Success(address destination, uint256 timeOffset) public {
        vm.assume(destination != address(0));
        vm.assume(destination != address(faucet));
        vm.assume(destination.code.length == 0); // Only EOAs can receive ETH without payable fallback
        vm.assume(timeOffset >= 24 hours && timeOffset <= 365 days);
        vm.assume(timeOffset <= type(uint256).max - block.timestamp);

        // Start at a safe timestamp to avoid arithmetic edge cases
        vm.warp(365 days); // Start at 1 year to ensure safe arithmetic

        uint256 portion = faucet.portion();
        vm.deal(address(this), portion * 2);

        uint256 balanceBefore = destination.balance;

        // First claim should always work for new addresses
        faucet.faucet{ value: portion }(destination);

        assertEq(destination.balance, balanceBefore + portion);
        assertEq(faucet.lastClaimed(destination), block.timestamp);

        // Move forward in time
        vm.warp(block.timestamp + timeOffset);

        // Second claim should work after waiting period
        faucet.faucet{ value: portion }(destination);
        assertEq(destination.balance, balanceBefore + (2 * portion));
    }

    function testFuzz_FaucetClaim_RevertInvalidAmount(address destination, uint256 amount) public {
        vm.assume(destination != address(0));
        vm.assume(amount != faucet.portion());
        vm.deal(address(this), amount);

        vm.expectRevert(Faucet.InvalidPortionAmount.selector);
        faucet.faucet{ value: amount }(destination);
    }

    function testFuzz_FaucetClaim_RevertTooEarly(address destination, uint256 timeOffset) public {
        vm.assume(destination != address(0));
        vm.assume(destination != address(faucet));
        vm.assume(destination.code.length == 0); // Only EOAs can receive ETH without payable fallback
        vm.assume(timeOffset > 0 && timeOffset < 24 hours);
        vm.assume(timeOffset <= type(uint256).max - block.timestamp);

        uint256 portion = faucet.portion();
        vm.deal(address(this), portion * 2);

        // Start at a time that's safe for arithmetic
        vm.warp(24 hours + 1);

        // First claim
        faucet.faucet{ value: portion }(destination);

        // Try to claim again too early
        vm.warp(block.timestamp + timeOffset);

        vm.expectRevert(Faucet.ClaimNotAllowedYet.selector);
        faucet.faucet{ value: portion }(destination);
    }

    function testFuzz_AvailableToFaucet(address destination, uint256 timeOffset) public {
        vm.assume(destination != address(0));
        vm.assume(destination != address(faucet));
        vm.assume(destination.code.length == 0); // Only EOAs can receive ETH without payable fallback
        vm.assume(timeOffset <= 365 days);
        vm.assume(timeOffset <= type(uint256).max - block.timestamp);

        // Start at a safe timestamp to avoid edge cases
        vm.warp(24 hours + 1);

        // First claim should always be available for new addresses
        Faucet.FaucetAvailability memory availability = faucet.availableToFaucet(destination);
        assertTrue(availability.available);

        // Make a claim
        uint256 portion = faucet.portion();
        vm.deal(address(this), portion);
        faucet.faucet{ value: portion }(destination);

        // Should not be available immediately after claiming
        availability = faucet.availableToFaucet(destination);
        assertFalse(availability.available);

        // Test availability based on time offset
        if (timeOffset > 0) {
            vm.warp(block.timestamp + timeOffset);

            availability = faucet.availableToFaucet(destination);
            if (timeOffset >= 24 hours) {
                assertTrue(availability.available);
            } else {
                assertFalse(availability.available);
            }
        }
    }

    function testFuzz_ChangePortion_Success(uint256 newPortion) public {
        uint256 currentPortion = faucet.portion();
        vm.assume(newPortion != currentPortion);

        faucet.changePortion(newPortion);

        assertEq(faucet.portion(), newPortion);
    }

    function testFuzz_ChangePortion_RevertSameValue(uint256 samePortion) public {
        uint256 initialPortion = faucet.portion();
        vm.assume(samePortion != initialPortion);
        
        faucet.changePortion(samePortion);

        vm.expectRevert(Faucet.SamePortionValue.selector);
        faucet.changePortion(samePortion);
    }

    function testFuzz_Withdraw_Success(uint256 contractBalance) public {
        vm.assume(contractBalance > 0 && contractBalance <= type(uint128).max);
        vm.deal(address(faucet), contractBalance);

        uint256 ownerBalanceBefore = owner.balance;

        faucet.withdraw();

        assertEq(address(faucet).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + contractBalance);
    }

    function testFuzz_Withdraw_RevertEmptyBalance() public {
        assertEq(address(faucet).balance, 0);

        vm.expectRevert(Faucet.NothingToWithdraw.selector);
        faucet.withdraw();
    }

    function testFuzz_OnlyOwner_AccessControl(address nonOwner, uint256 newPortion) public {
        vm.assume(nonOwner != owner && nonOwner != address(0));

        // Test changePortion access control
        vm.prank(nonOwner);
        vm.expectRevert();
        faucet.changePortion(newPortion);

        // Test withdraw access control
        vm.prank(nonOwner);
        vm.expectRevert();
        faucet.withdraw();
    }

    /// @dev Allows contract to receive ETH for testing
    receive() external payable { }
}
