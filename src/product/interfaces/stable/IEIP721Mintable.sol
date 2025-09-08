// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

/// @title IEIP721Mintable.
/// @author Oleg Bedrin - Xsolla Web3 <o.bedrin@xsolla.com>.
/// @notice Interface for mintable EIP721-compliant contracts.
interface IEIP721Mintable {
    /// @notice Mints a new token to the specified recipient.
    /// @dev The caller must have the appropriate permissions to mint.
    /// @param recipient The address that will receive the minted token.
    function mint(address recipient) external payable;
}
