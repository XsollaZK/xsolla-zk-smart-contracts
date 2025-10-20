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
        // Deploy executor (constructor arg order: webAuth, eoa, admin,
        // finalizer, submitter)
        executor = new XsollaRecoveryExecutor(
            address(0),
            address(eoaValidator)
        );
        executor.initialize(address(this), address(this), address(this));

        // Install executor module on the smart account (mirrors Guardian.t.sol
        // style)
        bytes memory data =
            abi.encodeCall(ModularSmartAccount.installModule, (MODULE_TYPE_EXECUTOR, address(executor), ""));
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = makeSignedUserOp(data, owner.key, address(eoaValidator));
        entryPoint.handleOps(userOps, bundler);
    }

    // Fuzz successful recovery path with synthesized local time adjustments (no
    // on-chain offsets)
    function testFuzz_RecoverySuccess(int128 delayOffset, int128 validityOffset, uint64 warpExtra) public {
        uint256 baseDelay = executor.REQUEST_DELAY_TIME();
        uint256 baseValidity = executor.REQUEST_VALIDITY_TIME();
        vm.assume(baseValidity > baseDelay + 2);

        // Derive a non-negative extra delay (cap 7 days) using safe abs (cast
        // to int256 first to avoid overflow)
        int256 d = int256(delayOffset);
        uint256 delayExtra = uint256(d < 0 ? -d : d) % 7 days;
        uint256 effDelay = baseDelay + delayExtra;

        // Ensure effDelay leaves room inside validity window; clamp if needed
        if (effDelay + 2 >= baseValidity) {
            // If window too tight after adding extra, reduce to last valid
            // start ensuring effDelay >= baseDelay
            if (baseValidity > baseDelay + 2) {
                effDelay = baseValidity - 3;
                if (effDelay < baseDelay) effDelay = baseDelay;
            } else {
                // No usable window – skip
                return;
            }
        }

        // Derive warpExtra limited to stay strictly before validity end
        uint256 maxWarpExtra = baseValidity - effDelay - 2; // need at least +1
            // to pass delay and < validity
        if (maxWarpExtra > 0) {
            warpExtra = uint64(warpExtra % (maxWarpExtra + 1));
        } else {
            warpExtra = 0;
        }

        // validityOffset unused now; keep param noise for fuzzing distribution
        validityOffset; // silence warning

        newOwner = makeAccount("newOwnerFuzz");
        executor.initializeRecovery(address(account), GuardianExecutor.RecoveryType.EOA, abi.encode(newOwner.addr));

        // Early finalize should revert
        vm.expectPartialRevert(GuardianExecutor_RecoverTimestampInvalid_selector());
        executor.finalizeRecovery(address(account));

        // Warp into valid window: timestamp + effDelay + 1 (+ optional
        // warpExtra)
        vm.warp(block.timestamp + effDelay + 1 + warpExtra);

        executor.finalizeRecovery(address(account));

        assertTrue(eoaValidator.isOwnerOf(address(account), newOwner.addr), "New owner not added");
        (uint8 rType, bytes memory dataBytes, uint256 ts) = _pending();
        assertEq(rType, uint8(GuardianExecutor.RecoveryType.None), "Recovery not cleared");
        assertEq(dataBytes.length, 0, "Data not cleared");
        assertEq(ts, 0, "Timestamp not cleared");
    }

    // Fuzz early finalize revert (always finalize immediately)
    function testFuzz_RevertEarly(int128 delayOffset) public {
        delayOffset; // param retained for fuzz diversity
        newOwner = makeAccount("earlyOwner");
        executor.initializeRecovery(address(account), GuardianExecutor.RecoveryType.EOA, abi.encode(newOwner.addr));
        vm.expectPartialRevert(GuardianExecutor_RecoverTimestampInvalid_selector());
        executor.finalizeRecovery(address(account));
    }

    // Fuzz late finalize revert (warp past validity window)
    function testFuzz_RevertLate(int128 delayOffset, int128 validityOffset, uint64 extraWarp) public {
        delayOffset; // unused now
        validityOffset;
        uint256 baseDelay = executor.REQUEST_DELAY_TIME();
        uint256 baseValidity = executor.REQUEST_VALIDITY_TIME();
        vm.assume(baseValidity > baseDelay + 2);

        newOwner = makeAccount("lateOwner");
        executor.initializeRecovery(address(account), GuardianExecutor.RecoveryType.EOA, abi.encode(newOwner.addr));

        // Warp beyond validity (timestamp + baseValidity + extra)
        extraWarp = uint64(extraWarp % 7 days);
        vm.warp(block.timestamp + baseDelay + baseValidity + extraWarp);

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
