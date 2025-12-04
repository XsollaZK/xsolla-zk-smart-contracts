// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { ERC1155Modular } from "./extensions/ERC1155Modular.sol";

/// @title ERC1155Factory
/// @author Oleg Bedrin <o.bedrin@xsolla.com> - Xsolla Web3
/// @notice A factory contract for deploying ERC1155 collections with base URI
/// management.
contract ERC1155Factory is Ownable {
    /// @notice Emitted when a new collection is deployed.
    /// @param newCollectionAddress The address of the newly deployed
    /// collection.
    event NewCollectionDeployed(address indexed newCollectionAddress);

    /// @notice The constructor sets the initial owner to the deployer.
    constructor() Ownable(_msgSender()) { }

    /// @notice Deploys a new ERC1155 collection with a specified base URI.
    /// @param baseURI The base URI for the new collection.
    function deployCollection(string memory baseURI) external {
        ERC1155Modular collection = new ERC1155Modular();
        collection.setBaseURI(baseURI);
        collection.grantRole(0x0, _msgSender());
        emit NewCollectionDeployed(address(collection));
    }
}
