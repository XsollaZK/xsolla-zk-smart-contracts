// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Ownable } from '@openzeppelin-contracts-5.4.0/access/Ownable.sol';

import { ERC20Modular } from './extensions/ERC20Modular.sol';

/// @title ERC20Factory
/// @author Oleg Bedrin <o.bedrin@xsolla.com> - Xsolla Web3
/// @notice A factory contract for deploying ERC20Modular tokens with role-based access control.
contract ERC20Factory is Ownable {
    /// @notice Emitted when a new ERC20 token is deployed.
    /// @param newTokenAddress The address of the newly deployed ERC20 token.
    event NewERC20Deployed(address indexed newTokenAddress);

    /// @notice The constructor sets the initial owner to the deployer.
    constructor() Ownable(_msgSender()) {}

    /// @notice Deploys a new ERC20Modular token with the specified parameters.
    /// @param name The name of the token.
    /// @param symbol The symbol of the token.
    /// @param defaultAdmin The address to be granted DEFAULT_ADMIN_ROLE.
    /// @param pauser The address to be granted PAUSER_ROLE.
    /// @param minter The address to be granted MINTER_ROLE.
    function deployERC20(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser,
        address minter
    ) external onlyOwner {
        ERC20Modular token = new ERC20Modular(
            name,
            symbol,
            defaultAdmin,
            pauser,
            minter
        );
        emit NewERC20Deployed(address(token));
    }
}
