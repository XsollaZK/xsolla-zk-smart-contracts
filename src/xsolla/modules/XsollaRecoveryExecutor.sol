// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { WebAuthnValidator } from "../../modules/WebAuthnValidator.sol";
import { EOAKeyValidator } from "../../modules/EOAKeyValidator.sol";
import { GuardianExecutor } from "../../modules/GuardianExecutor.sol";
import { ExecutionLib } from "../../libraries/ExecutionLib.sol";
import { IERC7579Account } from "../../interfaces/IERC7579Account.sol";
import { ModeLib } from "../../libraries/ModeLib.sol";

/// @title XsollaRecoveryExecutor
/// @notice GuardianExecutor variant with an implicit, globally trusted Xsolla guardian (no per‑account guardian
/// setup).
/// @dev Disables all mutable guardian management; only a privileged submit / finalize recovery flow is allowed.
/// Recovery lifecycle:
/// 1. initializeRecovery(): stores a pending request if none active (or previous expired).
/// 2. finalizeRecovery(): callable only after REQUEST_DELAY_TIME has strictly passed
///    and strictly before (timestamp + REQUEST_VALIDITY_TIME) expires.
/// 3. discardRecovery()/discardRecoveryFor(): cancels an active request.
/// A recovery is considered active if (timestamp != 0 && data.length != 0).
contract XsollaRecoveryExecutor is GuardianExecutor, AccessControl {
    /// @notice Role allowed to submit (initialize) recovery requests acting as the implicit guardian.
    /// @dev Holders can start or discard recoveries for any account.
    bytes32 public constant SUBMITTER_ROLE = keccak256("SUBMITTER_ROLE");
    /// @notice Role allowed to finalize (execute) a pending recovery after the delay window.
    /// @dev Separation of duties: submitter cannot finalize unless also granted this role.
    bytes32 public constant FINALIZER_ROLE = keccak256("FINALIZER_ROLE");

    /// @notice Thrown when attempting to use disabled guardian management functions.
    /// @custom:error GuardianModificationDisabled All guardian mutation entrypoints revert with this error.
    error GuardianModificationDisabled();

    /// @notice Thrown when trying to discard a recovery that does not exist for the target account.
    /// @param account The account for which no active recovery exists.
    error CannotDiscardRecoveryFor(address account);

    /// @notice Deploys the executor and assigns role addresses.
    /// @param _webAuthValidator Address of the installed WebAuthn (passkey) validator.
    /// @param _eoaValidator Address of the installed EOA key validator.
    /// @param _admin Address granted DEFAULT_ADMIN_ROLE (can grant/revoke other roles).
    /// @param _finalizer Address granted FINALIZER_ROLE (may finalize recoveries).
    /// @param _submitter Address granted SUBMITTER_ROLE (may initialize/discard recoveries).
    constructor(
        address _webAuthValidator,
        address _eoaValidator,
        address _admin,
        address _finalizer,
        address _submitter
    ) GuardianExecutor(_webAuthValidator, _eoaValidator) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(FINALIZER_ROLE, _finalizer);
        _grantRole(SUBMITTER_ROLE, _submitter);
    }

    /// @notice Initializes a recovery request for a smart account (implicit global guardian).
    /// @dev Requirements:
    /// - Corresponding validator for recoveryType must be installed (checkInstalledValidator).
    /// - No active (non‑expired) recovery in progress (else RecoveryInProgress).
    /// Behavior:
    /// - If a previous recovery exists but has expired, it is discarded first.
    /// - Records timestamp = current block time.
    /// @param accountToRecover Smart account to recover.
    /// @param recoveryType Recovery type enum (EOA or Passkey).
    /// @param data ABI‑encoded validator payload (e.g. new key material).
    function initializeRecovery(address accountToRecover, RecoveryType recoveryType, bytes calldata data)
        external
        virtual
        override
        onlyRole(SUBMITTER_ROLE)
    {
        // Implicit guardian path: replicate the base logic without the onlyGuardianOf modifier.
        checkInstalledValidator(accountToRecover, recoveryType);
        uint256 pendingRecoveryTimestamp = pendingRecovery[accountToRecover].timestamp;
        if (pendingRecoveryTimestamp != 0 && pendingRecoveryTimestamp + REQUEST_VALIDITY_TIME >= block.timestamp) {
            revert RecoveryInProgress(accountToRecover);
        } else {
            _discardRecoveryFor(accountToRecover, false);
        }
        RecoveryRequest memory recovery = RecoveryRequest(recoveryType, data, uint48(block.timestamp));
        pendingRecovery[accountToRecover] = recovery;
        emit RecoveryInitiated(accountToRecover, msg.sender, recovery);
    }

    /// @notice Finalizes an initialized recovery after delay and before expiry, executing the validator action.
    /// @dev Requirements:
    /// - Active recovery must exist (else NoRecoveryInProgress).
    /// - Validator for stored recovery type still installed.
    /// - Timing: (timestamp + REQUEST_DELAY_TIME) < block.timestamp (strictly after delay) AND
    ///            block.timestamp < (timestamp + REQUEST_VALIDITY_TIME) (strictly before expiry).
    /// Side effects:
    /// - Deletes pending recovery before external call.
    /// - Executes validator-specific addOwner / addValidationKey via account.
    /// @param account Account whose recovery is being finalized.
    /// @return returnData ABI return data from underlying validator call.
    function finalizeRecovery(address account)
        external
        virtual
        override
        onlyRole(FINALIZER_ROLE)
        returns (bytes memory returnData)
    {
        RecoveryRequest memory recovery = pendingRecovery[account];
        checkInstalledValidator(account, recovery.recoveryType);

        if (recovery.timestamp == 0 || recovery.data.length == 0) {
            revert NoRecoveryInProgress(account);
        }

        if (!(recovery.timestamp + REQUEST_DELAY_TIME < block.timestamp
                    && recovery.timestamp + REQUEST_VALIDITY_TIME > block.timestamp)) {
            revert RecoveryTimestampInvalid(recovery.timestamp);
        }

        // NOTE: the fact that recovery type is not `None` is checked in `checkInstalledValidator`.
        // slither-disable-next-line incorrect-equality
        address validator = recovery.recoveryType == RecoveryType.EOA ? eoaValidator : webAuthValidator;
        // slither-disable-next-line incorrect-equality
        bytes4 selector = recovery.recoveryType == RecoveryType.EOA
            ? EOAKeyValidator.addOwner.selector
            : WebAuthnValidator.addValidationKey.selector;
        bytes memory execution = ExecutionLib.encodeSingle(validator, 0, abi.encodePacked(selector, recovery.data));

        delete pendingRecovery[account];
        returnData = IERC7579Account(account).executeFromExecutor(ModeLib.encodeSimpleSingle(), execution)[0];
        emit RecoveryFinished(account);
    }

    /// @notice Discards caller's own pending recovery request, if any.
    /// @dev Reverts with CannotDiscardRecoveryFor if none is active.
    function discardRecovery() public virtual override {
        _discardRecoveryFor(msg.sender, true);
    }

    /// @notice Discards a pending recovery for a target account (submitter authority).
    /// @dev Reverts with CannotDiscardRecoveryFor if no active recovery for account.
    /// @param account Target account whose recovery is to be discarded.
    function discardRecoveryFor(address account) public virtual onlyRole(SUBMITTER_ROLE) {
        _discardRecoveryFor(account, true);
    }

    // ---------------------------------------------------------------------
    // Disabled guardian management (only implicit xsolla guardian is allowed).
    // ---------------------------------------------------------------------

    /// @inheritdoc GuardianExecutor
    /// @notice Disabled in this implementation; always reverts.
    function proposeGuardian(
        address /* newGuardian*/
    )
        external
        pure
        virtual
        override
    {
        revert GuardianModificationDisabled();
    }

    /// @inheritdoc GuardianExecutor
    /// @notice Disabled in this implementation; always reverts.
    function acceptGuardian(
        address /* accountToGuard*/
    )
        external
        pure
        virtual
        override
        returns (bool)
    {
        revert GuardianModificationDisabled();
    }

    /// @inheritdoc GuardianExecutor
    /// @notice Disabled in this implementation; always reverts.
    function removeGuardian(
        address /* guardianToRemove*/
    )
        external
        pure
        virtual
        override
    {
        revert GuardianModificationDisabled();
    }

    /// @dev Internal helper to discard an existing recovery.
    /// Reverts when no active recovery exists (CannotDiscardRecoveryFor).
    /// @param account Target account whose recovery (if active) is removed.
    function _discardRecoveryFor(address account, bool throws) internal {
        RecoveryRequest memory recovery = pendingRecovery[account];
        if (recovery.timestamp != 0 && recovery.data.length != 0) {
            delete pendingRecovery[account];
            emit RecoveryDiscarded(account);
        } else if (throws) {
            revert CannotDiscardRecoveryFor(account);
        }
    }
}
