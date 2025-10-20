# Autowirable DI: Wiring Contracts in Foundry Scripts

This guide explains how to use the lightweight DI container provided by `Autowirable.s.sol` to assemble deployments and look up addresses deterministically across runs using a TOML-backed configuration.

It’s designed for Foundry scripts and builds on a few simple ideas:
- A central wiring mechanism (`StdConfigBasedWiring`) that deploys or looks up contracts.
- Deterministic keys ("Sources") for every component.
- Modifiers that perform wiring before your function executes.
- A persistent config file (`./configurations/debug.toml`) keyed by chain.

## What you get
- Deterministic deployments with `CREATE2` wherever possible.
- Support for three wiring modes:
  - PLAIN: refer to a single source by name.
  - PLAIN_NICKNAMED: same source but namespaced by a short nickname.
  - CONFIGURATION_BASED: invoke a config contract that performs multi-step wiring.
- Built‑in recipes for:
  - Deploying an OpenZeppelin TransparentUpgradeableProxy around an implementation (`proxywire`).
  - Running a configuration contract (`configwire`).
  - Creating an EIP‑4337 smart account keyed by nickname/owner (`accountwire`).
- Simple lookups to retrieve the wired addresses later (`autowired`).

## Core pieces

- `script/xsolla/di/Autowirable.s.sol` — mixin for Foundry scripts exposing DI helpers:
  - `configwire(IConfiguration config)`: run a configuration contract (CONFIGURATION_BASED).
  - `autowire(Sources.Source source)`: wire a single source (PLAIN).
  - `proxywire(Sources.Source source)`: deploy TUP proxy for the given implementation (CONFIGURATION_BASED).
  - `accountwire(string nickname)`: deploy an EIP‑4337 smart account (CONFIGURATION_BASED).
  - `nickwire(Sources.Source source, ShortString nickname)`: PLAIN_NICKNAMED wiring.
  - `autowired(Sources.Source source)`: lookup the primary address for a source.
  - `autowired(Sources.Source source, string nickname)`: lookup a nicknamed variant (e.g. proxied modules or named accounts).

- `script/xsolla/di/wiring/StdConfigBasedWiring.s.sol` — the actual wiring engine talking to `StdConfig` (TOML).
- `script/xsolla/di/interfaces/IConfiguration.s.sol` — interface for configuration contracts.
- Configurations in `script/xsolla/di/configurations/*` encapsulate multi-step deployments, e.g.:
  - `StdConfigBasedEip4337FactoryConfiguration.s.sol`
  - `StdConfigBasedGuardianExecutorConfiguration.s.sol`
  - `StdConfigBasedXsollaRecoveryExecutorConfiguration.s.sol`

## Quick start

1) Inherit `Autowirable` in your Foundry script and prepare configs in `setUp()`.

```solidity
contract MyScript is Autowirable {
    function setUp() public {
        // Construct any IConfiguration you need using `vm` and the wiring mechanism
        // Example:
        // myConfig = new MyConfiguration(vm, wiringMechanism, msg.sender);
    }

    function run()
        public
        autowire(Sources.Source.EOAKeyValidator) // simple PLAIN wire
    {
        // Your logic. You can look up addresses via `autowired(...)`.
    }
}
```

2) Use wiring modifiers to deploy or resolve components before your function body runs.

- `proxywire(Sources.Source.WebAuthnValidator)`
  - Deploys a TransparentUpgradeableProxy for the `WebAuthnValidator` implementation, persists both the implementation and proxy addresses under deterministic keys, then passes the proxy address to your function.

- `configwire(guardianExecutorConfig)`
  - Runs a configuration contract which can perform multiple deployments and persist addresses.

- `accountwire("Alice")`
  - Creates a Modular Smart Account (EIP‑4337) for nickname "Alice" owned by `msg.sender` (as provided to the config constructor).

## Example: Full DI flow (from `SSO.s.sol`)

`script/xsolla/SSO.s.sol` wires validators via proxy, configures executors, deploys the 4337 factory pieces, and finally creates a named smart account.

```solidity
contract SSO is Autowirable {
    string public constant ALICE_SMART_ACC = "Alice";

    StdConfigBasedEip4337FactoryConfiguration private eip4337FactoryConfig;
    StdConfigBasedGuardianExecutorConfiguration private guardianExecutorConfig;
    StdConfigBasedXsollaRecoveryExecutorConfiguration private xsollaRecoveryConfig;

    function setUp() public {
        eip4337FactoryConfig = new StdConfigBasedEip4337FactoryConfiguration(vm, wiringMechanism, msg.sender);
        guardianExecutorConfig = new StdConfigBasedGuardianExecutorConfiguration(vm, wiringMechanism, msg.sender);
        xsollaRecoveryConfig = new StdConfigBasedXsollaRecoveryExecutorConfiguration(
            vm, wiringMechanism, msg.sender, msg.sender, msg.sender
        );
    }

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
        // Lookups
        address eoaProxy = autowired(
            Sources.Source.TransparentUpgradeableProxy,
            Sources.Source.EOAKeyValidator.toString()
        );
        address msaImpl = autowired(Sources.Source.ModularSmartAccount, ALICE_SMART_ACC);
        // ...and so on
    }
}
```

