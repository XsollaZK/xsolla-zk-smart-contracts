// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";

import { ERC721Claimer } from "src/xsolla/token/ERC721/ERC721Claimer.sol";
import { ERC721Modular } from "src/xsolla/token/ERC721/extensions/ERC721Modular.sol";

contract ERC721ClaimerFuzzTest is Test {
    ERC721Claimer public claimer;
    ERC721Modular public token;
    address public user = makeAddr("user");
    address public admin = makeAddr("admin");

    function setUp() public {
        token = new ERC721Modular("Test NFT", "TEST", 10_000);
        claimer = new ERC721Claimer(token);

        token.grantRole(token.MINTER_ROLE(), address(claimer));
        token.toggleMinting();
    }

    function testFuzz_ClaimTokens(address claimant, uint256 amount) public {
        vm.assume(claimant != address(0));
        vm.assume(claimant.code.length == 0);
        vm.assume(amount > 0 && amount <= 50);
        vm.assume(amount <= token.maxSupply() - token.totalSupply());

        claimer.setAmountToClaim(amount);

        uint256 initialBalance = token.balanceOf(claimant);
        uint256 initialSupply = token.totalSupply();

        vm.prank(claimant);
        claimer.claim();

        assertEq(token.balanceOf(claimant), initialBalance + amount);
        assertEq(token.totalSupply(), initialSupply + amount);
        assertTrue(claimer.isClaimed(claimant));
    }

    function testFuzz_SetAmountToClaim(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 100);
        vm.assume(amount <= token.maxSupply());

        claimer.setAmountToClaim(amount);
        assertEq(claimer.amountToClaim(), amount);

        vm.prank(user);
        claimer.claim();

        assertEq(token.balanceOf(user), amount);
    }

    function testFuzz_CannotClaimTwice(address claimant, uint256 amount) public {
        vm.assume(claimant != address(0));
        vm.assume(claimant.code.length == 0);
        vm.assume(amount > 0 && amount <= 50);
        vm.assume(amount * 2 <= token.maxSupply());

        claimer.setAmountToClaim(amount);

        // First claim should succeed
        vm.prank(claimant);
        claimer.claim();

        assertEq(token.balanceOf(claimant), amount);
        assertTrue(claimer.isClaimed(claimant));

        // Second claim should fail
        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(ERC721Claimer.AlreadyClaimed.selector, claimant));
        claimer.claim();

        // Balance should remain the same
        assertEq(token.balanceOf(claimant), amount);
    }

    function testFuzz_ClaimWithDifferentAmounts(address[5] memory claimants, uint256[5] memory amounts) public {
        uint256 totalAmount = 0;
        uint256 validClaimants = 0;

        // Validate inputs and calculate totals
        for (uint256 i = 0; i < 5; i++) {
            if (claimants[i] != address(0) && claimants[i].code.length == 0 && amounts[i] > 0 && amounts[i] <= 20) {
                totalAmount += amounts[i];
                validClaimants++;
            }
        }

        vm.assume(totalAmount <= token.maxSupply());
        vm.assume(validClaimants > 0);

        // Process claims
        for (uint256 i = 0; i < 5; i++) {
            if (claimants[i] != address(0) && claimants[i].code.length == 0 && amounts[i] > 0 && amounts[i] <= 20) {
                claimer.setAmountToClaim(amounts[i]);

                vm.prank(claimants[i]);
                claimer.claim();

                assertEq(token.balanceOf(claimants[i]), amounts[i]);
                assertTrue(claimer.isClaimed(claimants[i]));
            }
        }
    }

    function testFuzz_ClaimWithMaxSupplyLimit(uint256 maxSupply, uint256 claimAmount, uint256 claimers) public {
        // Use modulo to ensure valid ranges and relationships
        maxSupply = bound(maxSupply, 10, 100);
        claimAmount = bound(claimAmount, 1, maxSupply / 2);
        claimers = bound(claimers, 1, maxSupply / claimAmount);

        // Create new token with limited supply
        ERC721Modular limitedToken = new ERC721Modular("Limited", "LTD", maxSupply);
        ERC721Claimer limitedClaimer = new ERC721Claimer(limitedToken);

        limitedToken.grantRole(limitedToken.MINTER_ROLE(), address(limitedClaimer));
        limitedToken.toggleMinting();
        limitedClaimer.setAmountToClaim(claimAmount);

        // Create multiple claimers
        for (uint256 i = 0; i < claimers; i++) {
            address claimant = makeAddr(string(abi.encodePacked("claimant", vm.toString(i))));

            vm.prank(claimant);
            limitedClaimer.claim();

            assertEq(limitedToken.balanceOf(claimant), claimAmount);
            assertTrue(limitedClaimer.isClaimed(claimant));
        }

        assertEq(limitedToken.totalSupply(), claimAmount * claimers);
        assertTrue(limitedToken.totalSupply() <= maxSupply);
    }

    function testFuzz_ClaimWhenClaimingDisabled(address claimant) public {
        vm.assume(claimant != address(0));
        vm.assume(claimant.code.length == 0);

        // Disable minting on the token
        token.toggleMinting();

        vm.prank(claimant);
        vm.expectRevert();
        claimer.claim();

        assertFalse(claimer.isClaimed(claimant));
    }

    function testFuzz_TransferOwnership(address newOwner) public {
        vm.assume(newOwner != address(0));
        vm.assume(newOwner != address(this));
        vm.assume(newOwner.code.length == 0);

        claimer.transferOwnership(newOwner);
        assertEq(claimer.owner(), newOwner);

        // Only new owner can set claim amount
        vm.prank(newOwner);
        claimer.setAmountToClaim(5);
        assertEq(claimer.amountToClaim(), 5);

        vm.prank(user);
        claimer.claim();
        assertEq(token.balanceOf(user), 5);
    }

    function testFuzz_ClaimWithRandomAddresses(address[10] memory claimants) public {
        uint256 validClaimants = 0;

        // Count valid claimants first
        for (uint256 i = 0; i < 10; i++) {
            if (claimants[i] != address(0) && claimants[i].code.length == 0) {
                // Check for duplicates
                bool isDuplicate = false;
                for (uint256 j = 0; j < i; j++) {
                    if (claimants[i] == claimants[j]) {
                        isDuplicate = true;
                        break;
                    }
                }
                if (!isDuplicate) {
                    validClaimants++;
                }
            }
        }

        vm.assume(validClaimants <= token.maxSupply());

        uint256 actualClaimants = 0;
        for (uint256 i = 0; i < 10; i++) {
            if (claimants[i] != address(0) && claimants[i].code.length == 0 && !claimer.isClaimed(claimants[i])) {
                vm.prank(claimants[i]);
                claimer.claim();

                assertEq(token.balanceOf(claimants[i]), 1);
                assertTrue(claimer.isClaimed(claimants[i]));
                actualClaimants++;
            }
        }

        assertEq(token.totalSupply(), actualClaimants);
    }

    function testFuzz_OnlyOwnerCanSetAmount(address notOwner, uint256 amount) public {
        vm.assume(notOwner != address(this));
        vm.assume(notOwner != address(0));
        vm.assume(amount > 0 && amount <= 100);

        vm.prank(notOwner);
        vm.expectRevert();
        claimer.setAmountToClaim(amount);
    }

    function testFuzz_CannotSetZeroAmount() public {
        vm.expectRevert(ERC721Claimer.InvalidClaimAmount.selector);
        claimer.setAmountToClaim(0);
    }

    function testFuzz_ClaimEvent(address claimant, uint256 amount) public {
        vm.assume(claimant != address(0));
        vm.assume(claimant.code.length == 0);
        vm.assume(amount > 0 && amount <= 50);
        vm.assume(amount <= token.maxSupply());

        claimer.setAmountToClaim(amount);

        vm.expectEmit(true, true, false, true);
        emit ERC721Claimer.Claimed(claimant, amount);

        vm.prank(claimant);
        claimer.claim();
    }
}
