# Xsolla ZKsync Smart Contracts

ERC-7579 compatible ZKsync SSO contracts with Xsolla Web3 product contracts integration.

A user & developer friendly modular smart account implementation on ZKsync that integrates with Xsolla's Web3 product ecosystem, simplifying user authentication, session management, and transaction processing for gaming and digital commerce applications.

Fully compliant with the [ERC-7579](https://erc7579.com/) standard for modular smart accounts.

## Features

- **ERC-7579 Compliance**: Full compatibility with the modular smart account standard
- **ZKsync Integration**: Optimized for ZKsync's Layer 2 scaling solution
- **Xsolla Web3 Integration**: Seamless integration with Xsolla's Web3 product ecosystem
- **SSO Authentication**: Single Sign-On capabilities for enhanced user experience
- **Session Management**: Advanced session handling for gaming and commerce applications
- **Modular Architecture**: Extensible design with validator and executor modules
- **Account Abstraction**: Simplified transaction flows and gas management

## Architecture

This implementation extends the [ERC-7579 reference implementation](https://github.com/erc7579/erc7579-implementation) by Rhinestone with Xsolla-specific enhancements for Web3 gaming and digital commerce use cases.

> [!CAUTION]
> The factory and module interfaces are not yet stable! Any contracts interfacing
> `ModularSmartAccount` will likely need to be updated in the
> final version. The code is currently under audit and the latest may contain
> security vulnerabilities.

## Local Development

Requires the latest [`foundry`](https://getfoundry.sh).

1. Install workspace dependencies with `forge soldeer install`.
2. Build the project with `forge build`.
3. Run tests with `forge test`.

To run the integration tests:

1. Install dependencies with `pnpm install`
2. Run the local development node with `pnpm anvil`.
3. In a separate terminal, run the bundler with `pnpm bundler`
4. Deploy all contracts and a test account with `pnpm deploy-test`
5. Run integration tests with `pnpm test`
