// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";

import { ERC1155Factory } from "src/xsolla/token/ERC1155/ERC1155Factory.sol";
import { ERC1155Modular } from "src/xsolla/token/ERC1155/extensions/ERC1155Modular.sol";

contract ERC1155FactoryFuzzTest is Test {
    ERC1155Factory public factory;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");
        factory = new ERC1155Factory();
    }

    function testFuzz_deployCollection(string memory baseURI) public {
        vm.assume(bytes(baseURI).length <= 1000); // Reasonable URI length

        vm.recordLogs();
        factory.deployCollection(baseURI);

        // Check that the event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(logs.length > 0);

        // Verify the event contains a valid address
        bytes32 eventSignature = keccak256("NewCollectionDeployed(address)");
        bool eventFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                address deployedAddress = abi.decode(abi.encodePacked(logs[i].topics[1]), (address));
                assertTrue(deployedAddress != address(0));
                eventFound = true;
                break;
            }
        }
        assertTrue(eventFound);
    }

    function testFuzz_deployMultipleCollections(string[] memory baseURIs) public {
        vm.assume(baseURIs.length > 0 && baseURIs.length <= 20);

        for (uint256 i = 0; i < baseURIs.length; i++) {
            vm.assume(bytes(baseURIs[i]).length <= 500);

            vm.recordLogs();
            factory.deployCollection(baseURIs[i]);

            Vm.Log[] memory logs = vm.getRecordedLogs();
            assertTrue(logs.length > 0);
        }
    }

    function testFuzz_deployCollectionGasConsumption(string memory baseURI) public {
        vm.assume(bytes(baseURI).length <= 200);

        uint256 gasBefore = gasleft();
        factory.deployCollection(baseURI);
        uint256 gasUsed = gasBefore - gasleft();

        // Verify gas usage is within reasonable bounds
        assertTrue(gasUsed > 0);
        assertTrue(gasUsed < 3_000_000); // 3M gas limit for deployment
    }

    function testFuzz_deployCollectionFromDifferentSenders(address deployer, string memory baseURI) public {
        vm.assume(deployer != address(0));
        vm.assume(bytes(baseURI).length <= 200);

        vm.prank(deployer);
        vm.recordLogs();
        factory.deployCollection(baseURI);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(logs.length > 0);
    }

    function testFuzz_factoryOwnership(address newOwner) public {
        vm.assume(newOwner != address(0));
        vm.assume(newOwner != owner);

        factory.transferOwnership(newOwner);
        assertEq(factory.owner(), newOwner);

        // Old owner should no longer be owner
        assertFalse(factory.owner() == owner);
    }

    function testFuzz_factoryState(bytes32 randomData) public {
        // Test factory remains in consistent state regardless of invalid input
        address factoryAddress = address(factory);
        uint256 initialCodeSize;

        assembly {
            initialCodeSize := extcodesize(factoryAddress)
        }

        // Attempt invalid operations with random data
        (bool success,) = factoryAddress.call(abi.encode(randomData));
        // Call may succeed or fail, but factory should remain unchanged

        // Verify factory state unchanged
        uint256 finalCodeSize;
        assembly {
            finalCodeSize := extcodesize(factoryAddress)
        }

        assertEq(initialCodeSize, finalCodeSize);
        assertEq(factory.owner(), owner); // Owner should remain unchanged
            // success variable is intentionally not checked as we're testing
            // state consistency
    }

    function testFuzz_deployEmptyURI() public {
        vm.recordLogs();
        factory.deployCollection("");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(logs.length > 0);
    }

    function testFuzz_deployWithSpecialCharacters(bytes memory uriBytes) public {
        vm.assume(uriBytes.length <= 500);
        string memory baseURI = string(uriBytes);

        vm.recordLogs();
        factory.deployCollection(baseURI);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(logs.length > 0);
    }

    function testFuzz_consecutiveDeployments(uint8 count, string memory basePrefix) public {
        vm.assume(count > 0 && count <= 10);
        vm.assume(bytes(basePrefix).length <= 100);

        for (uint256 i = 0; i < count; i++) {
            string memory baseURI = string(abi.encodePacked(basePrefix, vm.toString(i)));

            vm.recordLogs();
            factory.deployCollection(baseURI);

            Vm.Log[] memory logs = vm.getRecordedLogs();
            assertTrue(logs.length > 0);
        }
    }

    function testFuzz_deployCollectionMaintainsFactoryState(string memory baseURI) public {
        vm.assume(bytes(baseURI).length <= 200);

        address initialOwner = factory.owner();

        factory.deployCollection(baseURI);

        // Factory state should remain unchanged
        assertEq(factory.owner(), initialOwner);
    }
}
