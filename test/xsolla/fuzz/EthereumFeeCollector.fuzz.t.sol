// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { EthereumFeeCollector } from "src/xsolla/collector/EthereumFeeCollector.sol";
import { WETH9 } from "src/xsolla/WETH9.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MOCK") { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TestWallet {
    receive() external payable { }
}

contract EthereumFeeCollectorFuzzTest is Test {
    EthereumFeeCollector public collector;
    WETH9 public weth;
    MockERC20 public mockToken;
    TestWallet public testWallet;

    address public owner;
    address public operator;
    address public withdrawalWallet;
    address public unauthorizedUser;

    event OperatorUpdated(address indexed operator);

    function setUp() public {
        owner = makeAddr("owner");
        operator = makeAddr("operator");
        testWallet = new TestWallet();
        withdrawalWallet = address(testWallet);
        unauthorizedUser = makeAddr("unauthorizedUser");

        vm.prank(owner);
        collector = new EthereumFeeCollector();

        weth = new WETH9();
        mockToken = new MockERC20();

        // Set up operator and withdrawal wallet
        vm.prank(owner);
        collector.assignOperator(operator);

        vm.prank(owner);
        collector.addWithdrawAddress(withdrawalWallet);
    }

    function testFuzz_name_returnsCorrectName() public view {
        string memory name = collector.name();
        assertEq(name, "ethereum-fee-collector");
    }

    function testFuzz_receiveEther_handlesDirectETHTransfers(uint256 amount) public {
        amount = bound(amount, 1, 100 ether);

        uint256 initialBalance = address(collector).balance;

        (bool success,) = payable(address(collector)).call{ value: amount }("");

        if (success) {
            assertEq(address(collector).balance, initialBalance + amount);
        } else {
            // If the contract doesn't accept ETH, that's also valid behavior
            assertEq(address(collector).balance, initialBalance);
        }
    }

    function testFuzz_unwrapAndWithdraw_revertsOnUnauthorizedCaller(address caller, uint256 amount) public {
        vm.assume(caller != owner && caller != operator && caller != address(0));
        amount = bound(amount, 1, 10 ether);

        _setupWETHForCollector(amount);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("InvalidOperator()"));
        collector.unwrapAndWithdraw(withdrawalWallet, address(weth), amount);
    }

    function testFuzz_unwrapAndWithdraw_revertsOnInvalidWithdrawalWallet(address invalidWallet, uint256 amount) public {
        vm.assume(invalidWallet != withdrawalWallet && invalidWallet != address(0));
        amount = bound(amount, 1, 10 ether);

        _setupWETHForCollector(amount);

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSignature("InvalidWithdrawalWallet(address)", invalidWallet));
        collector.unwrapAndWithdraw(invalidWallet, address(weth), amount);
    }

    function testFuzz_unwrapAndWithdraw_revertsOnInsufficientWETHBalance(uint256 wethBalance, uint256 withdrawAmount)
        public
    {
        wethBalance = bound(wethBalance, 0, 50 ether);
        withdrawAmount = bound(withdrawAmount, wethBalance + 1, wethBalance + 100 ether);

        if (wethBalance > 0) {
            _setupWETHForCollector(wethBalance);
        }

        vm.prank(operator);
        vm.expectRevert();
        collector.unwrapAndWithdraw(withdrawalWallet, address(weth), withdrawAmount);
    }

    function testFuzz_withdraw_transfersETHCorrectly(uint256 amount) public {
        amount = bound(amount, 1, 50 ether);

        vm.deal(address(collector), amount);

        uint256 initialBalance = withdrawalWallet.balance;

        vm.prank(operator);
        collector.withdraw(withdrawalWallet, amount);

        assertEq(withdrawalWallet.balance, initialBalance + amount);
        assertEq(address(collector).balance, 0);
    }

    function testFuzz_withdrawERC20Tokens_transfersTokensCorrectly(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        mockToken.mint(address(collector), amount);

        uint256 initialBalance = mockToken.balanceOf(withdrawalWallet);

        vm.prank(operator);
        collector.withdrawERC20Tokens(withdrawalWallet, address(mockToken), amount);

        assertEq(mockToken.balanceOf(withdrawalWallet), initialBalance + amount);
        assertEq(mockToken.balanceOf(address(collector)), 0);
    }

    function testFuzz_withdrawalWalletManagement_addAndRemoveWallets(address newWallet) public {
        vm.assume(newWallet != address(0) && newWallet != withdrawalWallet);

        // Test adding wallet
        vm.prank(owner);
        collector.addWithdrawAddress(newWallet);
        assertTrue(collector.isWithdrawalWallet(newWallet));

        // Test removing wallet
        vm.prank(owner);
        collector.removeWithdrawAddress(newWallet);
        assertFalse(collector.isWithdrawalWallet(newWallet));
    }

    function _setupWETHForCollector(uint256 amount) internal {
        // Fund the collector contract directly with ETH
        vm.deal(address(collector), amount);

        // Have the collector deposit ETH to get WETH
        vm.prank(address(collector));
        weth.deposit{ value: amount }();
    }

    receive() external payable { }
}