Notes:
- For proxied modules, use `autowired(Sources.Source.TransparentUpgradeableProxy, "<ModuleName>")`.
  - Example names: `"EOAKeyValidator"`, `"SessionKeyValidator"`, `"WebAuthnValidator"`, `"MSAFactory"`, `"GuardianExecutor"`.
- For named accounts, use `autowired(Sources.Source.ModularSmartAccount, "Alice")` to get the deployed account address stored under that nickname.

## Example: Simple ERC-20 script (no DI required)

`script/xsolla/EIP20.s.sol` shows a simple pattern that doesn’t need DI. You can still inherit `Autowirable` to keep the option to use DI later.

```solidity
contract EIP20 is Autowirable {
    ERC20Factory public erc20Factory;
    ERC20Modular public modularERC20;
    ERC20Claimer public erc20Claimer;

    function run() public {
        vm.startBroadcast();
        erc20Factory = new ERC20Factory();
        modularERC20 = new ERC20Modular("Xsolla Token", "XSOLLA", msg.sender, msg.sender, msg.sender);
        erc20Claimer = new ERC20Claimer(modularERC20);
        erc20Claimer.setAmountToClaim(100 ether);
        modularERC20.grantRole(modularERC20.MINTER_ROLE(), address(erc20Claimer));
        vm.stopBroadcast();
    }
}
```

## Writing a configuration contract

Implement `IConfiguration` to bundle multi-step routines. The constructor typically needs `vm` and the shared wiring mechanism so it can access the same config file.

Minimal skeleton:

```solidity
contract MyConfig is IConfiguration {
    StdConfig private config;
    Vm private vm;

    constructor(Vm _vm, StdConfigBasedWiring wiring) {
        vm = _vm;
        config = wiring.getConfig();
    }

    function name() external view returns (string memory) { return "My Config"; }

    function startAutowiringSources() external {
        // 1) read inputs from config if needed: config.get("SomeKey").toAddress();
        // 2) vm.startBroadcast(); deploy things; vm.stopBroadcast();
        // 3) persist addresses: config.set("SomeKey", deployedAddress);
    }
}
```

Tip: See the concrete examples:
- `StdConfigBasedGuardianExecutorConfiguration.s.sol`
- `StdConfigBasedXsollaRecoveryExecutorConfiguration.s.sol`
- `StdConfigBasedEip4337FactoryConfiguration.s.sol`

## Where values are stored

Addresses are written into `./configurations/debug.toml` under the active chain scope, e.g. `[anvil-hardhat.address]` with keys such as:
- `EOAKeyValidator`, `TransparentUpgradeableProxy_EOAKeyValidator`
- `SessionKeyValidator`, `TransparentUpgradeableProxy_SessionKeyValidator`
- `WebAuthnValidator`, `TransparentUpgradeableProxy_WebAuthnValidator`
- `GuardianExecutor`, `TransparentUpgradeableProxy_GuardianExecutor`
- `ModularSmartAccount`, `UpgradeableBeacon`, `MSAFactory`, `TransparentUpgradeableProxy_MSAFactory`
- `XsollaRecoveryExecutor`

Lookups via `autowired(...)` read from these keys through the wiring mechanism.

## Running scripts (Windows PowerShell)

- Start a local Anvil node (or use your own RPC URL).
- Execute scripts with Forge. Examples:

```powershell
# Run the SSO wiring end-to-end
forge script script/xsolla/SSO.s.sol:SSO --rpc-url 127.0.0.1:8545 --broadcast --private-key <YOUR_DEV_KEY>

# Run the simple ERC-20 script
forge script script/xsolla/EIP20.s.sol:EIP20 --rpc-url 127.0.0.1:8545 --broadcast --private-key <YOUR_DEV_KEY>
```

Notes:
- You’ll see logs like "Autowired ..." and "Configuration (...) utilized" showing what was wired.
- The DI engine is idempotent across runs: if a value already exists in TOML for a key, it will be reused where appropriate.

## Practical tips and gotchas

- `proxywire(...)` ensures the implementation is deployed and then deploys a TransparentUpgradeableProxy, persisting both addresses.
- `accountwire(nickname)` builds the module list and per-module init data; it requires that validator/executor addresses exist in the config (the configs ensure this).
- When you need constructor args (e.g., for `XsollaRecoveryExecutor`), prefer a config contract over `proxywire` so you can pass parameters explicitly.
- For proxied lookups, remember to use the nicknamed form with the module name as the nickname: `autowired(TransparentUpgradeableProxy, "EOAKeyValidator")`.

## Troubleshooting

- Empty revert or array out-of-bounds during account creation: ensure the number of `initData` elements matches the number of modules and that the prerequisites (validators/executors) are wired/configured first.
- ERC1967 invalid implementation during proxy setup: make sure the implementation was deployed in a broadcasted tx before deploying the proxy (handled by the wiring engine).
- TOML missing keys: run the appropriate `configwire(...)` or `proxywire(...)` step so the value gets written.

---

That’s it. Use `Autowirable` modifiers to declare what you need; the DI container will deploy or resolve it deterministically and make it available for your script body. 
