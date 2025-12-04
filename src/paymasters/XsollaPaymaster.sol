// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { IEntryPoint } from "account-abstraction/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "account-abstraction/interfaces/PackedUserOperation.sol";
import { BasePaymaster } from "account-abstraction/core/BasePaymaster.sol";
import { IPaymaster } from "account-abstraction/interfaces/IPaymaster.sol";

import { MSAFactory } from "../../MSAFactory.sol";

/// @title XsollaPaymaster
/// @author Oleg Bedrin <o.bedrin@xsolla.com> - Xsolla ZK
/// @notice A paymaster that sponsors gas fees for smart accounts created through MSAFactory
/// @dev This paymaster only serves accounts that are registered in the MSAFactory
contract XsollaPaymaster is BasePaymaster {
    /// @notice The MSAFactory contract that creates the smart accounts we sponsor
    MSAFactory public immutable msaFactory;

    /// @notice Maximum gas cost that this paymaster will sponsor per user operation
    uint256 public maxCostPerUserOp;

    /// @notice Mapping to track per-account spending limits
    mapping(address account => uint256 totalSpent) public accountSpending;

    /// @notice Maximum amount this paymaster will spend per account
    uint256 public maxSpendingPerAccount;

    /// @notice Whether the paymaster is currently active and accepting operations
    bool public paymasterActive;

    /// @notice Emitted when a user operation is sponsored
    /// @param account The smart account that was sponsored
    /// @param actualGasCost The actual gas cost paid by the paymaster
    event UserOpSponsored(address indexed account, uint256 actualGasCost);

    /// @notice Emitted when the paymaster configuration is updated
    event PaymasterConfigUpdated(uint256 maxCostPerUserOp, uint256 maxSpendingPerAccount, bool paymasterActive);

    /// @notice Emitted when account spending is reset
    event AccountSpendingReset(address indexed account);

    error PaymasterInactive();
    error InvalidAccount();
    error ExceedsMaxCost(uint256 requestedCost, uint256 maxAllowed);
    error ExceedsAccountSpendingLimit(address account, uint256 currentSpending, uint256 additionalCost, uint256 limit);
    error InsufficientDeposit(uint256 required, uint256 available);
    error NotBeaconProxy(address account);
    error InvalidPaymasterData(uint256 actualLength, uint256 expectedMinLength);

    /// @notice Initialize the XsollaPaymaster
    /// @param _entryPoint The EntryPoint contract (v0.8)
    /// @param _msaFactory The MSAFactory contract that creates accounts we sponsor
    /// @param _maxCostPerUserOp Maximum gas cost per user operation
    /// @param _maxSpendingPerAccount Maximum total spending per account
    constructor(
        IEntryPoint _entryPoint,
        MSAFactory _msaFactory,
        uint256 _maxCostPerUserOp,
        uint256 _maxSpendingPerAccount
    ) BasePaymaster(_entryPoint) {
        msaFactory = _msaFactory;
        maxCostPerUserOp = _maxCostPerUserOp;
        maxSpendingPerAccount = _maxSpendingPerAccount;
        paymasterActive = true;
    }

    /// @inheritdoc BasePaymaster
    function _validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
        internal
        view
        override
        returns (bytes memory context, uint256 validationData)
    {
        // Check if paymaster is active
        if (!paymasterActive) {
            revert PaymasterInactive();
        }

        // Check if the cost exceeds our maximum per operation
        if (maxCost > maxCostPerUserOp) {
            revert ExceedsMaxCost(maxCost, maxCostPerUserOp);
        }

        // Extract accountId from paymasterAndData and verify that the sender is an account created by our MSAFactory
        address account = userOp.sender;
        if (!_isValidMSAAccount(account, userOp.paymasterAndData)) {
            revert InvalidAccount();
        }

        // Check if the account would exceed its spending limit
        uint256 currentSpending = accountSpending[account];
        if (currentSpending + maxCost > maxSpendingPerAccount) {
            revert ExceedsAccountSpendingLimit(account, currentSpending, maxCost, maxSpendingPerAccount);
        }

        // Check if we have sufficient deposit to cover the cost
        uint256 currentDeposit = getDeposit();
        if (currentDeposit < maxCost) {
            revert InsufficientDeposit(maxCost, currentDeposit);
        }

        // All validations passed - return context with account address for postOp
        context = abi.encode(account);
        validationData = 0; // Valid indefinitely
    }

    /// @inheritdoc BasePaymaster
    function _postOp(
        IPaymaster.PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) internal override {
        // Only process successful operations and reverted operations (we still pay gas)
        if (mode == IPaymaster.PostOpMode.postOpReverted) {
            return;
        }

        // Decode the account address from context
        address account = abi.decode(context, (address));

        // Update the account's spending
        accountSpending[account] += actualGasCost;

        // Emit event for tracking
        emit UserOpSponsored(account, actualGasCost);
    }

    /// @notice Check if an account was created by our MSAFactory
    /// @param account The account address to check
    /// @param paymasterAndData The paymasterAndData field from PackedUserOperation containing accountId
    /// @return isValid True if the account is a valid MSA account
    function _isValidMSAAccount(address account, bytes calldata paymasterAndData) internal view returns (bool isValid) {
        // Check if the account has code (beacon proxy should have code)
        if (account.code.length == 0) {
            return false;
        }

        // Extract accountId from paymasterAndData
        // paymasterAndData format: [paymaster(20)] + [verificationGasLimit(16)] + [postOpGasLimit(16)] + [accountId(32)]
        // Total expected minimum length: 20 + 16 + 16 + 32 = 84 bytes
        if (paymasterAndData.length < 84) {
            revert InvalidPaymasterData(paymasterAndData.length, 84);
        }

        // Extract accountId from the last 32 bytes
        bytes32 accountId;
        assembly {
            accountId := calldataload(add(paymasterAndData.offset, 52)) // offset 52 = 20 + 16 + 16
        }

        // Check if this accountId maps to the given account address in MSAFactory
        return msaFactory.accountRegistry(accountId) == account;
    }

    /// @notice External function to get beacon address from an account (used for validation)
    /// @param account The account to check
    /// @param paymasterAndData The paymasterAndData containing accountId
    /// @return beacon The beacon address
    function getAccountBeacon(address account, bytes calldata paymasterAndData) external view returns (address beacon) {
        // For beacon proxies, we can't easily read the beacon address
        // since it's stored in an immutable variable and ERC-1967 storage slot
        // Let's return the factory's beacon if the account appears valid
        if (_isValidMSAAccount(account, paymasterAndData)) {
            return msaFactory.beacon();
        } else {
            revert NotBeaconProxy(account);
        }
    }

    /// @notice Update paymaster configuration (only owner)
    /// @param _maxCostPerUserOp New maximum cost per user operation
    /// @param _maxSpendingPerAccount New maximum spending per account
    /// @param _paymasterActive Whether the paymaster should be active
    function updateConfig(uint256 _maxCostPerUserOp, uint256 _maxSpendingPerAccount, bool _paymasterActive)
        external
        onlyOwner
    {
        maxCostPerUserOp = _maxCostPerUserOp;
        maxSpendingPerAccount = _maxSpendingPerAccount;
        paymasterActive = _paymasterActive;

        emit PaymasterConfigUpdated(_maxCostPerUserOp, _maxSpendingPerAccount, _paymasterActive);
    }

    /// @notice Reset spending for a specific account (only owner)
    /// @param account The account to reset spending for
    function resetAccountSpending(address account) external onlyOwner {
        accountSpending[account] = 0;
        emit AccountSpendingReset(account);
    }

    /// @notice Reset spending for multiple accounts (only owner)
    /// @param accounts Array of accounts to reset spending for
    function resetMultipleAccountSpending(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            accountSpending[accounts[i]] = 0;
            emit AccountSpendingReset(accounts[i]);
        }
    }

    /// @notice Check if an account is valid for sponsorship
    /// @param account The account to check
    /// @return isValid True if the account can be sponsored
    /// @dev This function is deprecated, use isValidAccount(address, bytes) instead
    function isValidAccount(address account) external view returns (bool isValid) {
        // Fallback: just check if account has code - not fully secure without accountId
        return account.code.length > 0;
    }

    /// @notice Check if an account is valid for sponsorship
    /// @param account The account to check
    /// @param paymasterAndData The paymasterAndData containing accountId
    /// @return isValid True if the account can be sponsored
    function isValidAccount(address account, bytes calldata paymasterAndData) external view returns (bool isValid) {
        return _isValidMSAAccount(account, paymasterAndData);
    }

    /// @notice Get the remaining spending allowance for an account
    /// @param account The account to check
    /// @return remaining The remaining amount that can be spent for this account
    function getRemainingSpending(address account) external view returns (uint256 remaining) {
        uint256 spent = accountSpending[account];
        if (spent >= maxSpendingPerAccount) {
            return 0;
        }
        return maxSpendingPerAccount - spent;
    }

    /// @notice Emergency pause function (only owner)
    function pause() external onlyOwner {
        paymasterActive = false;
        emit PaymasterConfigUpdated(maxCostPerUserOp, maxSpendingPerAccount, false);
    }

    /// @notice Emergency unpause function (only owner)
    function unpause() external onlyOwner {
        paymasterActive = true;
        emit PaymasterConfigUpdated(maxCostPerUserOp, maxSpendingPerAccount, true);
    }
}
