# Token Deployment Scripts Guide

This guide explains how to use the customizable deployment scripts for ERC20, ERC721, ERC1155 tokens, and AddressesReportConfig.

## Overview

All deployment scripts now support full customization through configuration structs and multiple deployment functions:

- **EIP20.s.sol** - ERC20 token deployment
- **EIP721.s.sol** - NFT (ERC721) deployment  
- **EIP1155.s.sol** - Multi-token (ERC1155) deployment
- **Reports.s.sol** - AddressesReportConfig deployment
- **NativeCurrency.s.sol** - WETH9 and Faucet deployment
- **SeaportFeesCollectors.s.sol** - Fee collector contracts deployment

## Usage Patterns

### 1. Default Deployment
```bash
forge script script/EIP20.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
forge script script/EIP721.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
forge script script/EIP1155.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
forge script script/Reports.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
forge script script/NativeCurrency.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
forge script script/SeaportFeesCollectors.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

### 2. Custom Deployment via Forge Script
You can create custom deployment scripts that import and configure these contracts:

```solidity
// Example: CustomERC20Deploy.s.sol
import "./EIP20.s.sol";

contract CustomERC20Deploy is Script {
    function run() external {
        EIP20 deployer = new EIP20();
        deployer.deployWithCustomConfig(
            "My Custom Token",     // name
            "MCT",                // symbol
            0x123...abc,          // defaultAdmin
            0x456...def,          // pauser  
            0x789...ghi,          // minter
            1000 ether            // claimAmount
        );
    }
}
```

## ERC20 (EIP20.s.sol)

### Configuration Options
```solidity
struct ERC20Config {
    string name;           // Token name
    string symbol;         // Token symbol
    address defaultAdmin;  // DEFAULT_ADMIN_ROLE holder
    address pauser;        // PAUSER_ROLE holder
    address minter;        // MINTER_ROLE holder
    uint256 claimAmount;   // Amount users can claim (in wei)
}
```

### Default Configuration
- **Name**: "Xsolla Token"
- **Symbol**: "XSOLLA"
- **Admin/Pauser/Minter**: `msg.sender`
- **Claim Amount**: 100 tokens (100 ether)

### Deployment Functions
1. `deployWithDefaults()` - Uses default configuration
2. `deployWithCustomConfig(...)` - Full customization
3. `run()` - Default function for forge script

### Example Custom Deployment
```solidity
// Deploy with custom parameters
deployer.deployWithCustomConfig(
    "Xsolla Game Token",           // name
    "XGT",                        // symbol
    0x1234567890123456789012345678901234567890,  // defaultAdmin
    0x2345678901234567890123456789012345678901,  // pauser
    0x3456789012345678901234567890123456789012,  // minter
    50 ether                      // claimAmount (50 tokens)
);
```

## ERC721 (EIP721.s.sol)

### Configuration Options
```solidity
struct ERC721Config {
    string name;                    // Collection name
    string symbol;                  // Collection symbol
    uint256 maxSupply;             // Maximum NFTs that can be minted
    string ipfsDefaultImage;       // Default IPFS image hash
    SVGIconsLib.Field[8] defaultFields;  // SVG metadata fields
    uint256 claimAmount;           // NFTs users can claim
    bool enableMinting;            // Enable/disable minting
    bool enableSvg;                // Enable/disable SVG generation
    string baseURI;                // Base URI for metadata
}
```

### Default Configuration
- **Name**: "Xsolla NFT Collection"
- **Symbol**: "XSOLLA_NFT" 
- **Max Supply**: 10,000
- **Claim Amount**: 1 NFT
- **Minting**: Enabled
- **SVG**: Disabled
- **IPFS Image**: "bafkreie7ohywtosou76tasm7j63yigtzxe7d5zqus4zu3j6oltvgtibeom"

### Deployment Functions
1. `deployWithDefaults()` - Uses default configuration
2. `deployWithCustomConfig(...)` - Full customization
3. `deployWithBasicConfig(...)` - Basic customization (name, symbol, supply, claim amount)
4. `run()` - Default function for forge script

### Example Custom Deployment
```solidity
// Basic customization
deployer.deployWithBasicConfig(
    "Epic Game NFTs",    // name
    "EPIC",             // symbol
    5000,               // maxSupply
    3                   // claimAmount
);

