// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { ISetBaseURI } from "../../../interfaces/drafts/ISetBaseURI.sol";

/// @title ERC1155Modular
/// @author Oleg Bedrin <o.bedrin@xsolla.com> - Xsolla Web3
/// @notice A base contract for ERC1155 tokens with minting, burning, and base
/// URI management. @custom:include-in-addresses-report false
contract ERC1155Modular is ERC1155, AccessControl, ISetBaseURI {
    /// @notice Role identifier for addresses that can mint tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role identifier for addresses that can burn tokens.
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Controls whether minting is enabled or disabled.
    bool public mintingEnabled;

    /// @notice Controls whether burning is enabled or disabled.
    bool public burningEnabled;

    /// @dev Error thrown when minting is disabled.
    error MintingDisabled();

    /// @dev Error thrown when burning is disabled.
    error BurningDisabled();

    /// @notice Initializes the contract with an empty URI.
    constructor() ERC1155("") {
        address sender = _msgSender();
        _grantRole(DEFAULT_ADMIN_ROLE, sender);
        _grantRole(MINTER_ROLE, sender);
        _grantRole(BURNER_ROLE, sender);
    }

    /// @notice Mints a specified amount of tokens to a given address.
    /// @param to The address to mint tokens to.
    /// @param id The ID of the token to mint.
    /// @param value The amount of tokens to mint.
    function mint(address to, uint256 id, uint256 value) external virtual onlyRole(MINTER_ROLE) {
        if (!mintingEnabled) {
            revert MintingDisabled();
        }
        _mint(to, id, value, abi.encodePacked(""));
    }

    /// @notice Toggles the minting enabled/disabled state.
    function toggleMinting() external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintingEnabled = !mintingEnabled;
    }

    /// @notice Toggles the burning enabled/disabled state.
    function toggleBurning() external onlyRole(DEFAULT_ADMIN_ROLE) {
        burningEnabled = !burningEnabled;
    }

    /// @notice Burns a specified amount of tokens from a given address.
    /// @param from The address to burn tokens from.
    /// @param id The ID of the token to burn.
    /// @param value The amount of tokens to burn.
    function burn(address from, uint256 id, uint256 value) external virtual onlyRole(BURNER_ROLE) {
        if (!burningEnabled) {
            revert BurningDisabled();
        }
        _burn(from, id, value);
    }

    /// @notice Sets the base URI for all token types.
    /// @param newURI The new base URI to set.
    /// @inheritdoc ISetBaseURI
    function setBaseURI(string memory newURI) external virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newURI);
    }

    /// @notice Checks if the contract supports a given interface.
    /// @param interfaceId The interface identifier.
    /// @return True if the interface is supported.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
