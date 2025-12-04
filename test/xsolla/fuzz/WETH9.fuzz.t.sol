// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";

import { WETH9 } from "src/xsolla/WETH9.sol";

contract WETH9FuzzTest is Test {
    WETH9 public weth;

    function setUp() public {
        weth = new WETH9();
    }

    function testFuzz_Deposit(uint256 amount) public {
        vm.assume(amount > 0 && amount <= type(uint128).max);
        vm.deal(address(this), amount);

        uint256 balanceBefore = weth.balanceOf(address(this));

        weth.deposit{ value: amount }();

        assertEq(weth.balanceOf(address(this)), balanceBefore + amount);
        assertEq(address(weth).balance, amount);
    }

    function testFuzz_Withdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        vm.assume(depositAmount > 0 && depositAmount <= type(uint128).max);
        vm.assume(withdrawAmount > 0 && withdrawAmount <= depositAmount);
        vm.deal(address(this), depositAmount);

        weth.deposit{ value: depositAmount }();
        uint256 ethBalanceBefore = address(this).balance;

        weth.withdraw(withdrawAmount);

        assertEq(weth.balanceOf(address(this)), depositAmount - withdrawAmount);
        assertEq(address(this).balance, ethBalanceBefore + withdrawAmount);
    }

    function testFuzz_Transfer(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != address(this));
        vm.assume(amount > 0 && amount <= type(uint128).max);
        vm.deal(address(this), amount);

        weth.deposit{ value: amount }();

        bool success = weth.transfer(to, amount);

        assertTrue(success);
        assertEq(weth.balanceOf(address(this)), 0);
        assertEq(weth.balanceOf(to), amount);
    }

    function testFuzz_Approve(address spender, uint256 amount) public {
        vm.assume(spender != address(0));

        bool success = weth.approve(spender, amount);

        assertTrue(success);
        assertEq(weth.allowance(address(this), spender), amount);
    }

    function testFuzz_TransferFrom(address from, address to, uint256 amount) public {
        vm.assume(from != address(0) && to != address(0) && from != to);
        vm.assume(to != address(weth) && from != address(weth));
        vm.assume(amount > 0 && amount <= type(uint128).max);
        vm.deal(from, amount);

        vm.prank(from);
        weth.deposit{ value: amount }();

        vm.prank(from);
        weth.approve(address(this), amount);

        bool success = weth.transferFrom(from, to, amount);

        assertTrue(success);
        assertEq(weth.balanceOf(from), 0);
        assertEq(weth.balanceOf(to), amount);
        assertEq(weth.allowance(from, address(this)), 0);
    }

    function testFuzz_WithdrawRevert(uint256 depositAmount, uint256 withdrawAmount) public {
        vm.assume(depositAmount > 0 && depositAmount <= type(uint128).max);
        vm.assume(withdrawAmount > depositAmount);
        vm.deal(address(this), depositAmount);

        weth.deposit{ value: depositAmount }();

        vm.expectRevert();
        weth.withdraw(withdrawAmount);
    }

    function testFuzz_TransferRevert(address to, uint256 depositAmount, uint256 transferAmount) public {
        vm.assume(to != address(0));
        vm.assume(depositAmount > 0 && depositAmount <= type(uint128).max);
        vm.assume(transferAmount > depositAmount);
        vm.deal(address(this), depositAmount);

        weth.deposit{ value: depositAmount }();

        vm.expectRevert();
        weth.transfer(to, transferAmount);
    }

    receive() external payable { }
}
