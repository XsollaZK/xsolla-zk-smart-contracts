// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";


// Artifact imports (grouped by domain with corrected paths)
// Accounts / Factory
import { AccountBase } from "src/core/AccountBase.sol";
import { ModularSmartAccount } from "src/ModularSmartAccount.sol";
import { MSAFactory } from "src/MSAFactory.sol";

// Validators (modules)
import { SessionKeyValidator } from "src/modules/SessionKeyValidator.sol";
import { EOAKeyValidator } from "src/modules/EOAKeyValidator.sol";
import { WebAuthnValidator } from "src/modules/WebAuthnValidator.sol";
import { AllowedSessionsValidator } from "src/modules/contrib/AllowedSessionsValidator.sol";

// Executors
import { GuardianExecutor } from "src/modules/GuardianExecutor.sol";
import { XsollaRecoveryExecutor } from "src/xsolla/modules/XsollaRecoveryExecutor.sol";

// Fee collectors
import { BaseFeeCollector } from "src/xsolla/collector/BaseFeeCollector.sol";
import { EthereumFeeCollector } from "src/xsolla/collector/EthereumFeeCollector.sol";

// ERC1155
import { ERC1155Factory } from "src/xsolla/token/ERC1155/ERC1155Factory.sol";
import { ERC1155Modular } from "src/xsolla/token/ERC1155/extensions/ERC1155Modular.sol";
import { ERC1155RoyaltyManaged } from "src/xsolla/token/ERC1155/extensions/ERC1155RoyaltyManaged.sol";
import { ERC1155Claimer } from "src/xsolla/token/ERC1155/ERC1155Claimer.sol";

// ERC20
import { ERC20Factory } from "src/xsolla/token/ERC20/ERC20Factory.sol";
import { ERC20Modular } from "src/xsolla/token/ERC20/extensions/ERC20Modular.sol";
import { ERC20Claimer } from "src/xsolla/token/ERC20/ERC20Claimer.sol";

// ERC721
import { ERC721Factory } from "src/xsolla/token/ERC721/ERC721Factory.sol";
import { ERC721Modular } from "src/xsolla/token/ERC721/extensions/ERC721Modular.sol";
import { ERC721RoyaltyManaged } from "src/xsolla/token/ERC721/extensions/ERC721RoyaltyManaged.sol";
import { ERC721Claimer } from "src/xsolla/token/ERC721/ERC721Claimer.sol";

// Libraries / Helpers
import { ExecutionHelper } from "src/core/ExecutionHelper.sol";
import { ExecutionLib } from "src/libraries/ExecutionLib.sol";
import { ModeLib } from "src/libraries/ModeLib.sol";
import { SessionLib } from "src/libraries/SessionLib.sol";
import { SVGIconsLib } from "src/xsolla/libraries/SVGIconsLib.sol";

// Misc
import { Faucet } from "src/xsolla/Faucet.sol";
import { WETH9 } from "src/xsolla/WETH9.sol";