// Full customization with custom SVG fields
SVGIconsLib.Field[8] memory customFields = [
    SVGIconsLib.Field('Game: ', 'Epic Adventure', 'none'),
    SVGIconsLib.Field('Rarity: ', 'Legendary', 'none'),
    SVGIconsLib.Field('Power: ', '9000', 'none'),
    SVGIconsLib.Field('Element: ', 'Fire', 'none'),
    SVGIconsLib.Field('', '', 'none'),
    SVGIconsLib.Field('', '', 'none'),
    SVGIconsLib.Field('', '', 'none'),
    SVGIconsLib.Field('', '', 'none')
];

deployer.deployWithCustomConfig(
    "Epic Game NFTs",                                    // name
    "EPIC",                                             // symbol
    5000,                                               // maxSupply
    "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi", // ipfsDefaultImage
    customFields,                                       // defaultFields
    3,                                                  // claimAmount
    true,                                              // enableMinting
    true,                                              // enableSvg
    "https://api.epicgame.com/metadata/"               // baseURI
);
```

## ERC1155 (EIP1155.s.sol)

### Configuration Options
```solidity
struct ERC1155Config {
    string baseURI;          // Base URI for token metadata
    uint256 claimAmount;     // Amount of tokens users can claim
    uint256 tokenIdToClaim;  // Token ID that users can claim
    bool enableMinting;      // Enable/disable minting
    bool enableBurning;      // Enable/disable burning
}
```

### Default Configuration
- **Base URI**: "https://api.xsolla.com/metadata/"
- **Claim Amount**: 100 tokens (100 ether)
- **Token ID to Claim**: 0
- **Minting**: Enabled
- **Burning**: Enabled

### Deployment Functions
1. `deployWithDefaults()` - Uses default configuration
2. `deployWithCustomConfig(...)` - Full customization
3. `deployWithBasicConfig(...)` - Basic customization (URI, claim amount, token ID)
4. `run()` - Default function for forge script

### Example Custom Deployment
```solidity
// Basic customization
deployer.deployWithBasicConfig(
    "https://api.mygame.com/tokens/",  // baseURI
    500 ether,                         // claimAmount (500 tokens)
    1                                  // tokenIdToClaim
);

// Full customization
deployer.deployWithCustomConfig(
    "https://api.mygame.com/tokens/",  // baseURI
    500 ether,                         // claimAmount
    1,                                 // tokenIdToClaim
    true,                             // enableMinting
    false                             // enableBurning (disabled)
);
```

## AddressesReportConfig (Reports.s.sol)

### Configuration Options
```solidity
struct ReportsConfig {
    address defaultAdmin;          // DEFAULT_ADMIN_ROLE holder
    address maintainer;            // MAINTAINER_ROLE holder
    bool setupInitialNetworks;     // Whether to create initial networks
    NetworkConfig[] initialNetworks;  // Initial network configurations
}

struct NetworkConfig {
    string name;                   // Network name
    string explorerUrl;           // Blockchain explorer URL
    ContractConfig[] contracts;   // Initial contracts for this network
}

