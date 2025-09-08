// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

/// @title Faucet
/// @author Oleg Bedrin <o.bedrin@xsolla.com> - Xsolla Web3, Gleb Zverev <g.zverev@xsolla.com>
/// @dev A contract that allows users to claim a fixed amount of ETH once per day
/// @notice This faucet distributes ETH to users with time-based rate limiting
contract Faucet is Ownable {
    using Address for address payable;

    /// @dev Struct to represent faucet availability status
    struct FaucetAvailability {
        bool available;
        string reason;
    }

    /// @dev Emitted when ETH is successfully sent to a destination address
    event Sent(address destination, uint256 value);
    /// @dev Emitted when the owner withdraws contract balance
    event Withdraw(address owner, uint256 value);
    /// @dev Emitted when the faucet portion amount is changed
    event PortionChanged(uint256 prevPortion, uint256 newPortion);

    /// @dev Thrown when user tries to claim before 24 hours have passed
    error ClaimNotAllowedYet();
    /// @dev Thrown when sent value doesn't match the required portion
    error InvalidPortionAmount();
    /// @dev Thrown when contract has no balance to withdraw
    error NothingToWithdraw();
    /// @dev Thrown when new portion is the same as current portion
    error SamePortionValue();

    /// @notice The amount of ETH that can be claimed per request
    uint256 public portion = 0.001 ether;
    /// @notice Mapping to track the last claim timestamp for each address
    mapping(address => uint256) public lastClaimed;

    /// @notice Initializes the contract with the owner set to the deployer
    constructor() Ownable(_msgSender()) {}

    /// @notice Allows users to claim ETH from the faucet
    /// @dev Users must send exact portion amount and wait 24 hours between claims
    /// @param destination The address that will receive the ETH
    function faucet(address destination) public payable {
        if (msg.value != portion) {
            revert InvalidPortionAmount();
        }
        FaucetAvailability memory availability = availableToFaucet(destination);
        if (!availability.available) {
            revert ClaimNotAllowedYet();
        }
        lastClaimed[destination] = block.timestamp;
        payable(destination).sendValue(msg.value);
        emit Sent(destination, msg.value);
    }

    /// @notice Checks if an address is eligible to claim from the faucet
    /// @param destination The address to check eligibility for
    /// @return availability Struct containing availability status and reason
    function availableToFaucet(
        address destination
    ) public view returns (FaucetAvailability memory availability) {
        if (block.timestamp <= lastClaimed[destination] + 24 hours) {
            return FaucetAvailability(false, "Claim not allowed yet");
        }
        return FaucetAvailability(true, "");
    }

    /// @notice Allows the owner to withdraw all ETH from the contract
    /// @dev Only callable by the contract owner
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert NothingToWithdraw();
        }
        payable(msg.sender).sendValue(balance);
        emit Withdraw(msg.sender, balance);
    }

    /// @notice Allows the owner to change the faucet portion amount
    /// @dev Only callable by the contract owner
    /// @param newPortion The new portion amount in wei
    function changePortion(uint256 newPortion) external onlyOwner {
        if (portion == newPortion) {
            revert SamePortionValue();
        }
        emit PortionChanged(portion, newPortion);
        portion = newPortion;
    }
}