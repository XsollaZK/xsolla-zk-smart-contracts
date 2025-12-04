// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

interface IConfiguration {
    function name() external view returns (string memory);
    function startAutowiringSources() external;
}