struct ContractConfig {
    string name;                  // Contract name
    string artifact;             // Contract artifact name
    address addr;                // Contract address
}
```

### Default Configuration
- **Default Admin**: `msg.sender`
- **Maintainer**: `msg.sender`
- **Setup Initial Networks**: `true`
- **Initial Networks**: 
  - Ethereum Mainnet (https://etherscan.io)
  - ZK Sync Era (https://explorer.zksync.io)
  - Sepolia Testnet (https://sepolia.etherscan.io)

### Deployment Functions
1. `deployWithDefaults()` - Uses default configuration with 3 networks
2. `deployWithCustomConfig(...)` - Full customization
3. `deployWithBasicConfig(...)` - Basic customization (admin, maintainer)
4. `deployEmpty()` - Deploy without initial networks
5. `run()` - Default function for forge script

### Helper Functions
1. `addNetwork(name, explorerUrl)` - Add network after deployment
2. `addContract(networkId, name, artifact, addr)` - Add contract to existing network

### Example Custom Deployment
```solidity
// Basic customization
deployer.deployWithBasicConfig(
    0x1234567890123456789012345678901234567890,  // defaultAdmin
    0x2345678901234567890123456789012345678901   // maintainer
);

// Deploy empty (no initial networks)
deployer.deployEmpty();

// Add custom networks after deployment
uint256 polygonId = deployer.addNetwork(
    "Polygon Mainnet",
    "https://polygonscan.com"
);

// Add contracts to network
deployer.addContract(
    polygonId,
    "MyToken",
    "ERC20Modular",
    0x3456789012345678901234567890123456789012
);

// Full customization with initial networks and contracts
NetworkConfig[] memory networks = new NetworkConfig[](1);
ContractConfig[] memory contracts = new ContractConfig[](2);

contracts[0] = ContractConfig({
    name: "GameToken",
    artifact: "ERC20Modular", 
    addr: 0x1111111111111111111111111111111111111111
});

contracts[1] = ContractConfig({
    name: "GameNFT",
    artifact: "ERC721Modular",
    addr: 0x2222222222222222222222222222222222222222
});

networks[0] = NetworkConfig({
    name: "Custom Network",
    explorerUrl: "https://custom.explorer.com",
    contracts: contracts
});

deployer.deployWithCustomConfig(
    0x1234567890123456789012345678901234567890,  // defaultAdmin
    0x2345678901234567890123456789012345678901,  // maintainer
    true,                                        // setupInitialNetworks
    networks                                     // initialNetworks
);
```

## Deployed Contracts

Each script deploys different contracts:

### For ERC20:
1. **ERC20Factory** - Factory for deploying new ERC20 tokens
2. **ERC20Modular** - The actual ERC20 token with roles and features
3. **ERC20Claimer** - Contract allowing users to claim tokens once

### For ERC721:
1. **ERC721Factory** - Factory for deploying new NFT collections
2. **ERC721Modular** - The actual NFT collection with metadata and SVG support
3. **ERC721Claimer** - Contract allowing users to claim NFTs once

### For ERC1155:
1. **ERC1155Factory** - Factory for deploying new multi-token collections
2. **ERC1155Modular** - The actual multi-token contract
3. **ERC1155Claimer** - Contract allowing users to claim tokens once

### For Reports:
1. **AddressesReportConfig** - Contract for managing deployment reports across networks

## AddressesReportConfig Features

The AddressesReportConfig contract provides:

### Network Management
- Create and manage network reports (Mainnet, Testnet, L2s, etc.)
- Store network metadata (name, explorer URL)
- Track deployment status across multiple networks

### Contract Registry
- Register deployed contracts with metadata
- Track contract addresses, names, and artifacts
- Organize contracts by network
- Support for batch operations

### Access Control
- Role-based permissions (DEFAULT_ADMIN_ROLE, MAINTAINER_ROLE)
- Secure multi-user management
- Granular access control for report management

### Query Interface
- Retrieve network information by ID or name
- Get contract details by network and contract ID
- Bulk data retrieval for dashboard integration
- Support for external tooling and automation

## Native Currency (NativeCurrency.s.sol)

Deploys WETH9 (Wrapped Ether) and Faucet contracts for native currency management.

### Configuration Options
```solidity
struct FaucetConfig {
    uint256 initialPortion;    // Amount of ETH users must send to claim
    address owner;             // Owner of the faucet contract
}

