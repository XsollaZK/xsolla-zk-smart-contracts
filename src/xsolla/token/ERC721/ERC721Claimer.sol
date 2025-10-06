// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ERC721Modular } from "./extensions/ERC721Modular.sol";

/// @title ERC721Claimer
/// @author Oleg Bedrin <o.bedrin@xsolla.com> - Xsolla Web3
/// @notice Allows users to claim a fixed amount of ERC721 tokens once.
/// @dev Only the owner can set the claim amount. Be mindful of gas limits for large claim amounts.
contract ERC721Claimer is Ownable {
    /// @notice Tracks whether an address has already claimed tokens.
    mapping(address claimer => bool claimedStatus) public isClaimed;

    /// @notice The ERC721 token that can be claimed.
    ERC721Modular public tokenToClaim;

    /// @notice The amount of tokens to be claimed per user.
    uint256 public amountToClaim;

    /// @notice Emitted when a user successfully claims tokens.
    /// @param claimer The address that claimed tokens.
    /// @param amount The amount of tokens claimed.
    event Claimed(address indexed claimer, uint256 indexed amount);

    /// @notice Error thrown when an address tries to claim more than once.
    /// @param claimer The address that has already claimed.
    error AlreadyClaimed(address claimer);

    /// @notice Error thrown when trying to set claim amount to zero.
    error InvalidClaimAmount();

    /// @notice Error thrown when token address is zero.
    error InvalidTokenAddress();

    /// @notice Initializes the contract with the token to be claimed.
    /// @param _tokenToClaim The ERC721 token contract address.
    constructor(ERC721Modular _tokenToClaim) Ownable(_msgSender()) {
        if (address(_tokenToClaim) == address(0)) {
            revert InvalidTokenAddress();
        }
        tokenToClaim = _tokenToClaim;
        amountToClaim = 1;
    }

    /// @notice Sets the amount of tokens that can be claimed per user.
    /// @dev Only callable by the contract owner. Consider gas limits for large amounts.
    /// @param _amountToClaim The new claim amount.
    function setAmountToClaim(uint256 _amountToClaim) external onlyOwner {
        if (_amountToClaim == 0) {
            revert InvalidClaimAmount();
        }
        amountToClaim = _amountToClaim;
    }

    /// @notice Claims the specified amount of tokens for the sender.
    /// @dev Can only be called once per address.
    function claim() external {
        address sender = _msgSender();
        if (isClaimed[sender]) {
            revert AlreadyClaimed(sender);
        }
        for (uint256 i = 0; i < amountToClaim; i++) {
            tokenToClaim.mint(sender);
        }
        isClaimed[sender] = true;
        emit Claimed(sender, amountToClaim);
    }
}
