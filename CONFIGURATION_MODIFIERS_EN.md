# Quick Reference: Autowirable DI System and Wiring Modifiers

This project uses a Dependency Injection (DI) system based on Foundry's `StdConfig` for:
1. Connecting environment configuration (debug / production).
2. Automatic deployment and wiring of contracts through `autowire`, `proxywire`, `configwire` modifiers.
3. Deterministic calculation of contract addresses via `Sources.Source`.
4. Retrieving addresses of deployed contracts through `autowired()` functions.

---
## 1. Base Class `Autowirable`
All deployment scripts inherit from `Autowirable`, which provides:
- Automatic wiring system setup
- Modifiers for contract wiring
- Functions for retrieving deployed contract addresses

Configuration is loaded automatically (DEBUG mode by default) when creating `Autowirable`.

### When to Use
Inherit from `Autowirable` in all deployment scripts:

### Example
```solidity
contract MyDeployScript is Autowirable {
    function run() public { /* ... */ }
}
```

---
## 2. Sources (`Sources.Source`)
`Sources.Source` is an enum where each position corresponds to a contract/deployment type defined in the project. Sources have helper methods (e.g., `toSalt()`, `toString()`) used for deterministic CREATE2 addresses and configuration identification.

---
## 3. Wiring Modifiers

### `autowire(Sources.Source source)`
Deploys a contract directly with a deterministic address.

### `proxywire(Sources.Source source)`
Deploys a proxy (TransparentUpgradeableProxy) for the given source.

### `configwire(IConfiguration configContract)`
Executes a configuration contract that can deploy multiple related contracts.

### `accountwire(string memory nickname)`
Deploys a named account (ModularSmartAccount) with the specified nickname.

### `nickwire(Sources.Source source, ShortString nickname)`
Deploys a contract with a specified nickname to enable multiple instances.

### Purpose
Automates the contract deployment process and saves their addresses in configuration for subsequent use.

### Example (from `SSO.s.sol`)
```solidity
function run()
    public
    proxywire(Sources.Source.EOAKeyValidator)
    proxywire(Sources.Source.SessionKeyValidator)
    proxywire(Sources.Source.WebAuthnValidator)
    configwire(guardianExecutorConfig)
    configwire(xsollaRecoveryConfig)
    configwire(eip4337FactoryConfig)
    accountwire(ALICE_SMART_ACC)
{
    // Inside the function body, contracts are already deployed and accessible via autowired()
}
```

---
## 4. `autowired()` Functions

### `autowired(Sources.Source source)`
Retrieves the address of a contract deployed via `autowire`.

### `autowired(Sources.Source source, string memory nickname)`
Retrieves the address of a contract with the specified nickname (for proxies or named accounts).

### Usage Examples
```solidity
// Getting address of a regular contract
address beacon = autowired(Sources.Source.UpgradeableBeacon);

// Getting proxy address for a specific module
address eoaValidator = autowired(
    Sources.Source.TransparentUpgradeableProxy, 
    Sources.Source.EOAKeyValidator.toString()
);

// Getting address of a named account
address aliceAccount = autowired(Sources.Source.ModularSmartAccount, ALICE_SMART_ACC);
```

---
## 5. Configuration Contracts
For complex deployments, special configuration contracts implementing the `IConfiguration` interface are created. They allow grouping related deployments.

### Examples:
- `Eip4337FactoryConfiguration` — deploys EIP-4337 factory and related components
- `GuardianExecutorConfiguration` — deploys Guardian Executor and its proxy
- `GuardianBasedRecoveryExecutorConfiguration` — deploys Recovery Executor

### Usage in Scripts:
```solidity
function setUp() public {
    eip4337FactoryConfig = new Eip4337FactoryConfiguration(vm, wiringMechanism, msg.sender);
    guardianExecutorConfig = new GuardianExecutorConfiguration(vm, wiringMechanism, msg.sender);
}

function run() public configwire(eip4337FactoryConfig) configwire(guardianExecutorConfig) {
    // Configurations are executed automatically
}
```

---
## 6. Typical Modifier Structure
Recommended order in `run()` / `deploy*()` functions:
1. Wiring modifiers (`autowire`, `proxywire`, `configwire`, `accountwire`, `nickwire`)
2. Inside the body: use `autowired()` to retrieve addresses of deployed contracts
3. (Optional) logging via `console.log`

---
## 7. Quick Tips
- Use `proxywire` for modules that should be upgradeable via proxy
- Use `autowire` for simple contracts that don't require a proxy
- Use `configwire` to group related deployments in configuration contracts
- Use `accountwire` to create named accounts with unique nicknames
- Use `nickwire` when you need to create multiple instances of the same contract type
- Retrieve addresses via `autowired()` only after declaring corresponding wiring modifiers

---
## 8. Minimal Examples

### Simple Contract Deployment
```solidity
contract SimpleScript is Autowirable {
    function run() public autowire(Sources.Source.EOAKeyValidator) {
        address validator = autowired(Sources.Source.EOAKeyValidator);
        console.log("EOAKeyValidator deployed at:", validator);
    }
}
```

### Proxy Deployment
```solidity
contract ProxyScript is Autowirable {
    function run() public proxywire(Sources.Source.SessionKeyValidator) {
        address proxy = autowired(
            Sources.Source.TransparentUpgradeableProxy,
            Sources.Source.SessionKeyValidator.toString()
        );
        console.log("SessionKeyValidator proxy deployed at:", proxy);
    }
}
```

### Full Example with Configuration
```solidity
contract FullScript is Autowirable {
    GuardianExecutorConfiguration private guardianConfig;
    
    function setUp() public {
        guardianConfig = new GuardianExecutorConfiguration(vm, wiringMechanism, msg.sender);
    }
    
    function run() 
        public 
        proxywire(Sources.Source.EOAKeyValidator)
        configwire(guardianConfig)
        accountwire("TestAccount")
    {
        address eoaProxy = autowired(
            Sources.Source.TransparentUpgradeableProxy,
            Sources.Source.EOAKeyValidator.toString()
        );
        address guardianProxy = autowired(
            Sources.Source.TransparentUpgradeableProxy,
            Sources.Source.GuardianExecutor.toString()
        );
        address account = autowired(Sources.Source.ModularSmartAccount, "TestAccount");
        
        console.log("EOA Validator:", eoaProxy);
        console.log("Guardian Executor:", guardianProxy);
        console.log("Test Account:", account);
    }
}
```

---
## 9. Running Scripts (Example)
(Replace RPC with your endpoint.)
```bash
forge script script/xsolla/SSO.s.sol:SSO --rpc-url $RPC --broadcast -vvvv
```
For dry-run, you can remove `--broadcast`.

---
## 10. Possible Errors
- `ChooseConfigurationFirst()` — configuration was not loaded (usually handled automatically in `Autowirable`)
- Errors when calling `autowired()` — make sure the corresponding wiring modifier was applied
- Invalid nicknames — ensure you're using correct string identifiers for proxies and accounts

---
## 11. Summary
| Modifier/Function | Purpose | When to Use |
|-------------------|---------|-------------|
| `autowire` | Deploys contract directly | For simple contracts without proxy |
| `proxywire` | Deploys proxy for contract | For upgradeable modules |
| `configwire` | Executes configuration contract | For grouping related deployments |
| `accountwire` | Deploys named account | For creating ModularSmartAccount |
| `nickwire` | Deploys contract with nickname | For multiple instances of same type |
| `autowired` | Retrieves deployed contract address | For accessing addresses after deployment |

If you need extended documentation, sections about creating configuration contracts and the internal wiring mechanism implementation can be expanded.
