// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { Config } from "forge-std/Config.sol";

import { Artifacts } from "./Artifacts.s.sol";

// 1 Historical proxies - automatic

contract Configuration is Config {
    using Artifacts for Artifacts.Artifact;

    enum Kind {
        NONE,
        PRODUCTION,
        DEBUG
    }

    string public constant DEFAULT_CONFIG_FOLDER = "./configurations/";
    string public constant PRODUCTION_CONFIG_FILENAME = "production.toml";
    string public constant DEBUG_CONFIG_FILENAME = "debug.toml";

    error ChooseConfigurationFirst();
    error UnknownConfiguration();
    error ArtifactHasNotBeenInjected(string name, address actual);

    modifier withMultiChainConfiguration(Kind configuration) {
        if (configuration == Kind.PRODUCTION) {
            _loadConfigAndForks(string(abi.encodePacked(DEFAULT_CONFIG_FOLDER, PRODUCTION_CONFIG_FILENAME)), true);
        } else if (configuration == Kind.DEBUG) {
            _loadConfigAndForks(string(abi.encodePacked(DEFAULT_CONFIG_FOLDER, DEBUG_CONFIG_FILENAME)), true);
        } else {
            revert UnknownConfiguration();
        }
        _;
    }

    modifier withConfiguration(Kind configuration) {
        if (configuration == Kind.PRODUCTION) {
            _loadConfig(string(abi.encodePacked(DEFAULT_CONFIG_FOLDER, PRODUCTION_CONFIG_FILENAME)), true);
        } else if (configuration == Kind.DEBUG) {
            _loadConfig(string(abi.encodePacked(DEFAULT_CONFIG_FOLDER, DEBUG_CONFIG_FILENAME)), true);
        } else {
            revert UnknownConfiguration();
        }
        _;
    }

    // --- Internal helpers to avoid duplication ---
    function _defineInjectionsPre(Artifacts.Artifact[] memory artifacts, bytes32[] memory uniqueIds) internal returns (address[] memory computedAddresses) {
        if (address(config) == address(0)) {
            revert ChooseConfigurationFirst();
        }
        computedAddresses = new address[](artifacts.length);
        for (uint256 i = 0; i < artifacts.length; i++) {
            address computedAddress;
            if (uniqueIds.length == artifacts.length) {
                computedAddress = artifacts[i].toCreate2Address(uniqueIds[i]);
                config.set(string.concat(string.concat(artifacts[i].toString(), "_"), Strings.toHexString(uint256(uniqueIds[i]))), computedAddress);
            } else {
                computedAddress = artifacts[i].toCreate2Address();
                config.set(artifacts[i].toString(), computedAddress);
            }
            computedAddresses[i] = computedAddress;
        }
    }

    // Added overload used by existing defineInjections{N} convenience modifiers
    function _defineInjectionsPre(Artifacts.Artifact[] memory artifacts) internal returns (address[] memory computedAddresses) {
        return _defineInjectionsPre(artifacts, new bytes32[](0));
    }

    function _defineInjectionsPost(Artifacts.Artifact[] memory artifacts, address[] memory computedAddresses) internal view {
        for (uint256 i = 0; i < computedAddresses.length; i++) {
            if (computedAddresses[i].code.length == 0) {
                revert ArtifactHasNotBeenInjected(artifacts[i].toString(), computedAddresses[i]);
            }
        }
    }

    // --- Existing modifier refactored to helpers ---
    modifier defineInjections(bytes memory concatenatedEncodedArtifacts) {
        Artifacts.Artifact[] memory artifacts = abi.decode(concatenatedEncodedArtifacts, (Artifacts.Artifact[]));
        address[] memory computedAddresses = _defineInjectionsPre(artifacts, new bytes32[](0));
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineUniqueInjections(bytes memory concatenatedEncodedArtifacts) {
        (Artifacts.Artifact[] memory artifacts, bytes32[] memory uniqueIds) = abi.decode(concatenatedEncodedArtifacts, (Artifacts.Artifact[], bytes32[]));
        address[] memory computedAddresses = _defineInjectionsPre(artifacts, uniqueIds);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    // --- New convenience modifiers for 1..10 artifacts ---

    modifier defineInjection(Artifacts.Artifact a1) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](1);
        artifacts[0] = a1;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineInjections2(Artifacts.Artifact a1, Artifacts.Artifact a2) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](2);
        artifacts[0] = a1;
        artifacts[1] = a2;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineInjections3(Artifacts.Artifact a1, Artifacts.Artifact a2, Artifacts.Artifact a3) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](3);
        artifacts[0] = a1;
        artifacts[1] = a2;
        artifacts[2] = a3;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineInjections4(Artifacts.Artifact a1, Artifacts.Artifact a2, Artifacts.Artifact a3, Artifacts.Artifact a4) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](4);
        artifacts[0] = a1;
        artifacts[1] = a2;
        artifacts[2] = a3;
        artifacts[3] = a4;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineInjections5(
        Artifacts.Artifact a1,
        Artifacts.Artifact a2,
        Artifacts.Artifact a3,
        Artifacts.Artifact a4,
        Artifacts.Artifact a5
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](5);
        artifacts[0] = a1;
        artifacts[1] = a2;
        artifacts[2] = a3;
        artifacts[3] = a4;
        artifacts[4] = a5;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineInjections6(
        Artifacts.Artifact a1,
        Artifacts.Artifact a2,
        Artifacts.Artifact a3,
        Artifacts.Artifact a4,
        Artifacts.Artifact a5,
        Artifacts.Artifact a6
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](6);
        artifacts[0] = a1;
        artifacts[1] = a2;
        artifacts[2] = a3;
        artifacts[3] = a4;
        artifacts[4] = a5;
        artifacts[5] = a6;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineInjections7(
        Artifacts.Artifact a1,
        Artifacts.Artifact a2,
        Artifacts.Artifact a3,
        Artifacts.Artifact a4,
        Artifacts.Artifact a5,
        Artifacts.Artifact a6,
        Artifacts.Artifact a7
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](7);
        artifacts[0] = a1;
        artifacts[1] = a2;
        artifacts[2] = a3;
        artifacts[3] = a4;
        artifacts[4] = a5;
        artifacts[5] = a6;
        artifacts[6] = a7;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineInjections8(
        Artifacts.Artifact a1,
        Artifacts.Artifact a2,
        Artifacts.Artifact a3,
        Artifacts.Artifact a4,
        Artifacts.Artifact a5,
        Artifacts.Artifact a6,
        Artifacts.Artifact a7,
        Artifacts.Artifact a8
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](8);
        artifacts[0] = a1;
        artifacts[1] = a2;
        artifacts[2] = a3;
        artifacts[3] = a4;
        artifacts[4] = a5;
        artifacts[5] = a6;
        artifacts[6] = a7;
        artifacts[7] = a8;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineInjections9(
        Artifacts.Artifact a1,
        Artifacts.Artifact a2,
        Artifacts.Artifact a3,
        Artifacts.Artifact a4,
        Artifacts.Artifact a5,
        Artifacts.Artifact a6,
        Artifacts.Artifact a7,
        Artifacts.Artifact a8,
        Artifacts.Artifact a9
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](9);
        artifacts[0] = a1;
        artifacts[1] = a2;
        artifacts[2] = a3;
        artifacts[3] = a4;
        artifacts[4] = a5;
        artifacts[5] = a6;
        artifacts[6] = a7;
        artifacts[7] = a8;
        artifacts[8] = a9;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineInjections10(
        Artifacts.Artifact a1,
        Artifacts.Artifact a2,
        Artifacts.Artifact a3,
        Artifacts.Artifact a4,
        Artifacts.Artifact a5,
        Artifacts.Artifact a6,
        Artifacts.Artifact a7,
        Artifacts.Artifact a8,
        Artifacts.Artifact a9,
        Artifacts.Artifact a10
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](10);
        artifacts[0] = a1;
        artifacts[1] = a2;
        artifacts[2] = a3;
        artifacts[3] = a4;
        artifacts[4] = a5;
        artifacts[5] = a6;
        artifacts[6] = a7;
        artifacts[7] = a8;
        artifacts[8] = a9;
        artifacts[9] = a10;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    // --- New convenience modifiers for defineUniqueInjections (1..10) ---

    modifier defineUniqueInjection(Artifacts.Artifact a1, bytes32 u1) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](1);
        artifacts[0] = a1;
        bytes32[] memory uniqueIds = new bytes32[](1);
        uniqueIds[0] = u1;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts, uniqueIds);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineUniqueInjections2(Artifacts.Artifact a1, bytes32 u1, Artifacts.Artifact a2, bytes32 u2) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](2);
        artifacts[0] = a1;
        artifacts[1] = a2;
        bytes32[] memory uniqueIds = new bytes32[](2);
        uniqueIds[0] = u1;
        uniqueIds[1] = u2;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts, uniqueIds);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineUniqueInjections3(
        Artifacts.Artifact a1, bytes32 u1,
        Artifacts.Artifact a2, bytes32 u2,
        Artifacts.Artifact a3, bytes32 u3
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](3);
        artifacts[0] = a1; artifacts[1] = a2; artifacts[2] = a3;
        bytes32[] memory uniqueIds = new bytes32[](3);
        uniqueIds[0] = u1; uniqueIds[1] = u2; uniqueIds[2] = u3;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts, uniqueIds);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineUniqueInjections4(
        Artifacts.Artifact a1, bytes32 u1,
        Artifacts.Artifact a2, bytes32 u2,
        Artifacts.Artifact a3, bytes32 u3,
        Artifacts.Artifact a4, bytes32 u4
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](4);
        artifacts[0]=a1; artifacts[1]=a2; artifacts[2]=a3; artifacts[3]=a4;
        bytes32[] memory uniqueIds = new bytes32[](4);
        uniqueIds[0]=u1; uniqueIds[1]=u2; uniqueIds[2]=u3; uniqueIds[3]=u4;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts, uniqueIds);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineUniqueInjections5(
        Artifacts.Artifact a1, bytes32 u1,
        Artifacts.Artifact a2, bytes32 u2,
        Artifacts.Artifact a3, bytes32 u3,
        Artifacts.Artifact a4, bytes32 u4,
        Artifacts.Artifact a5, bytes32 u5
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](5);
        artifacts[0]=a1; artifacts[1]=a2; artifacts[2]=a3; artifacts[3]=a4; artifacts[4]=a5;
        bytes32[] memory uniqueIds = new bytes32[](5);
        uniqueIds[0]=u1; uniqueIds[1]=u2; uniqueIds[2]=u3; uniqueIds[3]=u4; uniqueIds[4]=u5;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts, uniqueIds);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineUniqueInjections6(
        Artifacts.Artifact a1, bytes32 u1,
        Artifacts.Artifact a2, bytes32 u2,
        Artifacts.Artifact a3, bytes32 u3,
        Artifacts.Artifact a4, bytes32 u4,
        Artifacts.Artifact a5, bytes32 u5,
        Artifacts.Artifact a6, bytes32 u6
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](6);
        artifacts[0]=a1; artifacts[1]=a2; artifacts[2]=a3; artifacts[3]=a4; artifacts[4]=a5; artifacts[5]=a6;
        bytes32[] memory uniqueIds = new bytes32[](6);
        uniqueIds[0]=u1; uniqueIds[1]=u2; uniqueIds[2]=u3; uniqueIds[3]=u4; uniqueIds[4]=u5; uniqueIds[5]=u6;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts, uniqueIds);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineUniqueInjections7(
        Artifacts.Artifact a1, bytes32 u1,
        Artifacts.Artifact a2, bytes32 u2,
        Artifacts.Artifact a3, bytes32 u3,
        Artifacts.Artifact a4, bytes32 u4,
        Artifacts.Artifact a5, bytes32 u5,
        Artifacts.Artifact a6, bytes32 u6,
        Artifacts.Artifact a7, bytes32 u7
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](7);
        artifacts[0]=a1; artifacts[1]=a2; artifacts[2]=a3; artifacts[3]=a4; artifacts[4]=a5; artifacts[5]=a6; artifacts[6]=a7;
        bytes32[] memory uniqueIds = new bytes32[](7);
        uniqueIds[0]=u1; uniqueIds[1]=u2; uniqueIds[2]=u3; uniqueIds[3]=u4; uniqueIds[4]=u5; uniqueIds[5]=u6; uniqueIds[6]=u7;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts, uniqueIds);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineUniqueInjections8(
        Artifacts.Artifact a1, bytes32 u1,
        Artifacts.Artifact a2, bytes32 u2,
        Artifacts.Artifact a3, bytes32 u3,
        Artifacts.Artifact a4, bytes32 u4,
        Artifacts.Artifact a5, bytes32 u5,
        Artifacts.Artifact a6, bytes32 u6,
        Artifacts.Artifact a7, bytes32 u7,
        Artifacts.Artifact a8, bytes32 u8
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](8);
        artifacts[0]=a1; artifacts[1]=a2; artifacts[2]=a3; artifacts[3]=a4; artifacts[4]=a5; artifacts[5]=a6; artifacts[6]=a7; artifacts[7]=a8;
        bytes32[] memory uniqueIds = new bytes32[](8);
        uniqueIds[0]=u1; uniqueIds[1]=u2; uniqueIds[2]=u3; uniqueIds[3]=u4; uniqueIds[4]=u5; uniqueIds[5]=u6; uniqueIds[6]=u7; uniqueIds[7]=u8;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts, uniqueIds);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineUniqueInjections9(
        Artifacts.Artifact a1, bytes32 u1,
        Artifacts.Artifact a2, bytes32 u2,
        Artifacts.Artifact a3, bytes32 u3,
        Artifacts.Artifact a4, bytes32 u4,
        Artifacts.Artifact a5, bytes32 u5,
        Artifacts.Artifact a6, bytes32 u6,
        Artifacts.Artifact a7, bytes32 u7,
        Artifacts.Artifact a8, bytes32 u8,
        Artifacts.Artifact a9, bytes32 u9
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](9);
        artifacts[0]=a1; artifacts[1]=a2; artifacts[2]=a3; artifacts[3]=a4; artifacts[4]=a5; artifacts[5]=a6; artifacts[6]=a7; artifacts[7]=a8; artifacts[8]=a9;
        bytes32[] memory uniqueIds = new bytes32[](9);
        uniqueIds[0]=u1; uniqueIds[1]=u2; uniqueIds[2]=u3; uniqueIds[3]=u4; uniqueIds[4]=u5; uniqueIds[5]=u6; uniqueIds[6]=u7; uniqueIds[7]=u8; uniqueIds[8]=u9;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts, uniqueIds);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }

    modifier defineUniqueInjections10(
        Artifacts.Artifact a1, bytes32 u1,
        Artifacts.Artifact a2, bytes32 u2,
        Artifacts.Artifact a3, bytes32 u3,
        Artifacts.Artifact a4, bytes32 u4,
        Artifacts.Artifact a5, bytes32 u5,
        Artifacts.Artifact a6, bytes32 u6,
        Artifacts.Artifact a7, bytes32 u7,
        Artifacts.Artifact a8, bytes32 u8,
        Artifacts.Artifact a9, bytes32 u9,
        Artifacts.Artifact a10, bytes32 u10
    ) {
        Artifacts.Artifact[] memory artifacts = new Artifacts.Artifact[](10);
        artifacts[0]=a1; artifacts[1]=a2; artifacts[2]=a3; artifacts[3]=a4; artifacts[4]=a5; artifacts[5]=a6; artifacts[6]=a7; artifacts[7]=a8; artifacts[8]=a9; artifacts[9]=a10;
        bytes32[] memory uniqueIds = new bytes32[](10);
        uniqueIds[0]=u1; uniqueIds[1]=u2; uniqueIds[2]=u3; uniqueIds[3]=u4; uniqueIds[4]=u5; uniqueIds[5]=u6; uniqueIds[6]=u7; uniqueIds[7]=u8; uniqueIds[8]=u9; uniqueIds[9]=u10;
        address[] memory computedAddresses = _defineInjectionsPre(artifacts, uniqueIds);
        _;
        _defineInjectionsPost(artifacts, computedAddresses);
    }
}
