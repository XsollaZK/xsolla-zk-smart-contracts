// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { EnumerableSet } from "@openzeppelin-contracts-5.4.0/utils/structs/EnumerableSet.sol";
import { AccessControl } from "@openzeppelin-contracts-5.4.0/access/AccessControl.sol";

/// @title AddressesReportConfig
/// @author Oleg Bedrin - Xsolla Web3 <o.bedrin@xsolla.com>
/// @notice A contract for managing external network and contract deployment reports
/// @dev This contract allows maintainers to create, update, and manage reports of deployed contracts across different networks
contract AddressesReportConfig is AccessControl {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice Represents a network report containing multiple contract reports
    /// @dev Uses EnumerableSet for efficient contract ID management
    struct NetworkReport {
        uint256 contractReportsIdCounter;
        string name;
        string explorerUrl;
        EnumerableSet.UintSet contractsIds;
        mapping(uint256 contractReportId => ContractReport) contractReports;
    }

    /// @notice Represents a single contract deployment report
    struct ContractReport {
        address addr;
        string name;
        string artifact;
    }

    /// @notice Public view structure for network report information
    struct NetworkReportInfo {
        string name;
        string explorerUrl;
        uint256[] contractIds;
    }

    /// @notice Public view structure for contract report data
    struct ContractReportData {
        address addr;
        string name;
        string artifact;
    }

    /// @notice Aggregated data structure for all contracts in a network
    struct AllContractReportsData {
        uint256[] contractIds;
        string[] names;
        string[] artifacts;
        address[] addresses;
    }

    /// @notice Thrown when trying to access a non-existent network report
    /// @param networkReportId The ID of the network report that was not found
    error NetworkReportNotFound(uint256 networkReportId);
    
    /// @notice Thrown when trying to access a non-existent contract report
    /// @param networkReportId The ID of the network report
    /// @param contractReportId The ID of the contract report that was not found
    error ContractReportNotFound(uint256 networkReportId, uint256 contractReportId);

    /// @notice Thrown when no network report is found with the given name
    /// @param name The name of the network that was not found
    error NetworkReportNotFoundByName(string name);

    /// @notice Thrown when no contract report is found with the given name in the specified network
    /// @param networkReportId The ID of the network report
    /// @param name The name of the contract that was not found
    error ContractReportNotFoundByName(uint256 networkReportId, string name);

    /// @notice Role identifier for accounts that can maintain reports
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    /// @notice Counter for generating unique network report IDs
    uint256 public networkReportsIdCounter;
    
    /// @dev Set of all active network report IDs
    EnumerableSet.UintSet internal networkReportsIds;
    
    /// @notice Mapping from network report ID to NetworkReport struct
    mapping(uint256 networkReportId => NetworkReport) internal _networkReports;    

    /// @notice Emitted when a new network report is created
    /// @param networkReportId The ID of the created network report
    /// @param name The name of the network
    /// @param explorerUrl The blockchain explorer URL for the network
    event NetworkReportCreated(uint256 indexed networkReportId, string name, string explorerUrl);
    
    /// @notice Emitted when an existing network report is updated
    /// @param networkReportId The ID of the updated network report
    /// @param name The updated name of the network
    /// @param explorerUrl The updated blockchain explorer URL for the network
    event NetworkReportUpdated(uint256 indexed networkReportId, string name, string explorerUrl);
    
    /// @notice Emitted when a network report is removed
    /// @param networkReportId The ID of the removed network report
    event NetworkReportRemoved(uint256 indexed networkReportId);
    
    /// @notice Emitted when a new contract report is added to a network
    /// @param networkReportId The ID of the network report
    /// @param contractReportId The ID of the added contract report
    /// @param name The name of the contract
    /// @param artifact The artifact name of the contract
    /// @param addr The deployed address of the contract
    event ContractReportAdded(uint256 indexed networkReportId, uint256 indexed contractReportId, string name, string artifact, address addr);
    
    /// @notice Emitted when an existing contract report is updated
    /// @param networkReportId The ID of the network report
    /// @param contractReportId The ID of the updated contract report
    /// @param name The updated name of the contract
    /// @param artifact The updated artifact name of the contract
    /// @param addr The updated deployed address of the contract
    event ContractReportUpdated(uint256 indexed networkReportId, uint256 indexed contractReportId, string name, string artifact, address addr);
    
    /// @notice Emitted when a contract report is removed from a network
    /// @param networkReportId The ID of the network report
    /// @param contractReportId The ID of the removed contract report
    event ContractReportRemoved(uint256 indexed networkReportId, uint256 indexed contractReportId);

    /// @notice Initializes the contract and sets up roles for the deployer
    /// @dev Grants both DEFAULT_ADMIN_ROLE and MAINTAINER_ROLE to the contract deployer
    constructor() {
        address sender = _msgSender();
        _grantRole(DEFAULT_ADMIN_ROLE, sender);
        _grantRole(MAINTAINER_ROLE, sender);
    }

    /// @notice Creates a new network report or updates an existing one
    /// @dev If _networkReportId is 0 or doesn't exist, creates a new report. Otherwise updates existing.
    /// @param _networkReportId The ID of the network report to update (0 for new report)
    /// @param _name The name of the network
    /// @param _explorerUrl The blockchain explorer URL for the network
    /// @return networkReportId The ID of the created or updated network report
    function insertNetworkReport(uint256 _networkReportId, string memory _name, string memory _explorerUrl) 
        external 
        onlyRole(MAINTAINER_ROLE) 
        returns (uint256 networkReportId) 
    {
        bool isUpdate = _networkReportId != 0 && networkReportsIds.contains(_networkReportId);
        
        if (isUpdate) {
            networkReportId = _networkReportId;
        } else {
            networkReportId = ++networkReportsIdCounter;
            networkReportsIds.add(networkReportId);
        }
        
        NetworkReport storage report = _networkReports[networkReportId];
        report.name = _name;
        report.explorerUrl = _explorerUrl;
        
        if (isUpdate) {
            emit NetworkReportUpdated(networkReportId, _name, _explorerUrl);
        } else {
            emit NetworkReportCreated(networkReportId, _name, _explorerUrl);
        }
    }

    /// @notice Creates a new contract report or updates an existing one within a network
    /// @dev If _contractReportId is 0 or doesn't exist, creates a new report. Otherwise updates existing.
    /// @param _networkReportId The ID of the network report to add the contract to
    /// @param _contractReportId The ID of the contract report to update (0 for new report)
    /// @param _name The name of the contract
    /// @param _artifact The artifact name of the contract
    /// @param _addr The deployed address of the contract
    /// @return contractReportId The ID of the created or updated contract report
    function insertContractReport(
        uint256 _networkReportId,
        uint256 _contractReportId,
        string memory _name, 
        string memory _artifact, 
        address _addr
    ) external onlyRole(MAINTAINER_ROLE) returns (uint256 contractReportId) {
        if (!networkReportsIds.contains(_networkReportId)) {
            revert NetworkReportNotFound(_networkReportId);
        }
        
        NetworkReport storage networkReport = _networkReports[_networkReportId];
        bool isUpdate = _contractReportId != 0 && networkReport.contractsIds.contains(_contractReportId);
        
        if (isUpdate) {
            contractReportId = _contractReportId;
        } else {
            contractReportId = ++networkReport.contractReportsIdCounter;
            networkReport.contractsIds.add(contractReportId);
        }
        
        ContractReport storage contractReport = networkReport.contractReports[contractReportId];
        contractReport.addr = _addr;
        contractReport.name = _name;
        contractReport.artifact = _artifact;
        
        if (isUpdate) {
            emit ContractReportUpdated(_networkReportId, contractReportId, _name, _artifact, _addr);
        } else {
            emit ContractReportAdded(_networkReportId, contractReportId, _name, _artifact, _addr);
        }
    }

    /// @notice Returns all network report IDs
    /// @return Array of all network report IDs
    function getAllNetworkReportIds() external view returns (uint256[] memory) {
        return networkReportsIds.values();
    }

    /// @notice Gets basic information about a network report
    /// @param _networkReportId The ID of the network report
    /// @return info NetworkReportInfo struct containing name, explorer URL, and contract IDs
    function getNetworkReportInfo(uint256 _networkReportId) 
        external 
        view 
        returns (NetworkReportInfo memory info) 
    {
        if (!networkReportsIds.contains(_networkReportId)) {
            revert NetworkReportNotFound(_networkReportId);
        }
        NetworkReport storage report = _networkReports[_networkReportId];
        info = NetworkReportInfo({
            name: report.name,
            explorerUrl: report.explorerUrl,
            contractIds: report.contractsIds.values()
        });
    }

    /// @notice Gets the network report ID by network name
    /// @param _name The name of the network to search for
    /// @return networkReportId The ID of the network report with the matching name
    function getNetworkIdByName(string memory _name) external view returns (uint256 networkReportId) {
        uint256[] memory networkIds = networkReportsIds.values();
        
        for (uint256 i = 0; i < networkIds.length; ++i) {
            if (keccak256(bytes(_networkReports[networkIds[i]].name)) == keccak256(bytes(_name))) {
                return networkIds[i];
            }
        }
    }

    /// @notice Gets the contract report ID by contract name within a specific network
    /// @param _networkReportId The ID of the network report to search in
    /// @param _name The name of the contract to search for
    /// @return contractReportId The ID of the contract report with the matching name
    function getContractIdByName(uint256 _networkReportId, string memory _name) external view returns (uint256 contractReportId) {
        if (!networkReportsIds.contains(_networkReportId)) {
            revert NetworkReportNotFound(_networkReportId);
        }
        
        NetworkReport storage networkReport = _networkReports[_networkReportId];
        uint256[] memory contractIds = networkReport.contractsIds.values();
        
        for (uint256 i = 0; i < contractIds.length; ++i) {
            if (keccak256(bytes(networkReport.contractReports[contractIds[i]].name)) == keccak256(bytes(_name))) {
                return contractIds[i];
            }
        }
    }

    /// @notice Gets detailed information about a specific contract report
    /// @param _networkReportId The ID of the network report
    /// @param _contractReportId The ID of the contract report
    /// @return data ContractReportData struct containing address, name, and artifact
    function getContractReport(uint256 _networkReportId, uint256 _contractReportId) 
        external 
        view 
        returns (ContractReportData memory data) 
    {
        if (!networkReportsIds.contains(_networkReportId)) {
            revert NetworkReportNotFound(_networkReportId);
        }
        NetworkReport storage networkReport = _networkReports[_networkReportId];
        if (!networkReport.contractsIds.contains(_contractReportId)) {
            revert ContractReportNotFound(_networkReportId, _contractReportId);
        }
        
        ContractReport storage contractReport = networkReport.contractReports[_contractReportId];
        data = ContractReportData({
            addr: contractReport.addr,
            name: contractReport.name,
            artifact: contractReport.artifact
        });
    }

    /// @notice Gets all contract reports for a specific network
    /// @param _networkReportId The ID of the network report
    /// @return data AllContractReportsData struct containing arrays of all contract data
    function getAllContractReports(uint256 _networkReportId) 
        external 
        view 
        returns (AllContractReportsData memory data) 
    {
        if (!networkReportsIds.contains(_networkReportId)) {
            revert NetworkReportNotFound(_networkReportId);
        }
        NetworkReport storage networkReport = _networkReports[_networkReportId];
        
        data.contractIds = networkReport.contractsIds.values();
        uint256 length = data.contractIds.length;
        
        data.names = new string[](length);
        data.artifacts = new string[](length);
        data.addresses = new address[](length);
        
        for (uint256 i = 0; i < length; ++i) {
            ContractReport storage report = networkReport.contractReports[data.contractIds[i]];
            data.names[i] = report.name;
            data.artifacts[i] = report.artifact;
            data.addresses[i] = report.addr;
        }
    }

    /// @notice Returns the total number of network reports
    /// @return The count of network reports
    function getNetworkReportCount() external view returns (uint256) {
        return networkReportsIds.length();
    }

    /// @notice Returns the number of contract reports in a specific network
    /// @param _networkReportId The ID of the network report
    /// @return The count of contract reports in the network
    function getContractReportCount(uint256 _networkReportId) external view returns (uint256) {
        if (!networkReportsIds.contains(_networkReportId)) {
            revert NetworkReportNotFound(_networkReportId);
        }
        return _networkReports[_networkReportId].contractsIds.length();
    }
}