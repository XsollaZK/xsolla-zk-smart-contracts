// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Vm } from "forge-std/Vm.sol";

import { ERC20Factory } from "src/xsolla/token/ERC20/ERC20Factory.sol";
import { ERC20Modular } from "src/xsolla/token/ERC20/extensions/ERC20Modular.sol";

/// @title ERC20Factory Fuzz Tests
/// @notice Comprehensive fuzz testing for the ERC20Factory contract
contract ERC20FactoryFuzzTest is Test {
    ERC20Factory public factory;
    address public owner;
    address public nonOwner;

    event NewERC20Deployed(address indexed newTokenAddress);

    function setUp() public {
        owner = makeAddr("owner");
        nonOwner = makeAddr("nonOwner");

        vm.prank(owner);
        factory = new ERC20Factory();
    }

    /// @notice Fuzz test for successful ERC20 deployment by owner
    function testFuzz_DeployERC20_Success(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser,
        address minter
    ) public {
        // Bound addresses to valid non-zero addresses
        vm.assume(defaultAdmin != address(0));
        vm.assume(pauser != address(0));
        vm.assume(minter != address(0));

        // Bound string lengths to reasonable limits
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 100);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 20);

        vm.prank(owner);

        // Record logs to capture the deployed address
        vm.recordLogs();
        factory.deployERC20(name, symbol, defaultAdmin, pauser, minter);

        // Get the deployed token address from logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the NewERC20Deployed event
        bool foundEvent = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("NewERC20Deployed(address)")) {
                address deployedToken = address(uint160(uint256(logs[i].topics[1])));
                assertTrue(deployedToken != address(0), "Deployed token address should not be zero");
                foundEvent = true;
                break;
            }
        }
        assertTrue(foundEvent, "NewERC20Deployed event should be emitted");
    }

    /// @notice Fuzz test for deployment failure when called by non-owner
    function testFuzz_DeployERC20_OnlyOwner(
        address caller,
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser,
        address minter
    ) public {
        vm.assume(caller != owner);
        vm.assume(defaultAdmin != address(0));
        vm.assume(pauser != address(0));
        vm.assume(minter != address(0));
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 100);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 20);

        vm.prank(caller);
        vm.expectRevert();
        factory.deployERC20(name, symbol, defaultAdmin, pauser, minter);
    }

    /// @notice Fuzz test for deployment with same addresses for all roles
    function testFuzz_DeployERC20_SameAddressAllRoles(string memory name, string memory symbol, address sameAddress)
        public
    {
        vm.assume(sameAddress != address(0));
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 100);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 20);

        vm.prank(owner);
        factory.deployERC20(name, symbol, sameAddress, sameAddress, sameAddress);

        // The deployment should succeed even when all roles are assigned to the
        // same address
    }

    /// @notice Fuzz test to verify deployed token properties
    function testFuzz_DeployedTokenProperties(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser,
        address minter
    ) public {
        vm.assume(defaultAdmin != address(0));
        vm.assume(pauser != address(0));
        vm.assume(minter != address(0));
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 100);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 20);

        vm.prank(owner);

        // Record logs to capture the deployed address
        vm.recordLogs();
        factory.deployERC20(name, symbol, defaultAdmin, pauser, minter);

        // Get the deployed token address from logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        address deployedTokenAddress;
        bool foundEvent = false;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("NewERC20Deployed(address)")) {
                deployedTokenAddress = address(uint160(uint256(logs[i].topics[1])));
                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "NewERC20Deployed event should be found");
        assertTrue(deployedTokenAddress != address(0), "Deployed token address should not be zero");

        ERC20Modular token = ERC20Modular(deployedTokenAddress);

        // Verify token properties
        assertEq(token.name(), name, "Token name should match");
        assertEq(token.symbol(), symbol, "Token symbol should match");
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), defaultAdmin), "Default admin role should be granted");
        assertTrue(token.hasRole(token.PAUSER_ROLE(), pauser), "Pauser role should be granted");
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter), "Minter role should be granted");
    }

    /// @notice Fuzz test for deployment with extremely long strings (edge case)
    function testFuzz_DeployERC20_LongStrings(address defaultAdmin, address pauser, address minter) public {
        vm.assume(defaultAdmin != address(0));
        vm.assume(pauser != address(0));
        vm.assume(minter != address(0));

        // Create very long strings
        string memory longName = "ThisIsAVeryLongTokenNameThatMightCauseIssuesInSomeImplementations";
        string memory longSymbol = "VERYLONGSYMBOL";

        vm.prank(owner);
        factory.deployERC20(longName, longSymbol, defaultAdmin, pauser, minter);
    }

    /// @notice Fuzz test for deployment with special characters in strings
    function testFuzz_DeployERC20_SpecialCharacters(address defaultAdmin, address pauser, address minter) public {
        vm.assume(defaultAdmin != address(0));
        vm.assume(pauser != address(0));
        vm.assume(minter != address(0));

        string memory nameWithSpecialChars = "Token-Name_123!@#";
        string memory symbolWithSpecialChars = "TKN-123";

        vm.prank(owner);
        factory.deployERC20(nameWithSpecialChars, symbolWithSpecialChars, defaultAdmin, pauser, minter);
    }

    /// @notice Fuzz test for multiple deployments
    function testFuzz_MultipleDeployments(
        uint8 deploymentCount,
        string memory baseName,
        string memory baseSymbol,
        address defaultAdmin,
        address pauser,
        address minter
    ) public {
        vm.assume(defaultAdmin != address(0));
        vm.assume(pauser != address(0));
        vm.assume(minter != address(0));
        vm.assume(bytes(baseName).length > 0 && bytes(baseName).length <= 50);
        vm.assume(bytes(baseSymbol).length > 0 && bytes(baseSymbol).length <= 10);

        // Limit deployment count to reasonable number
        deploymentCount = uint8(bound(deploymentCount, 1, 10));

        vm.startPrank(owner);
        for (uint8 i = 0; i < deploymentCount; i++) {
            string memory name = string(abi.encodePacked(baseName, vm.toString(i)));
            string memory symbol = string(abi.encodePacked(baseSymbol, vm.toString(i)));

            factory.deployERC20(name, symbol, defaultAdmin, pauser, minter);
        }
        vm.stopPrank();
    }

    /// @notice Fuzz test for ownership transfer and subsequent deployment
    function testFuzz_OwnershipTransferAndDeploy(
        address newOwner,
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser,
        address minter
    ) public {
        vm.assume(newOwner != address(0) && newOwner != owner);
        vm.assume(defaultAdmin != address(0));
        vm.assume(pauser != address(0));
        vm.assume(minter != address(0));
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 100);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 20);

        // Transfer ownership
        vm.prank(owner);
        factory.transferOwnership(newOwner);

        // Old owner should not be able to deploy
        vm.prank(owner);
        vm.expectRevert();
        factory.deployERC20(name, symbol, defaultAdmin, pauser, minter);

        // New owner should be able to deploy
        vm.prank(newOwner);
        factory.deployERC20(name, symbol, defaultAdmin, pauser, minter);
    }

    /// @notice Test factory owner getter
    function testFuzz_FactoryOwner() public view {
        assertEq(factory.owner(), owner, "Factory owner should be set correctly");
    }

    /// @notice Fuzz test for gas consumption analysis
    function testFuzz_GasConsumption(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser,
        address minter
    ) public {
        vm.assume(defaultAdmin != address(0));
        vm.assume(pauser != address(0));
        vm.assume(minter != address(0));
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 100);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 20);

        vm.prank(owner);

        uint256 gasBefore = gasleft();
        factory.deployERC20(name, symbol, defaultAdmin, pauser, minter);
        uint256 gasUsed = gasBefore - gasleft();

        // Log gas usage for analysis
        console.log("Gas used for deployment:", gasUsed);

        // Ensure gas usage is within reasonable bounds (adjust as needed)
        assertLt(gasUsed, 3_000_000, "Gas usage should be reasonable");
    }
}
