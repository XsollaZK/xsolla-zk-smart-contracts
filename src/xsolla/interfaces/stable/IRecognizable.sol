// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

/// @title IRecognizable
/// @author Oleg Bedrin - Xsolla Web3 <o.bedrin@xsolla.com>.
interface IRecognizable {
    /// @notice Returns the name of the contract.
    function name() external view returns (string memory);
}
