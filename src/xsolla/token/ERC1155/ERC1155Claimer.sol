// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ERC1155Modular } from "./extensions/ERC1155Modular.sol";

/// @title ERC1155Claimer
/// @author Oleg Bedrin <o.bedrin@xsolla.com> - Xsolla Web3
/// @notice Allows users to claim a fixed amount of ERC1155 tokens once.
/// @dev Only the owner can set the claim amount and token ID.
contract ERC1155Claimer is Ownable {
    /// @notice Tracks whether an address has already claimed tokens.
    mapping(address claimer => bool claimedStatus) public isClaimed;

    /// @notice The ERC1155 token that can be claimed.
    ERC1155Modular public tokenToClaim;

    /// @notice The amount of tokens to be claimed per user.
    uint256 public amountToClaim;

    /// @notice The token ID to be claimed per user.
    uint256 public tokenIdToClaim;

    /// @notice Emitted when a user successfully claims tokens.
    /// @param claimer The address that claimed tokens.
    /// @param tokenId The token ID that was claimed.
    /// @param amount The amount of tokens claimed.
    event Claimed(address indexed claimer, uint256 indexed tokenId, uint256 indexed amount);

    /// @notice Error thrown when an address tries to claim more than once.
    /// @param claimer The address that has already claimed.
    error AlreadyClaimed(address claimer);

    /// @notice Initializes the contract with the token to be claimed.
    /// @param _tokenToClaim The ERC1155 token contract address.
    constructor(ERC1155Modular _tokenToClaim) Ownable(_msgSender()) {
        tokenToClaim = _tokenToClaim;
        tokenIdToClaim = 0;
        amountToClaim = 100 ether;
    }

    /// @notice Sets the amount of tokens that can be claimed per user.
    /// @dev Only callable by the contract owner.
    /// @param _amountToClaim The new claim amount.
    function setAmountToClaim(uint256 _amountToClaim) external onlyOwner {
        amountToClaim = _amountToClaim;
    }

    /// @notice Sets the token ID that can be claimed.
    /// @dev Only callable by the contract owner.
    /// @param _tokenIdToClaim The new token ID to claim.
    function setTokenIdToClaim(uint256 _tokenIdToClaim) external onlyOwner {
        tokenIdToClaim = _tokenIdToClaim;
    }

    /// @notice Claims the specified amount of tokens for the sender.
    /// @dev Can only be called once per address.
    function claim() external {
        address sender = _msgSender();
        if (isClaimed[sender]) {
            revert AlreadyClaimed(sender);
        }
        tokenToClaim.mint(sender, tokenIdToClaim, amountToClaim);
        isClaimed[sender] = true;
        emit Claimed(sender, tokenIdToClaim, amountToClaim);
    }
}
