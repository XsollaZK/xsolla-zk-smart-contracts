// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Ownable } from '@openzeppelin-contracts-5.4.0/access/Ownable.sol';

import { ERC20Modular } from './extensions/ERC20Modular.sol';

/// @title ERC20Claimer
/// @author Oleg Bedrin <o.bedrin@xsolla.com> - Xsolla Web3
/// @notice Allows users to claim a fixed amount of ERC20 tokens once.
/// @dev Only the owner can set the claim amount.
contract ERC20Claimer is Ownable {
    /// @notice Tracks whether an address has already claimed tokens.
    mapping(address claimer => bool claimedStatus) public isClaimed;

    /// @notice The ERC20 token that can be claimed.
    ERC20Modular public tokenToClaim;

    /// @notice The amount of tokens to be claimed per user.
    uint256 public amountToClaim;

    /// @notice Emitted when a user successfully claims tokens.
    /// @param claimer The address that claimed tokens.
    /// @param amount The amount of tokens claimed.
    event Claimed(address indexed claimer, uint256 indexed amount);

    /// @notice Error thrown when an address tries to claim more than once.
    /// @param claimer The address that has already claimed.
    error AlreadyClaimed(address claimer);

    /// @notice Initializes the contract with the token to be claimed.
    /// @param _tokenToClaim The ERC20 token contract address.
    constructor(ERC20Modular _tokenToClaim) Ownable(_msgSender()) {
        tokenToClaim = _tokenToClaim;
        amountToClaim = 100 ether;
    }

    /// @notice Sets the amount of tokens that can be claimed per user.
    /// @dev Only callable by the contract owner.
    /// @param _amountToClaim The new claim amount.
    function setAmountToClaim(uint256 _amountToClaim) external onlyOwner {
        amountToClaim = _amountToClaim;
    }

    /// @notice Claims the specified amount of tokens for the sender.
    /// @dev Can only be called once per address.
    /// @param _recipient Recipient of the claim.
    function claimFor(address _recipient) external {
        _claim(_recipient);
    }

    /// @notice Claims the specified amount of tokens for the sender.
    /// @dev Can only be called once per address.
    function claim() external {
        _claim(_msgSender());
    }

    /// @dev Internal function to handle the claiming logic.
    /// @param _recipient The address that will receive the claimed tokens.
    function _claim(address _recipient) internal {
        if (isClaimed[_recipient]) {
            revert AlreadyClaimed(_recipient);
        }
        tokenToClaim.mint(_recipient, amountToClaim);
        isClaimed[_recipient] = true;
        emit Claimed(_recipient, amountToClaim);
    }
}