/// @dev This library is going to be generated in the future versions of DI
library Artifacts {
    enum Artifact {
        NONE,
        AccountBase,
        AllowedSessionsValidator,
        BaseFeeCollector,
        ERC1155Claimer,
        ERC1155Factory,
        ERC1155Modular,
        ERC1155RoyaltyManaged,
        ERC20Claimer,
        ERC20Factory,
        ERC20Modular,
        ERC721Claimer,
        ERC721Factory,
        ERC721Modular,
        ERC721RoyaltyManaged,
        EOAKeyValidator,
        EthereumFeeCollector,
        ExecutionHelper,
        ExecutionLib,
        Faucet,
        GuardianExecutor,
        ModeLib,
        MSAFactory,
        ModularSmartAccount,
        SessionKeyValidator,
        SessionLib,
        SVGIconsLib,
        WebAuthnValidator,
        WETH9,
        XsollaRecoveryExecutor,
        TransparentUpgradeableProxy
    }

    address public constant FOUNDRY_CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    error UnknownArtifact();

    function toSalt(Artifact artifact) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(toString(artifact)));
    }

    function toSalt(Artifact artifact, bytes32 uniqueId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(toString(artifact), uniqueId));
    }

    function toCreate2Address(Artifact artifact) internal pure returns (address) {
        // The Create2 deployer address is hardcoded in Foundry settings
        return
            Create2.computeAddress(
                toSalt(artifact), toBytecodeHash(artifact), FOUNDRY_CREATE2_DEPLOYER
            );
    }

    function toCreate2Address(Artifact artifact, bytes32 uniqueId) internal pure returns (address) {
        // The Create2 deployer address is hardcoded in Foundry settings
        return
            Create2.computeAddress(
                toSalt(artifact, uniqueId), toBytecodeHash(artifact), FOUNDRY_CREATE2_DEPLOYER
            );
    }

    function toBytecodeHash(Artifact artifact) internal pure returns (bytes32) {
        if (artifact == Artifact.AccountBase) {
            return keccak256(type(AccountBase).creationCode);
        }
        if (artifact == Artifact.AllowedSessionsValidator) {
            return keccak256(type(AllowedSessionsValidator).creationCode);
        }
        if (artifact == Artifact.BaseFeeCollector) {
            return keccak256(type(BaseFeeCollector).creationCode);
        }
        if (artifact == Artifact.ERC1155Claimer) {
            return keccak256(type(ERC1155Claimer).creationCode);
        }
        if (artifact == Artifact.ERC1155Factory) {
            return keccak256(type(ERC1155Factory).creationCode);
        }
        if (artifact == Artifact.ERC1155Modular) {
            return keccak256(type(ERC1155Modular).creationCode);
        }
        if (artifact == Artifact.ERC1155RoyaltyManaged) {
            return keccak256(type(ERC1155RoyaltyManaged).creationCode);
        }
        if (artifact == Artifact.ERC20Claimer) {
            return keccak256(type(ERC20Claimer).creationCode);
        }
        if (artifact == Artifact.ERC20Factory) {
            return keccak256(type(ERC20Factory).creationCode);
        }
        if (artifact == Artifact.ERC20Modular) {
            return keccak256(type(ERC20Modular).creationCode);
        }
        if (artifact == Artifact.ERC721Claimer) {
            return keccak256(type(ERC721Claimer).creationCode);
        }
        if (artifact == Artifact.ERC721Factory) {
            return keccak256(type(ERC721Factory).creationCode);
        }
        if (artifact == Artifact.ERC721Modular) {
            return keccak256(type(ERC721Modular).creationCode);
        }
        if (artifact == Artifact.ERC721RoyaltyManaged) {
            return keccak256(type(ERC721RoyaltyManaged).creationCode);
        }
        if (artifact == Artifact.EOAKeyValidator) {
            return keccak256(type(EOAKeyValidator).creationCode);
        }
        if (artifact == Artifact.EthereumFeeCollector) {
            return keccak256(type(EthereumFeeCollector).creationCode);
        }
        if (artifact == Artifact.ExecutionHelper) {
            return keccak256(type(ExecutionHelper).creationCode);
        }
        if (artifact == Artifact.ExecutionLib) {
            return keccak256(type(ExecutionLib).creationCode);
        }
        if (artifact == Artifact.Faucet) {
            return keccak256(type(Faucet).creationCode);
        }
        if (artifact == Artifact.GuardianExecutor) {
            return keccak256(type(GuardianExecutor).creationCode);
        }
        if (artifact == Artifact.ModeLib) {
            return keccak256(type(ModeLib).creationCode);
        }
        if (artifact == Artifact.MSAFactory) {
            return keccak256(type(MSAFactory).creationCode);
        }
        if (artifact == Artifact.ModularSmartAccount) {
            return keccak256(type(ModularSmartAccount).creationCode);
        }
        if (artifact == Artifact.SessionKeyValidator) {
            return keccak256(type(SessionKeyValidator).creationCode);
        }
        if (artifact == Artifact.SessionLib) {
            return keccak256(type(SessionLib).creationCode);
        }
        if (artifact == Artifact.SVGIconsLib) {
            return keccak256(type(SVGIconsLib).creationCode);
        }
        if (artifact == Artifact.WebAuthnValidator) {
            return keccak256(type(WebAuthnValidator).creationCode);
        }
        if (artifact == Artifact.WETH9) {
            return keccak256(type(WETH9).creationCode);
        }
        if (artifact == Artifact.XsollaRecoveryExecutor) {
            return keccak256(type(XsollaRecoveryExecutor).creationCode);
        }
        if (artifact == Artifact.TransparentUpgradeableProxy) {
            return keccak256(type(TransparentUpgradeableProxy).creationCode);
        }
        revert UnknownArtifact();
    }

    function toString(Artifact artifact) internal pure returns (string memory) {
        if (artifact == Artifact.AccountBase) return "AccountBase";
        if (artifact == Artifact.AllowedSessionsValidator) {
            return "AllowedSessionsValidator";
        }
        if (artifact == Artifact.BaseFeeCollector) return "BaseFeeCollector";
        if (artifact == Artifact.ERC1155Claimer) return "ERC1155Claimer";
        if (artifact == Artifact.ERC1155Factory) return "ERC1155Factory";
        if (artifact == Artifact.ERC1155Modular) return "ERC1155Modular";
        if (artifact == Artifact.ERC1155RoyaltyManaged) {
            return "ERC1155RoyaltyManaged";
        }
        if (artifact == Artifact.ERC20Claimer) return "ERC20Claimer";
        if (artifact == Artifact.ERC20Factory) return "ERC20Factory";
        if (artifact == Artifact.ERC20Modular) return "ERC20Modular";
        if (artifact == Artifact.ERC721Claimer) return "ERC721Claimer";
        if (artifact == Artifact.ERC721Factory) return "ERC721Factory";
        if (artifact == Artifact.ERC721Modular) return "ERC721Modular";
        if (artifact == Artifact.ERC721RoyaltyManaged) {
            return "ERC721RoyaltyManaged";
        }
        if (artifact == Artifact.EOAKeyValidator) return "EOAKeyValidator";
        if (artifact == Artifact.EthereumFeeCollector) {
            return "EthereumFeeCollector";
        }
        if (artifact == Artifact.ExecutionHelper) return "ExecutionHelper";
        if (artifact == Artifact.ExecutionLib) return "ExecutionLib";
        if (artifact == Artifact.Faucet) return "Faucet";
        if (artifact == Artifact.GuardianExecutor) return "GuardianExecutor";
        if (artifact == Artifact.ModeLib) return "ModeLib";
        if (artifact == Artifact.MSAFactory) return "MSAFactory";
        if (artifact == Artifact.ModularSmartAccount) {
            return "ModularSmartAccount";
        }
        if (artifact == Artifact.SessionKeyValidator) {
            return "SessionKeyValidator";
        }
        if (artifact == Artifact.SessionLib) return "SessionLib";
        if (artifact == Artifact.SVGIconsLib) return "SVGIconsLib";
        if (artifact == Artifact.WebAuthnValidator) return "WebAuthnValidator";
        if (artifact == Artifact.WETH9) return "WETH9";
        if (artifact == Artifact.XsollaRecoveryExecutor) {
            return "XsollaRecoveryExecutor";
        }
        if (artifact == Artifact.TransparentUpgradeableProxy) {
            return "TransparentUpgradeableProxy";
        }
        revert UnknownArtifact();
    }
}
