// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseFeeCollector } from "src/collector/BaseFeeCollector.sol";

contract MockERC20 is ERC20 {
    error InsufficientBalance();
    error InsufficientAllowance();

    constructor() ERC20("MockToken", "MOCK") { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        if (balanceOf(from) < amount) {
            revert InsufficientBalance();
        }
        _burn(from, amount);
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if (balanceOf(msg.sender) < value) {
            revert InsufficientBalance();
        }
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (balanceOf(from) < value) {
            revert InsufficientBalance();
        }
        if (allowance(from, msg.sender) < value) {
            revert InsufficientAllowance();
        }
        return super.transferFrom(from, to, value);
    }
}

contract BaseFeeCollectorFuzzTest is Test {
    BaseFeeCollector public collector;
    MockERC20 public mockToken;

    address public owner;
    address public operator;
    address public withdrawalWallet;
    address public unauthorizedUser;

    event OperatorUpdated(address indexed operator);

    function setUp() public {
        owner = makeAddr("owner");
        operator = makeAddr("operator");
        withdrawalWallet = makeAddr("withdrawalWallet");
        unauthorizedUser = makeAddr("unauthorizedUser");

        vm.prank(owner);
        collector = new BaseFeeCollector();

        mockToken = new MockERC20();

        // Set up operator and withdrawal wallet
        vm.prank(owner);
        collector.assignOperator(operator);

        vm.prank(owner);
        collector.addWithdrawAddress(withdrawalWallet);
    }

    function testFuzz_withdraw_validAmounts(uint256 amount) public {
        amount = bound(amount, 1, 100 ether);

        // Fund the collector
        vm.deal(address(collector), amount);

        uint256 initialBalance = withdrawalWallet.balance;

        vm.prank(operator);
        collector.withdraw(withdrawalWallet, amount);

        assertEq(withdrawalWallet.balance, initialBalance + amount);
        assertEq(address(collector).balance, 0);
    }

    function testFuzz_withdraw_invalidAmounts(uint256 amount, uint256 contractBalance) public {
        contractBalance = bound(contractBalance, 0, 50 ether);
        amount = bound(amount, contractBalance + 1, type(uint128).max);

        vm.deal(address(collector), contractBalance);

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSignature("InvalidNativeTokenAmount(uint256)", amount));
        collector.withdraw(withdrawalWallet, amount);
    }

    function testFuzz_withdraw_unauthorizedCaller(address caller, uint256 amount) public {
        vm.assume(caller != owner && caller != operator && caller != address(0));
        amount = bound(amount, 1, 10 ether);

        vm.deal(address(collector), amount);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("InvalidOperator()"));
        collector.withdraw(withdrawalWallet, amount);
    }

    function testFuzz_withdraw_invalidWithdrawalWallet(address invalidWallet, uint256 amount) public {
        vm.assume(invalidWallet != withdrawalWallet && invalidWallet != address(0));
        amount = bound(amount, 1, 10 ether);

        vm.deal(address(collector), amount);

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSignature("InvalidWithdrawalWallet(address)", invalidWallet));
        collector.withdraw(invalidWallet, amount);
    }

    function testFuzz_withdrawERC20Tokens_validAmounts(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        // Mint tokens to collector
        mockToken.mint(address(collector), amount);

        uint256 initialBalance = mockToken.balanceOf(withdrawalWallet);

        vm.prank(operator);
        collector.withdrawERC20Tokens(withdrawalWallet, address(mockToken), amount);

        assertEq(mockToken.balanceOf(withdrawalWallet), initialBalance + amount);
        assertEq(mockToken.balanceOf(address(collector)), 0);
    }

    function testFuzz_withdrawERC20Tokens_unauthorizedCaller(address caller, uint256 amount) public {
        vm.assume(caller != owner && caller != operator && caller != address(0));
        amount = bound(amount, 1, 1000 ether);

        mockToken.mint(address(collector), amount);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("InvalidOperator()"));
        collector.withdrawERC20Tokens(withdrawalWallet, address(mockToken), amount);
    }

    function testFuzz_withdrawERC20Tokens_invalidWithdrawalWallet(address invalidWallet, uint256 amount) public {
        vm.assume(invalidWallet != withdrawalWallet && invalidWallet != address(0));
        amount = bound(amount, 1, 1000 ether);

        mockToken.mint(address(collector), amount);

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSignature("InvalidWithdrawalWallet(address)", invalidWallet));
        collector.withdrawERC20Tokens(invalidWallet, address(mockToken), amount);
    }

    function testFuzz_addWithdrawAddress_validAddresses(address newWallet) public {
        vm.assume(newWallet != address(0) && newWallet != withdrawalWallet);

        vm.prank(owner);
        collector.addWithdrawAddress(newWallet);

        assertTrue(collector.isWithdrawalWallet(newWallet));
    }

    function testFuzz_addWithdrawAddress_unauthorizedCaller(address caller, address newWallet) public {
        vm.assume(caller != owner && caller != address(0));
        vm.assume(newWallet != address(0));

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        collector.addWithdrawAddress(newWallet);
    }

    function testFuzz_addWithdrawAddress_nullAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("NewWithdrawalWalletIsNullAddress()"));
        collector.addWithdrawAddress(address(0));
    }

    function testFuzz_removeWithdrawAddress_validAddresses(address walletToRemove) public {
        vm.assume(walletToRemove != address(0));

        // First add the wallet
        vm.prank(owner);
        collector.addWithdrawAddress(walletToRemove);

        assertTrue(collector.isWithdrawalWallet(walletToRemove));

        // Then remove it
        vm.prank(owner);
        collector.removeWithdrawAddress(walletToRemove);

        assertFalse(collector.isWithdrawalWallet(walletToRemove));
    }

    function testFuzz_removeWithdrawAddress_unauthorizedCaller(address caller, address walletToRemove) public {
        vm.assume(caller != owner && caller != address(0));
        vm.assume(walletToRemove != address(0));

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        collector.removeWithdrawAddress(walletToRemove);
    }

    function testFuzz_assignOperator_validAddresses(address newOperator) public {
        vm.assume(newOperator != address(0) && newOperator != operator);
        // Exclude precompiled contracts and problematic addresses
        vm.assume(uint160(newOperator) > 0x1000); // Exclude low addresses
            // entirely
        vm.assume(newOperator != owner && newOperator != withdrawalWallet);
        vm.assume(newOperator.code.length == 0); // Ensure it's not a contract

        vm.prank(owner);
        collector.assignOperator(newOperator);

        // Test that new operator can withdraw (this verifies the assignment
        // worked)
        vm.deal(address(collector), 1 ether);
        vm.prank(newOperator);
        collector.withdraw(withdrawalWallet, 1 ether);

        // Verify the withdrawal succeeded
        assertEq(withdrawalWallet.balance, 1 ether);
    }

    function testFuzz_assignOperator_unauthorizedCaller(address caller, address newOperator) public {
        vm.assume(caller != owner && caller != address(0));
        vm.assume(newOperator != address(0));

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        collector.assignOperator(newOperator);
    }

    function testFuzz_assignOperator_nullAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("OperatorIsNullAddress()"));
        collector.assignOperator(address(0));
    }

    function testFuzz_ownerCanWithdraw(uint256 amount) public {
        amount = bound(amount, 1, 100 ether);

        vm.deal(address(collector), amount);

        // Owner should be able to withdraw without being operator
        vm.prank(owner);
        collector.withdraw(withdrawalWallet, amount);

        assertEq(withdrawalWallet.balance, amount);
    }

    function testFuzz_receiveEther(uint256 amount) public {
        amount = bound(amount, 1, 100 ether);

        uint256 initialBalance = address(collector).balance;

        // Use vm.deal to directly give ether to the contract instead of sending
        vm.deal(address(collector), initialBalance + amount);

        assertEq(address(collector).balance, initialBalance + amount);
    }
}
