// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

library AccountIdsLib {
    function getAccountId(address firstOwner) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(firstOwner));
    }
}