struct NativeCurrencyConfig {
    bool deployWETH9;          // Whether to deploy WETH9
    bool deployFaucet;         // Whether to deploy Faucet
    FaucetConfig faucetConfig; // Faucet-specific configuration
}
```

### Available Functions
```solidity
// Deploy with defaults (both WETH9 and Faucet with 0.001 ETH portion)
function deployWithDefaults() public

// Deploy with custom configuration
function deployWithCustomConfig(NativeCurrencyConfig memory _config) public

// Deploy only WETH9 contract
function deployWETH9Only() public returns (WETH9)

// Deploy only Faucet with custom config
function deployFaucetOnly(FaucetConfig memory _faucetConfig) public returns (Faucet)

// Helper functions for interaction
function claimFromFaucet(address destination) external payable
function wrapETH(uint256 amount) external payable
function unwrapETH(uint256 amount) external
function checkFaucetAvailability(address user) external view returns (bool, string memory)
```

### Example Usage
```solidity
// Basic deployment
forge script script/NativeCurrency.s.sol --broadcast

// Custom faucet configuration
FaucetConfig memory faucetConfig = FaucetConfig({
    initialPortion: 0.01 ether,  // 0.01 ETH per claim
    owner: 0x123...abc          // Custom owner
});

NativeCurrencyConfig memory config = NativeCurrencyConfig({
    deployWETH9: true,
    deployFaucet: true,
    faucetConfig: faucetConfig
});

deployWithCustomConfig(config);
```

### WETH9 Features
- Standard wrapped Ether implementation
- Deposit ETH to get WETH tokens
- Withdraw WETH tokens to get ETH back
- Full ERC20 compatibility
- No constructor parameters required

### Faucet Features
- Rate-limited ETH distribution (24-hour cooldown)
- Configurable portion amounts
- Owner-controlled settings
- User must send exact portion amount to claim
- Pass-through mechanism (user sends ETH, gets ETH back with rate limiting)

### Important Notes
1. **Faucet Mechanism**: Users must send exactly the portion amount when claiming from the faucet
2. **Rate Limiting**: Each address can only claim once per 24 hours
3. **Owner Controls**: Faucet owner can change portion amounts and withdraw accumulated funds
4. **No Direct Funding**: The faucet doesn't need pre-funding as users provide their own ETH

## Seaport Fee Collectors (SeaportFeesCollectors.s.sol)

Deploys fee collector contracts for managing withdrawal of native tokens and ERC20 tokens, designed for use with Seaport protocol and marketplace fee collection.

### Configuration Options
```solidity
struct FeeCollectorConfig {
    address owner;              // Owner of the fee collector contract
    address operator;           // Operator address for withdrawals
    address[] withdrawalWallets; // Initial withdrawal wallet addresses
}

struct FeesCollectorsConfig {
    bool deployBaseFeeCollector;      // Whether to deploy BaseFeeCollector
    bool deployEthereumFeeCollector;  // Whether to deploy EthereumFeeCollector
    FeeCollectorConfig baseFeeConfig; // Base fee collector configuration
    FeeCollectorConfig ethFeeConfig;  // Ethereum fee collector configuration
}
```

### Available Functions
```solidity
// Deploy with defaults (both collectors with deployer as owner/operator)
function deployWithDefaults() public

// Deploy with custom configuration
function deployWithCustomConfig(FeesCollectorsConfig memory _config) public

// Deploy only BaseFeeCollector
function deployBaseFeeCollectorOnly(FeeCollectorConfig memory _config) public returns (BaseFeeCollector)

// Deploy only EthereumFeeCollector
function deployEthereumFeeCollectorOnly(FeeCollectorConfig memory _config) public returns (EthereumFeeCollector)

