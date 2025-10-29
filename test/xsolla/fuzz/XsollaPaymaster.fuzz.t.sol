// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { PackedUserOperation } from "account-abstraction/interfaces/PackedUserOperation.sol";
import { IEntryPoint } from "account-abstraction/interfaces/IEntryPoint.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { ModularSmartAccount } from "src/ModularSmartAccount.sol";
import { XsollaPaymaster } from "src/xsolla/paymasters/XsollaPaymaster.sol";
import { IMSA } from "src/interfaces/IMSA.sol";

import { MSATest } from "../../MSATest.sol";

contract XsollaPaymasterFuzzTest is MSATest {
    XsollaPaymaster public paymaster;

    // Test constants
    uint256 public constant DEFAULT_MAX_COST_PER_USER_OP = 1e18; // 1 ETH
    uint256 public constant DEFAULT_MAX_SPENDING_PER_ACCOUNT = 10e18; // 10 ETH
    uint256 public constant PAYMASTER_DEPOSIT = 100e18; // 100 ETH

    // Test accounts
    Account public paymasterOwner;
    Account public invalidAccountOwner;
    ModularSmartAccount public validAccount;
    address public invalidAccount;

    event UserOpSponsored(address indexed account, uint256 actualGasCost);
    event PaymasterConfigUpdated(uint256 maxCostPerUserOp, uint256 maxSpendingPerAccount, bool paymasterActive);
    event AccountSpendingReset(address indexed account);

    function setUp() public override {
        super.setUp();

        paymasterOwner = makeAccount("paymasterOwner");
        invalidAccountOwner = makeAccount("invalidAccountOwner");

        // Deploy paymaster
        vm.prank(paymasterOwner.addr);
        paymaster =
            new XsollaPaymaster(entryPoint, factory, DEFAULT_MAX_COST_PER_USER_OP, DEFAULT_MAX_SPENDING_PER_ACCOUNT);

        // Fund the paymaster
        vm.deal(paymasterOwner.addr, PAYMASTER_DEPOSIT * 2);
        vm.prank(paymasterOwner.addr);
        paymaster.deposit{ value: PAYMASTER_DEPOSIT }();

        // Create additional valid account
        validAccount = ModularSmartAccount(payable(createValidAccount("validAccount")));

        // Create invalid account (not from MSAFactory)
        invalidAccount = address(new ModularSmartAccount());
    }

    function createValidAccount(string memory accountName) internal returns (address) {
        Account memory accountOwner = makeAccount(accountName);

        address[] memory modules = new address[](1);
        modules[0] = address(eoaValidator);

        address[] memory owners = new address[](1);
        owners[0] = accountOwner.addr;

        bytes[] memory initData = new bytes[](1);
        initData[0] = abi.encode(owners);

        bytes memory data = abi.encodeCall(IMSA.initializeAccount, (modules, initData));
        address newAccount = factory.deployAccount(keccak256(abi.encode(accountName)), data);

        // Fund the account
        vm.deal(newAccount, 1 ether);

        return newAccount;
    }

    function createUserOpWithCost(address sender, uint256 maxCost) internal view returns (PackedUserOperation memory) {
        return PackedUserOperation({
            sender: sender,
            nonce: entryPoint.getNonce(sender, 0),
            initCode: "",
            callData: abi.encodeCall(ModularSmartAccount.execute, (bytes32(0), "")),
            accountGasLimits: bytes32(abi.encodePacked(uint128(maxCost), uint128(maxCost))),
            preVerificationGas: maxCost,
            gasFees: bytes32(abi.encodePacked(uint128(1), uint128(1))),
            paymasterAndData: abi.encodePacked(address(paymaster)),
            signature: ""
        });
    }

    // Basic setup and configuration tests
    function testFuzz_PaymasterSetup() public view {
        assertEq(address(paymaster.entryPoint()), address(entryPoint));
        assertEq(address(paymaster.msaFactory()), address(factory));
        assertEq(paymaster.maxCostPerUserOp(), DEFAULT_MAX_COST_PER_USER_OP);
        assertEq(paymaster.maxSpendingPerAccount(), DEFAULT_MAX_SPENDING_PER_ACCOUNT);
        assertTrue(paymaster.paymasterActive());
        assertEq(paymaster.owner(), paymasterOwner.addr);
    }

    // Fuzz test for validatePaymasterUserOp with various max costs
    function testFuzz_ValidatePaymasterUserOp_ValidAccount(uint256 maxCost) public {
        vm.assume(maxCost > 0 && maxCost <= DEFAULT_MAX_COST_PER_USER_OP);
        vm.assume(maxCost <= PAYMASTER_DEPOSIT);

        // Use the account from MSATest setup which is known to be valid
        PackedUserOperation memory userOp = createUserOpWithCost(address(account), maxCost);
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        // Call from EntryPoint to avoid "Sender not EntryPoint" error
        vm.prank(address(entryPoint));
        (bytes memory context, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, userOpHash, maxCost);

        assertEq(validationData, 0, "Should be valid");
        assertEq(abi.decode(context, (address)), address(account), "Context should contain account address");
    }

    function testFuzz_ValidatePaymasterUserOp_ExceedsMaxCost(uint256 maxCost) public {
        vm.assume(maxCost > DEFAULT_MAX_COST_PER_USER_OP);
        vm.assume(maxCost <= type(uint128).max); // Avoid overflow in PackedUserOperation

        PackedUserOperation memory userOp = createUserOpWithCost(address(validAccount), maxCost);
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        vm.prank(address(entryPoint));
        vm.expectRevert(
            abi.encodeWithSelector(XsollaPaymaster.ExceedsMaxCost.selector, maxCost, DEFAULT_MAX_COST_PER_USER_OP)
        );
        paymaster.validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }

    function testFuzz_ValidatePaymasterUserOp_InvalidAccount(uint256 maxCost) public {
        vm.assume(maxCost > 0 && maxCost <= DEFAULT_MAX_COST_PER_USER_OP);

        PackedUserOperation memory userOp = createUserOpWithCost(invalidAccount, maxCost);
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        vm.prank(address(entryPoint));
        vm.expectRevert(XsollaPaymaster.InvalidAccount.selector);
        paymaster.validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }

    function testFuzz_ValidatePaymasterUserOp_ExceedsAccountSpendingLimit(uint256 previousSpending, uint256 maxCost)
        public
    {
        // Bound values to valid ranges first
        previousSpending = bound(previousSpending, 1, DEFAULT_MAX_SPENDING_PER_ACCOUNT - 2);
        maxCost = bound(maxCost, 1, DEFAULT_MAX_COST_PER_USER_OP);

        // Ensure maxCost doesn't exceed paymaster deposit
        if (maxCost > PAYMASTER_DEPOSIT) {
            maxCost = PAYMASTER_DEPOSIT;
        }

        // Ensure the total would exceed the spending limit but not the max cost limit
        uint256 remainingLimit = DEFAULT_MAX_SPENDING_PER_ACCOUNT - previousSpending;
        if (maxCost <= remainingLimit) {
            // Adjust previousSpending so that previousSpending + maxCost > limit
            previousSpending = DEFAULT_MAX_SPENDING_PER_ACCOUNT - maxCost + 1;
        }

        // Use the account from MSATest setup which is known to be valid
        // Simulate previous spending
        vm.store(
            address(paymaster),
            keccak256(abi.encode(address(account), uint256(3))), // accountSpending mapping slot
            bytes32(previousSpending)
        );

        PackedUserOperation memory userOp = createUserOpWithCost(address(account), maxCost);
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        vm.prank(address(entryPoint));
        vm.expectRevert(
            abi.encodeWithSelector(
                XsollaPaymaster.ExceedsAccountSpendingLimit.selector,
                address(account),
                previousSpending,
                maxCost,
                DEFAULT_MAX_SPENDING_PER_ACCOUNT
            )
        );
        paymaster.validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }

    function testFuzz_ValidatePaymasterUserOp_InsufficientDeposit(uint256 depositAmount, uint256 maxCost) public {
        vm.assume(depositAmount < maxCost);
        vm.assume(maxCost > 0 && maxCost <= DEFAULT_MAX_COST_PER_USER_OP);
        vm.assume(depositAmount <= PAYMASTER_DEPOSIT);

        // Withdraw some deposit to simulate insufficient funds
        uint256 withdrawAmount = PAYMASTER_DEPOSIT - depositAmount;
        vm.prank(paymasterOwner.addr);
        paymaster.withdrawTo(payable(paymasterOwner.addr), withdrawAmount);

        // Use the account from MSATest setup which is known to be valid
        PackedUserOperation memory userOp = createUserOpWithCost(address(account), maxCost);
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        vm.prank(address(entryPoint));
        vm.expectRevert(abi.encodeWithSelector(XsollaPaymaster.InsufficientDeposit.selector, maxCost, depositAmount));
        paymaster.validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }

    function testFuzz_ValidatePaymasterUserOp_PaymasterInactive() public {
        // Deactivate paymaster
        vm.prank(paymasterOwner.addr);
        paymaster.pause();

        PackedUserOperation memory userOp = createUserOpWithCost(address(validAccount), 1000);
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        vm.prank(address(entryPoint));
        vm.expectRevert(XsollaPaymaster.PaymasterInactive.selector);
        paymaster.validatePaymasterUserOp(userOp, userOpHash, 1000);
    }

    function testFuzz_UpdateConfig(
        uint256 newMaxCostPerUserOp,
        uint256 newMaxSpendingPerAccount,
        bool newPaymasterActive
    ) public {
        vm.assume(newMaxCostPerUserOp > 0 && newMaxCostPerUserOp <= type(uint128).max);
        vm.assume(newMaxSpendingPerAccount > 0 && newMaxSpendingPerAccount <= type(uint128).max);

        vm.prank(paymasterOwner.addr);
        vm.expectEmit(true, true, true, true);
        emit PaymasterConfigUpdated(newMaxCostPerUserOp, newMaxSpendingPerAccount, newPaymasterActive);

        paymaster.updateConfig(newMaxCostPerUserOp, newMaxSpendingPerAccount, newPaymasterActive);

        assertEq(paymaster.maxCostPerUserOp(), newMaxCostPerUserOp);
        assertEq(paymaster.maxSpendingPerAccount(), newMaxSpendingPerAccount);
        assertEq(paymaster.paymasterActive(), newPaymasterActive);
    }

    function testFuzz_ResetAccountSpending(uint256 currentSpending) public {
        vm.assume(currentSpending > 0 && currentSpending <= DEFAULT_MAX_SPENDING_PER_ACCOUNT);

        // Set some spending
        vm.store(address(paymaster), keccak256(abi.encode(address(validAccount), uint256(3))), bytes32(currentSpending));

        assertEq(paymaster.accountSpending(address(validAccount)), currentSpending);

        vm.prank(paymasterOwner.addr);
        vm.expectEmit(true, true, true, true);
        emit AccountSpendingReset(address(validAccount));

        paymaster.resetAccountSpending(address(validAccount));

        assertEq(paymaster.accountSpending(address(validAccount)), 0);
    }

    function testFuzz_ResetMultipleAccountSpending(uint8 numAccounts) public {
        vm.assume(numAccounts > 0 && numAccounts <= 10); // Reasonable limit for fuzz testing

        address[] memory accounts = new address[](numAccounts);

        // Create accounts and set spending
        for (uint256 i = 0; i < numAccounts; i++) {
            accounts[i] = createValidAccount(string(abi.encodePacked("account", i)));

            // Set some spending for each account
            vm.store(address(paymaster), keccak256(abi.encode(accounts[i], uint256(3))), bytes32(1000 * (i + 1)));
        }

        vm.prank(paymasterOwner.addr);
        paymaster.resetMultipleAccountSpending(accounts);

        // Verify all accounts have zero spending
        for (uint256 i = 0; i < numAccounts; i++) {
            assertEq(paymaster.accountSpending(accounts[i]), 0);
        }
    }

    function testFuzz_GetRemainingSpending(uint256 currentSpending) public {
        vm.assume(currentSpending <= DEFAULT_MAX_SPENDING_PER_ACCOUNT);

        // Set current spending
        vm.store(address(paymaster), keccak256(abi.encode(address(validAccount), uint256(3))), bytes32(currentSpending));

        uint256 expectedRemaining =
            currentSpending >= DEFAULT_MAX_SPENDING_PER_ACCOUNT ? 0 : DEFAULT_MAX_SPENDING_PER_ACCOUNT - currentSpending;

        assertEq(paymaster.getRemainingSpending(address(validAccount)), expectedRemaining);
    }

    function testFuzz_IsValidAccount_ValidAccount() public view {
        assertTrue(paymaster.isValidAccount(address(account)));
        // Note: validAccount might not be properly initialized as a beacon proxy
        // so we test with the main account from MSATest setup
    }

    function testFuzz_IsValidAccount_InvalidAccount() public view {
        assertFalse(paymaster.isValidAccount(invalidAccount));
        assertFalse(paymaster.isValidAccount(address(0)));
    }

    function testFuzz_GetAccountBeacon_ValidAccount() public view {
        address beacon = paymaster.getAccountBeacon(address(account));
        assertEq(beacon, factory.beacon());
        // Note: validAccount might not be properly initialized as a beacon proxy
        // so we test with the main account from MSATest setup
    }

    function testFuzz_GetAccountBeacon_InvalidAccount() public {
        vm.expectRevert(abi.encodeWithSelector(XsollaPaymaster.NotBeaconProxy.selector, invalidAccount));
        paymaster.getAccountBeacon(invalidAccount);
    }

    // Edge case: Test with zero values
    function testFuzz_EdgeCase_ZeroValues() public {
        vm.prank(paymasterOwner.addr);
        paymaster.updateConfig(0, 0, false);

        assertEq(paymaster.maxCostPerUserOp(), 0);
        assertEq(paymaster.maxSpendingPerAccount(), 0);
        assertFalse(paymaster.paymasterActive());
    }

    // Edge case: Test with maximum values
    function testFuzz_EdgeCase_MaxValues() public {
        uint256 maxUint256 = type(uint256).max;

        vm.prank(paymasterOwner.addr);
        paymaster.updateConfig(maxUint256, maxUint256, true);

        assertEq(paymaster.maxCostPerUserOp(), maxUint256);
        assertEq(paymaster.maxSpendingPerAccount(), maxUint256);
        assertTrue(paymaster.paymasterActive());
    }

    // Test pause/unpause functionality
    function testFuzz_PauseUnpause() public {
        // Test pause
        vm.prank(paymasterOwner.addr);
        vm.expectEmit(true, true, true, true);
        emit PaymasterConfigUpdated(DEFAULT_MAX_COST_PER_USER_OP, DEFAULT_MAX_SPENDING_PER_ACCOUNT, false);

        paymaster.pause();
        assertFalse(paymaster.paymasterActive());

        // Test unpause
        vm.prank(paymasterOwner.addr);
        vm.expectEmit(true, true, true, true);
        emit PaymasterConfigUpdated(DEFAULT_MAX_COST_PER_USER_OP, DEFAULT_MAX_SPENDING_PER_ACCOUNT, true);

        paymaster.unpause();
        assertTrue(paymaster.paymasterActive());
    }

    // Test unauthorized access
    function testFuzz_Unauthorized_UpdateConfig(address unauthorized) public {
        vm.assume(unauthorized != paymasterOwner.addr);
        vm.assume(unauthorized != address(0));

        vm.prank(unauthorized);
        vm.expectRevert(); // Just expect any revert for ownership check
        paymaster.updateConfig(1000, 1000, true);
    }

    function testFuzz_Unauthorized_ResetAccountSpending(address unauthorized) public {
        vm.assume(unauthorized != paymasterOwner.addr);
        vm.assume(unauthorized != address(0));

        vm.prank(unauthorized);
        vm.expectRevert(); // Just expect any revert for ownership check
        paymaster.resetAccountSpending(address(validAccount));
    }

    function testFuzz_Unauthorized_Pause(address unauthorized) public {
        vm.assume(unauthorized != paymasterOwner.addr);
        vm.assume(unauthorized != address(0));

        vm.prank(unauthorized);
        vm.expectRevert(); // Just expect any revert for ownership check
        paymaster.pause();
    }

    function testFuzz_Unauthorized_Unpause(address unauthorized) public {
        vm.assume(unauthorized != paymasterOwner.addr);
        vm.assume(unauthorized != address(0));

        vm.prank(unauthorized);
        vm.expectRevert(); // Just expect any revert for ownership check
        paymaster.unpause();
    }
}
