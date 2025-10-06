// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { PackedUserOperation } from "account-abstraction/interfaces/PackedUserOperation.sol";
import { ModularSmartAccount } from "src/ModularSmartAccount.sol";

import { IERC7579Account } from "src/interfaces/IERC7579Account.sol";
import { ExecutionLib } from "src/libraries/ExecutionLib.sol";
import { ModeLib } from "src/libraries/ModeLib.sol";
import { MODULE_TYPE_EXECUTOR } from "src/interfaces/IERC7579Module.sol";
import { XsollaRecoveryExecutor } from "src/xsolla/modules/XsollaRecoveryExecutor.sol";
import { EOAKeyValidator } from "src/modules/EOAKeyValidator.sol";
import { GuardianExecutor } from "src/modules/GuardianExecutor.sol";

import { MSATest } from "../../MSATest.sol";

contract XsollaRecoveryExecutorFuzzTest is MSATest {
    XsollaRecoveryExecutor internal executor;
    Account internal newOwner;

    function setUp() public override {
        super.setUp();
        // Deploy executor (this contract: admin, submitter, finalizer)
        executor = new XsollaRecoveryExecutor(
            address(0), // webAuthValidator (unused in these fuzzes)
            address(eoaValidator), // eoa validator
            address(this), // finalizer
            address(this), // admin
            address(this) // submitter == implicit guardian (not explicitly used – roles drive access)
        );

        // Install executor module on the smart account (mirrors Guardian.t.sol style)
        bytes memory data =
            abi.encodeCall(ModularSmartAccount.installModule, (MODULE_TYPE_EXECUTOR, address(executor), ""));
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = makeSignedUserOp(data, owner.key, address(eoaValidator));
        entryPoint.handleOps(userOps, bundler);
    }

    // Fuzz successful recovery path with signed time offsets
    function testFuzz_RecoverySuccess(int128 delayOffset, int128 validityOffset, uint64 warpExtra) public {
        uint256 baseDelay = executor.REQUEST_DELAY_TIME();
        uint256 baseValidity = executor.REQUEST_VALIDITY_TIME();

        // Bound offsets so (base + offset) stays >= 0 and within sane test window
        vm.assume(delayOffset >= -int128(int256(baseDelay)) && delayOffset <= int128(7 days));
        vm.assume(validityOffset >= -int128(int256(baseValidity)) && validityOffset <= int128(14 days));

        int256 effDelaySigned = int256(uint256(baseDelay)) + delayOffset;
        int256 effValiditySigned = int256(uint256(baseValidity)) + validityOffset;
        vm.assume(effDelaySigned >= 0 && effValiditySigned >= 0);

        uint256 effDelay = uint256(effDelaySigned);
        uint256 effValidity = uint256(effValiditySigned);

        // Need enough room for finalize (validity > delay + 2)
        vm.assume(effValidity > effDelay + 2);

        // Bound extra warp so we stay inside validity window
        if (effValidity - effDelay > 3) {
            vm.assume(warpExtra <= uint64(effValidity - effDelay - 2));
        } else {
            warpExtra = 0;
        }

        // Apply offsets
        executor.setRequestDelayTimeOffset(delayOffset);
        executor.setRequestValidityTimeOffset(validityOffset);

        // New owner target
        newOwner = makeAccount("newOwnerFuzz");

        // Initialize recovery (EOA path)
        executor.initializeRecovery(address(account), GuardianExecutor.RecoveryType.EOA, abi.encode(newOwner.addr));

        // Early finalize must revert
        vm.expectPartialRevert(GuardianExecutor_RecoverTimestampInvalid_selector());
        executor.finalizeRecovery(address(account));

        // Warp into valid window
        vm.warp(block.timestamp + effDelay + 1 + warpExtra);

        // Finalize (should succeed)
        executor.finalizeRecovery(address(account));

        // Assert new owner appended
        address[] memory owners = eoaValidator.getOwners(address(account));
        bool found;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == newOwner.addr) {
                found = true;
                break;
            }
        }
        assertTrue(found, "New owner not added");

        // Pending cleared
        (uint8 rType, bytes memory dataBytes, uint256 ts) = _pending();
        assertEq(rType, uint8(GuardianExecutor.RecoveryType.None), "Recovery not cleared");
        assertEq(dataBytes.length, 0, "Data not cleared");
        assertEq(ts, 0, "Timestamp not cleared");
    }

    // Fuzz early finalize revert (delay not yet passed)
    function testFuzz_RevertEarly(int128 delayOffset) public {
        uint256 baseDelay = executor.REQUEST_DELAY_TIME();
        vm.assume(delayOffset >= -int128(int256(baseDelay)) && delayOffset <= int128(5 days));
        executor.setRequestDelayTimeOffset(delayOffset);

        newOwner = makeAccount("earlyOwner");
        executor.initializeRecovery(address(account), GuardianExecutor.RecoveryType.EOA, abi.encode(newOwner.addr));

        vm.expectPartialRevert(GuardianExecutor_RecoverTimestampInvalid_selector());
        executor.finalizeRecovery(address(account));
    }

    // Fuzz late finalize revert (past validity window)
    function testFuzz_RevertLate(int128 delayOffset, int128 validityOffset, uint64 extraWarp) public {
        uint256 baseDelay = executor.REQUEST_DELAY_TIME();
        uint256 baseValidity = executor.REQUEST_VALIDITY_TIME();

        vm.assume(delayOffset >= -int128(int256(baseDelay)) && delayOffset <= int128(7 days));
        vm.assume(validityOffset >= -int128(int256(baseValidity)) && validityOffset <= int128(14 days));

        int256 effDelaySigned = int256(uint256(baseDelay)) + delayOffset;
        int256 effValiditySigned = int256(uint256(baseValidity)) + validityOffset;
        vm.assume(effDelaySigned >= 0 && effValiditySigned >= 0);

        uint256 effDelay = uint256(effDelaySigned);
        uint256 effValidity = uint256(effValiditySigned);
        vm.assume(effValidity > effDelay + 2);

        executor.setRequestDelayTimeOffset(delayOffset);
        executor.setRequestValidityTimeOffset(validityOffset);

        newOwner = makeAccount("lateOwner");
        executor.initializeRecovery(address(account), GuardianExecutor.RecoveryType.EOA, abi.encode(newOwner.addr));

        // Warp past expiry: delay + validity + extra
        vm.assume(extraWarp < 7 days);
        vm.warp(block.timestamp + effDelay + effValidity + extraWarp);

        vm.expectPartialRevert(GuardianExecutor_RecoverTimestampInvalid_selector());
        executor.finalizeRecovery(address(account));
    }

    // Helper to read pending (cast to simple tuple for assertions)
    function _pending() internal view returns (uint8 rType, bytes memory dataBytes, uint256 ts) {
        (GuardianExecutor.RecoveryType recoveryType, bytes memory data, uint256 timestamp) =
            executor.pendingRecovery(address(account));
        rType = uint8(recoveryType);
        dataBytes = data;
        ts = timestamp;
    }

    // Selector helper (avoids importing full base just for selector constant)
    function GuardianExecutor_RecoverTimestampInvalid_selector() internal pure returns (bytes4) {
        return bytes4(keccak256("RecoveryTimestampInvalid(uint48)"));
    }
}
