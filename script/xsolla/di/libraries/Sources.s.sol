// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
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
import { GuardianBasedRecoveryExecutor } from "src/modules/contrib/GuardianBasedRecoveryExecutor.sol";

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
library Sources {
    using ShortStrings for ShortString;

    bytes32 public constant NICKNAMED_PROXY_FLAG = keccak256("NICKNAMED_PROXY_FLAG");
    bytes32 public constant EIP4337_FLAG = keccak256("EIP4337_FLAG");

    enum Source {
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
        GuardianBasedRecoveryExecutor,
        TransparentUpgradeableProxy,
        UpgradeableBeacon
    }

    error UnknownMetaArtifact();

    function getFullNicknamedName(Source metaArtifact, ShortString nickname) internal pure returns (string memory) {
        return string.concat(toString(metaArtifact), "_", nickname.toString());
    }

    function toSalt(Source metaArtifact) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(toString(metaArtifact)));
    }

    function toSalt(Source metaArtifact, ShortString nickname) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(toString(metaArtifact), nickname.toString()));
    }

    function toCreationCode(Source metaArtifact) internal pure returns (bytes memory) {
        if (metaArtifact == Source.AccountBase) {
            return type(AccountBase).creationCode;
        }
        if (metaArtifact == Source.AllowedSessionsValidator) {
            return type(AllowedSessionsValidator).creationCode;
        }
        if (metaArtifact == Source.BaseFeeCollector) {
            return type(BaseFeeCollector).creationCode;
        }
        if (metaArtifact == Source.ERC1155Claimer) {
            return type(ERC1155Claimer).creationCode;
        }
        if (metaArtifact == Source.ERC1155Factory) {
            return type(ERC1155Factory).creationCode;
        }
        if (metaArtifact == Source.ERC1155Modular) {
            return type(ERC1155Modular).creationCode;
        }
        if (metaArtifact == Source.ERC1155RoyaltyManaged) {
            return type(ERC1155RoyaltyManaged).creationCode;
        }
        if (metaArtifact == Source.ERC20Claimer) {
            return type(ERC20Claimer).creationCode;
        }
        if (metaArtifact == Source.ERC20Factory) {
            return type(ERC20Factory).creationCode;
        }
        if (metaArtifact == Source.ERC20Modular) {
            return type(ERC20Modular).creationCode;
        }
        if (metaArtifact == Source.ERC721Claimer) {
            return type(ERC721Claimer).creationCode;
        }
        if (metaArtifact == Source.ERC721Factory) {
            return type(ERC721Factory).creationCode;
        }
        if (metaArtifact == Source.ERC721Modular) {
            return type(ERC721Modular).creationCode;
        }
        if (metaArtifact == Source.ERC721RoyaltyManaged) {
            return type(ERC721RoyaltyManaged).creationCode;
        }
        if (metaArtifact == Source.EOAKeyValidator) {
            return type(EOAKeyValidator).creationCode;
        }
        if (metaArtifact == Source.EthereumFeeCollector) {
            return type(EthereumFeeCollector).creationCode;
        }
        if (metaArtifact == Source.ExecutionHelper) {
            return type(ExecutionHelper).creationCode;
        }
        if (metaArtifact == Source.ExecutionLib) {
            return type(ExecutionLib).creationCode;
        }
        if (metaArtifact == Source.Faucet) return type(Faucet).creationCode;
        if (metaArtifact == Source.GuardianExecutor) {
            return type(GuardianExecutor).creationCode;
        }
        if (metaArtifact == Source.ModeLib) return type(ModeLib).creationCode;
        if (metaArtifact == Source.MSAFactory) return type(MSAFactory).creationCode;
        if (metaArtifact == Source.ModularSmartAccount) {
            return type(ModularSmartAccount).creationCode;
        }
        if (metaArtifact == Source.SessionKeyValidator) {
            return type(SessionKeyValidator).creationCode;
        }
        if (metaArtifact == Source.SessionLib) return type(SessionLib).creationCode;
        if (metaArtifact == Source.SVGIconsLib) return type(SVGIconsLib).creationCode;
        if (metaArtifact == Source.WebAuthnValidator) {
            return type(WebAuthnValidator).creationCode;
        }
        if (metaArtifact == Source.WETH9) return type(WETH9).creationCode;
        if (metaArtifact == Source.GuardianBasedRecoveryExecutor) {
            return type(GuardianBasedRecoveryExecutor).creationCode;
        }
        if (metaArtifact == Source.TransparentUpgradeableProxy) {
            return type(TransparentUpgradeableProxy).creationCode;
        }
        if (metaArtifact == Source.UpgradeableBeacon) {
            return type(UpgradeableBeacon).creationCode;
        }
        revert UnknownMetaArtifact();
    }

    function toString(Source metaArtifact) internal pure returns (string memory) {
        if (metaArtifact == Source.AccountBase) {
            return type(AccountBase).name;
        }
        if (metaArtifact == Source.AllowedSessionsValidator) {
            return type(AllowedSessionsValidator).name;
        }
        if (metaArtifact == Source.BaseFeeCollector) {
            return type(BaseFeeCollector).name;
        }
        if (metaArtifact == Source.ERC1155Claimer) {
            return type(ERC1155Claimer).name;
        }
        if (metaArtifact == Source.ERC1155Factory) {
            return type(ERC1155Factory).name;
        }
        if (metaArtifact == Source.ERC1155Modular) {
            return type(ERC1155Modular).name;
        }
        if (metaArtifact == Source.ERC1155RoyaltyManaged) {
            return type(ERC1155RoyaltyManaged).name;
        }
        if (metaArtifact == Source.ERC20Claimer) {
            return type(ERC20Claimer).name;
        }
        if (metaArtifact == Source.ERC20Factory) {
            return type(ERC20Factory).name;
        }
        if (metaArtifact == Source.ERC20Modular) {
            return type(ERC20Modular).name;
        }
        if (metaArtifact == Source.ERC721Claimer) {
            return type(ERC721Claimer).name;
        }
        if (metaArtifact == Source.ERC721Factory) {
            return type(ERC721Factory).name;
        }
        if (metaArtifact == Source.ERC721Modular) {
            return type(ERC721Modular).name;
        }
        if (metaArtifact == Source.ERC721RoyaltyManaged) {
            return type(ERC721RoyaltyManaged).name;
        }
        if (metaArtifact == Source.EOAKeyValidator) {
            return type(EOAKeyValidator).name;
        }
        if (metaArtifact == Source.EthereumFeeCollector) {
            return type(EthereumFeeCollector).name;
        }
        if (metaArtifact == Source.ExecutionHelper) {
            return type(ExecutionHelper).name;
        }
        if (metaArtifact == Source.ExecutionLib) {
            return type(ExecutionLib).name;
        }
        if (metaArtifact == Source.Faucet) return type(Faucet).name;
        if (metaArtifact == Source.GuardianExecutor) {
            return type(GuardianExecutor).name;
        }
        if (metaArtifact == Source.ModeLib) return type(ModeLib).name;
        if (metaArtifact == Source.MSAFactory) return type(MSAFactory).name;
        if (metaArtifact == Source.ModularSmartAccount) {
            return type(ModularSmartAccount).name;
        }
        if (metaArtifact == Source.SessionKeyValidator) {
            return type(SessionKeyValidator).name;
        }
        if (metaArtifact == Source.SessionLib) return type(SessionLib).name;
        if (metaArtifact == Source.SVGIconsLib) return type(SVGIconsLib).name;
        if (metaArtifact == Source.WebAuthnValidator) {
            return type(WebAuthnValidator).name;
        }
        if (metaArtifact == Source.WETH9) return type(WETH9).name;
        if (metaArtifact == Source.GuardianBasedRecoveryExecutor) {
            return type(GuardianBasedRecoveryExecutor).name;
        }
        if (metaArtifact == Source.TransparentUpgradeableProxy) {
            return type(TransparentUpgradeableProxy).name;
        }
        if (metaArtifact == Source.UpgradeableBeacon) {
            return type(UpgradeableBeacon).name;
        }
        revert UnknownMetaArtifact();
    }
}
