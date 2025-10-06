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
/// @notice Extends GuardianExecutor by introducing an implicit global Xsolla guardian that can recover any account
/// without being explicitly registered per account. Guardian management (add / accept / remove) is intentionally
/// disabled; only the implicit guardian is recognized.
/// @dev Submitter role equates to guardian or owner authority in the original flow.
/// Recovery supports EOA key addition and WebAuthn passkey addition through installed validators.
///  Time window calculations can be adjusted via admin-controlled signed offsets for delay and validity.
/// @author Oleg Bedrin - Xsolla Web3 <o.bedrin@xsolla.com>
contract XsollaRecoveryExecutor is GuardianExecutor, AccessControl {
    /// @notice Role allowed to initialize recovery requests.
    bytes32 public constant SUBMITTER_ROLE = keccak256("SUBMITTER_ROLE");
    /// @notice Role allowed to finalize recovery if additional segregation is ever applied (currently unused in logic).
    bytes32 public constant FINALIZER_ROLE = keccak256("FINALIZER_ROLE");

    /// @notice Signed offset (positive or negative) applied to the base REQUEST_DELAY_TIME during validation.
    int256 public requestDelayTimeOffset;
    /// @notice Signed offset (positive or negative) applied to the base REQUEST_VALIDITY_TIME during validation.
    int256 public requestValidityTimeOffset;

    /// @notice Emitted the first time the Xsolla guardian (implicit) initiates a recovery for an account.
    /// @param account The account undergoing recovery.
    /// @param guardian The implicit guardian (xsolla) that initiated the recovery.
    event XsollaGuardianRecovery(address indexed account, address indexed guardian);

    /// @notice Error thrown when attempting to modify guardians which is disabled in this implementation.
    error GuardianModificationDisabled();

    /// @notice Deploys the executor with required validator references and role assignments.
    /// @param _webAuthValidator The address of the WebAuthn (passkey) validator contract.
    /// @param _eoaValidator The address of the EOA key validator contract.
    /// @param _finalizer Address granted FINALIZER_ROLE privileges.
    /// @param _admin Address granted DEFAULT_ADMIN_ROLE privileges.
    /// @param _submitter Address granted SUBMITTER_ROLE privileges.
    constructor(
        address _webAuthValidator,
        address _eoaValidator,
        address _finalizer,
        address _admin,
        address _submitter
    ) GuardianExecutor(_webAuthValidator, _eoaValidator) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(FINALIZER_ROLE, _finalizer);
        _grantRole(SUBMITTER_ROLE, _submitter);
    }

    /// @notice Initializes a recovery request on behalf of the implicit Xsolla guardian.
    /// @dev Bypasses onlyGuardianOf from the base when invoked through the privileged submitter path.
    /// Validates no active recovery exists or that the previous one expired.
    /// @param accountToRecover The smart account subject to recovery.
    /// @param recoveryType The recovery type (EOA or Passkey).
    /// @param data ABI-encoded payload required by the target validator.
    function initializeRecovery(address accountToRecover, RecoveryType recoveryType, bytes calldata data)
        external
        virtual
        override
        onlyRole(SUBMITTER_ROLE)
    {
        // Implicit guardian path: replicate the base logic without the onlyGuardianOf modifier.
        checkInstalledValidator(accountToRecover, recoveryType);
        uint256 pendingRecoveryTimestamp = pendingRecovery[accountToRecover].timestamp;
        if (!(pendingRecoveryTimestamp == 0 || pendingRecoveryTimestamp + REQUEST_VALIDITY_TIME < block.timestamp)) {
            revert RecoveryInProgress(accountToRecover);
        }
        RecoveryRequest memory recovery = RecoveryRequest(recoveryType, data, uint48(block.timestamp));
        pendingRecovery[accountToRecover] = recovery;
        emit RecoveryInitiated(accountToRecover, msg.sender, recovery);
        emit XsollaGuardianRecovery(accountToRecover, msg.sender);
    }

    /// @notice Finalizes an in-progress recovery after the delay window and before the expiry window.
    /// @dev Executes a call into the respective validator to append a new key or validation record.
    /// @param account The account whose recovery is being finalized.
    /// @return returnData The raw return data from the underlying validator execution.
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

        if (!(recovery.timestamp + SafeCast.toUint256(SafeCast.toInt256(REQUEST_DELAY_TIME) + requestDelayTimeOffset)
                        < block.timestamp
                    && recovery.timestamp
                            + SafeCast.toUint256(SafeCast.toInt256(REQUEST_VALIDITY_TIME) + requestValidityTimeOffset)
                        > block.timestamp)) {
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

    // ---------------------------------------------------------------------
    // Disabled guardian management (only implicit xsolla guardian is allowed).
    // ---------------------------------------------------------------------

    /// @notice Disabled in this implementation because guardian modification is not supported.
    /// @param /*newGuardian*/ Ignored parameter.
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

    /// @notice Disabled in this implementation because guardian modification is not supported.
    /// @param /*accountToGuard*/ Ignored parameter.
    /// @return Always reverts; return included for interface compatibility.
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

    /// @notice Disabled in this implementation because guardian modification is not supported.
    /// @param /*guardianToRemove*/ Ignored parameter.
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

    /// @notice Sets a signed offset applied to REQUEST_DELAY_TIME during recovery validation.
    /// @dev Only callable by admin.
    /// @param offset The signed offset in seconds (positive or negative).
    function setRequestDelayTimeOffset(int256 offset) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        requestDelayTimeOffset = offset;
    }

    /// @notice Sets a signed offset applied to REQUEST_VALIDITY_TIME during recovery validation.
    /// @dev Only callable by admin.
    /// @param offset The signed offset in seconds (positive or negative).
    function setRequestValidityTimeOffset(int256 offset) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        requestValidityTimeOffset = offset;
    }
}
