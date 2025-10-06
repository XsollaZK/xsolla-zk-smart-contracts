// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

/// @title WETH Interface
/// @notice Interface for interacting with Wrapped Ether (WETH) contracts
/// @dev Defines the minimal interface needed for WETH withdrawal operations
interface IWETH {
    /// @notice Withdraws WETH tokens and converts them back to ETH
    /// @dev Burns the specified amount of WETH tokens and sends equivalent ETH to the caller
    /// @param wad The amount of WETH tokens to withdraw (in wei)
    function withdraw(uint256 wad) external;
}