// Helper functions for fee collection operations
function withdrawFromBaseFeeCollector(address withdrawalWallet, uint256 amount) external
function withdrawERC20FromBaseFeeCollector(address withdrawalWallet, address tokenContract, uint256 amount) external
function unwrapAndWithdrawFromEthereumFeeCollector(address withdrawalWallet, address wrappedTokenContract, uint256 amount) external
function addWithdrawalWallet(uint8 collector, address withdrawalWallet) external
function removeWithdrawalWallet(uint8 collector, address withdrawalWallet) external
function isValidWithdrawalWallet(uint8 collector, address withdrawalWallet) external view returns (bool)
```

### Example Usage
```solidity
// Basic deployment
forge script script/SeaportFeesCollectors.s.sol --broadcast

// Custom configuration with multiple withdrawal wallets
address[] memory withdrawalWallets = new address[](2);
withdrawalWallets[0] = 0x123...abc;
withdrawalWallets[1] = 0x456...def;

FeeCollectorConfig memory config = FeeCollectorConfig({
    owner: 0x789...ghi,
    operator: 0xabc...123,
    withdrawalWallets: withdrawalWallets
});

FeesCollectorsConfig memory fullConfig = FeesCollectorsConfig({
    deployBaseFeeCollector: true,
    deployEthereumFeeCollector: true,
    baseFeeConfig: config,
    ethFeeConfig: config
});

deployWithCustomConfig(fullConfig);
```

### BaseFeeCollector Features
- Withdraw native tokens (ETH) from the contract
- Withdraw any ERC20 tokens from the contract
- Owner/operator role-based access control
- Allowlisted withdrawal wallet system
- Designed for beacon proxy implementation pattern

### EthereumFeeCollector Features
- Inherits all BaseFeeCollector functionality
- Additional WETH unwrapping capability
- Unwrap WETH and transfer ETH to withdrawal wallets
- Optimized for Ethereum mainnet fee collection workflows

### Access Control Model
1. **Owner**: Full administrative control, can manage operators and withdrawal wallets
2. **Operator**: Can execute withdrawals to allowlisted wallets
3. **Withdrawal Wallets**: Allowlisted addresses that can receive withdrawn funds

### Security Features
- Role-based access control with owner and operator separation
- Allowlisted withdrawal wallets prevent unauthorized fund extraction
- Safe token transfer mechanisms with proper error handling
- Support for both native tokens and ERC20 tokens

### Integration with Seaport
These fee collectors are designed to work with the Seaport protocol for marketplace fee collection:
- Collect fees from NFT sales and transfers
- Batch withdrawal operations for gas efficiency
- Support for multiple token types in a single transaction
- Flexible withdrawal wallet management for different fee recipients

## Gas Usage

Approximate gas costs for deployments:

- **ERC20**: ~4.26M gas
- **ERC721**: ~8.54M gas (higher due to SVG functionality)
- **ERC1155**: ~4.76M gas
- **Reports**: ~2.05M gas
- **NativeCurrency**: ~1.35M gas
- **SeaportFeesCollectors**: ~1.61M gas

## Security Notes

1. **Role Management**: Ensure proper role assignments for production deployments
2. **Claim Amounts**: Set appropriate claim amounts to prevent abuse
3. **Supply Limits**: Set reasonable max supplies for NFT collections
4. **URI Validation**: Ensure metadata URIs are properly configured and accessible

## Advanced Usage

### Environment Variables
You can use environment variables in custom scripts:

```solidity
string memory tokenName = vm.envString("TOKEN_NAME");
uint256 maxSupply = vm.envUint("MAX_SUPPLY");
address admin = vm.envAddress("ADMIN_ADDRESS");
```

### Multi-Network Deployment
Create network-specific configurations:

```solidity
function getNetworkConfig() internal view returns (ERC20Config memory) {
    if (block.chainid == 1) {
        // Mainnet config
        return ERC20Config(...);
    } else if (block.chainid == 324) {
        // ZK Sync Era config  
        return ERC20Config(...);
    } else {
        // Testnet config
        return ERC20Config(...);
    }
}
```

This guide provides comprehensive instructions for deploying and customizing all token types supported by the Xsolla ZK smart contract suite.
