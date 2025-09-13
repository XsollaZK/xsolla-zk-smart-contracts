// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";

import { ERC1155Modular } from "../../src/product/token/ERC1155/extensions/ERC1155Modular.sol";
import { ERC1155Claimer } from "../../src/product/token/ERC1155/ERC1155Claimer.sol";

contract ERC1155ClaimerFuzzTest is Test {
    ERC1155Modular public token;
    ERC1155Claimer public claimer;
    address public owner;
    address public user;
    
    function setUp() public {
        owner = address(this);
        user = makeAddr("user");
        
        token = new ERC1155Modular();
        token.toggleMinting();
        
        claimer = new ERC1155Claimer(token);
        token.grantRole(token.MINTER_ROLE(), address(claimer));
    }
    
    function testFuzz_setAmountToClaim(uint256 amount) public {
        vm.assume(amount > 0 && amount <= type(uint128).max);
        
        claimer.setAmountToClaim(amount);
        assertEq(claimer.amountToClaim(), amount);
    }
    
    function testFuzz_setTokenIdToClaim(uint256 tokenId) public {
        vm.assume(tokenId <= type(uint128).max);
        
        claimer.setTokenIdToClaim(tokenId);
        assertEq(claimer.tokenIdToClaim(), tokenId);
    }
    
    function testFuzz_claim(address claimant, uint256 amount, uint256 tokenId) public {
        vm.assume(claimant != address(0));
        vm.assume(claimant.code.length == 0); // Only EOAs to avoid ERC1155InvalidReceiver
        vm.assume(amount > 0 && amount <= type(uint64).max);
        vm.assume(tokenId <= type(uint64).max);
        
        // Setup claimer with fuzzed parameters
        claimer.setAmountToClaim(amount);
        claimer.setTokenIdToClaim(tokenId);
        
        uint256 balanceBefore = token.balanceOf(claimant, tokenId);
        
        vm.prank(claimant);
        vm.expectEmit(true, true, true, true);
        emit ERC1155Claimer.Claimed(claimant, tokenId, amount);
        claimer.claim();
        
        uint256 balanceAfter = token.balanceOf(claimant, tokenId);
        assertEq(balanceAfter, balanceBefore + amount);
        assertTrue(claimer.isClaimed(claimant));
    }
    
    function testFuzz_doubleClaim(address claimant) public {
        vm.assume(claimant != address(0));
        vm.assume(claimant.code.length == 0); // Only EOAs to avoid ERC1155InvalidReceiver
        
        // First claim should succeed
        vm.prank(claimant);
        claimer.claim();
        assertTrue(claimer.isClaimed(claimant));
        
        // Second claim should revert
        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Claimer.AlreadyClaimed.selector, claimant));
        claimer.claim();
    }
    
    function testFuzz_multipleUsersClaim(address[] memory claimants, uint256 amount, uint256 tokenId) public {
        vm.assume(claimants.length > 0 && claimants.length <= 50);
        vm.assume(amount > 0 && amount <= type(uint32).max);
        vm.assume(tokenId <= type(uint32).max);
        
        // Filter out zero addresses, contracts, and duplicates
        address[] memory validClaimants = new address[](claimants.length);
        uint256 validCount = 0;
        
        for (uint i = 0; i < claimants.length; i++) {
            if (claimants[i] != address(0) && claimants[i].code.length == 0) {
                bool isDuplicate = false;
                for (uint j = 0; j < validCount; j++) {
                    if (validClaimants[j] == claimants[i]) {
                        isDuplicate = true;
                        break;
                    }
                }
                if (!isDuplicate) {
                    validClaimants[validCount] = claimants[i];
                    validCount++;
                }
            }
        }
        
        vm.assume(validCount > 0);
        
        claimer.setAmountToClaim(amount);
        claimer.setTokenIdToClaim(tokenId);
        
        // Each valid claimant should be able to claim once
        for (uint i = 0; i < validCount; i++) {
            vm.prank(validClaimants[i]);
            claimer.claim();
            
            assertEq(token.balanceOf(validClaimants[i], tokenId), amount);
            assertTrue(claimer.isClaimed(validClaimants[i]));
        }
    }
    
    function testFuzz_unauthorizedClaimerModification(address unauthorized, uint256 amount) public {
        vm.assume(unauthorized != owner);
        vm.assume(unauthorized != address(this));
        vm.assume(amount > 0);
        
        vm.prank(unauthorized);
        vm.expectRevert();
        claimer.setAmountToClaim(amount);
    }
    
    function testFuzz_unauthorizedTokenIdModification(address unauthorized, uint256 tokenId) public {
        vm.assume(unauthorized != owner);
        vm.assume(unauthorized != address(this));
        
        vm.prank(unauthorized);
        vm.expectRevert();
        claimer.setTokenIdToClaim(tokenId);
    }
    
    function testFuzz_claimWithInvalidToken(address claimant) public {
        vm.assume(claimant != address(0));
        vm.assume(claimant.code.length == 0); // Only EOAs to avoid ERC1155InvalidReceiver
        
        // Create a different token that claimer doesn't have minter role for
        ERC1155Modular otherToken = new ERC1155Modular();
        ERC1155Claimer invalidClaimer = new ERC1155Claimer(otherToken);
        
        vm.prank(claimant);
        vm.expectRevert();
        invalidClaimer.claim();
    }
    
    function testFuzz_gasConsumption(uint256 amount, uint256 tokenId) public {
        vm.assume(amount > 0 && amount <= type(uint32).max);
        vm.assume(tokenId <= type(uint32).max);
        
        claimer.setAmountToClaim(amount);
        claimer.setTokenIdToClaim(tokenId);
        
        uint256 gasBefore = gasleft();
        vm.prank(user);
        claimer.claim();
        uint256 gasUsed = gasBefore - gasleft();
        
        // Verify gas usage is reasonable
        assertTrue(gasUsed > 0);
        assertTrue(gasUsed < 200_000); // 200k gas limit for claim
    }
    
    function testFuzz_constructorValues(ERC1155Modular _token) public {
        ERC1155Claimer newClaimer = new ERC1155Claimer(_token);
        
        assertEq(address(newClaimer.tokenToClaim()), address(_token));
        assertEq(newClaimer.tokenIdToClaim(), 0);
        assertEq(newClaimer.amountToClaim(), 100 ether);
        assertEq(newClaimer.owner(), address(this));
    }
    
    function testFuzz_claimStatusTracking(address claimant) public {
        vm.assume(claimant != address(0));
        vm.assume(claimant.code.length == 0); // Only EOAs to avoid ERC1155InvalidReceiver
        
        // Initially not claimed
        assertFalse(claimer.isClaimed(claimant));
        
        // Claim tokens
        vm.prank(claimant);
        claimer.claim();
        
        // Now should be marked as claimed
        assertTrue(claimer.isClaimed(claimant));
    }
    
    function testFuzz_eventEmission(address claimant, uint256 amount, uint256 tokenId) public {
        vm.assume(claimant != address(0));
        vm.assume(claimant.code.length == 0); // Only EOAs to avoid ERC1155InvalidReceiver
        vm.assume(amount > 0 && amount <= type(uint64).max);
        vm.assume(tokenId <= type(uint64).max);
        
        claimer.setAmountToClaim(amount);
        claimer.setTokenIdToClaim(tokenId);
        
        vm.prank(claimant);
        vm.recordLogs();
        claimer.claim();
        
        // Verify the event was emitted by checking logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool foundEvent = false;
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Claimed(address,uint256,uint256)")) {
                foundEvent = true;
                break;
            }
        }
        assertTrue(foundEvent, "Claimed event not found");
    }
}
