# exchange

## **Trading Digital Assets with fully onchain CLOB**

Standard offers the exchange protocol, which allows users to trade digital assets at their preferred prices and quantities. Whether you're a seasoned trader or new to the digital market, exchange offers the tools to buy and sell with precision and control.

## Table of Contents

- [Pre-requisites](#pre-requisites) : Essential tools and packages required before building or testing the src.
- [Usage](#usage) : Step-by-step guide on how to utilize the Standard monorepo src.
- [Security](#security) : Best practices and guidelines to ensure safe contract interaction.
- [Deploying and Using Locally](#deploying-and-using-locally) : Procedures to deploy the src in a local environment for testing or development purposes.

---

## Pre-requisites

Before delving into a Standard monorepo project, ensure your environment is prepared and know how to use these tools.

**Required Tools**:

- [**Foundry**](https://book.getfoundry.sh/getting-started/installation): A core development tool for the src.
- [**Forge**](https://book.getfoundry.sh/forge/): An essential package for building and deploying.
- [**Yarn**](https://yarnpkg.com/getting-started/install): A fast, reliable, and secure dependency management tool used to install and manage the project's dependencies.

To set up these tools, visit their respective [official documentation](https://book.getfoundry.sh/forge/) for [installation instructions](https://book.getfoundry.sh/getting-started/installation).

---

## Usage

Navigate your way through the Standard exchange contracts with the following procedures:

### 1. Install

Install all the necessary dependencies by running:

```bash
yarn
```

### 2. Build

Compile the src to ensure they're ready for deployment or testing:

```
forge build
```

### 3. Test

To ensure the src function as expected, run tests specifically for the pass module:

```
forge test --match-path test/exchange/*
```

### 4. Deploy

To deploy the exchange contracts in a chain, find `DeployExchangeMainnetContracts` contract in `scripts` folder on root project directory. 

```
contract DeployExchangeMainnetContracts is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    /// Second per block to finalize
    uint32 constant spb = 2;
    address constant deployer_address =
        0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address constant foundation_address =
        0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address constant weth = 0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701;

    function run() external {
        _setDeployer();
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngine matchingEngine = new MatchingEngine();

        orderbookFactory.initialize(address(matchingEngine));
        matchingEngine.initialize(
            address(orderbookFactory),
            address(deployer_address),
            address(weth)
        );

        vm.stopBroadcast();
    }
}
```

Run command in root directory below to deploy:
```
forge script script/exchange/MonadTestnet.sol:DeployExchangeMainnetContracts  --fork-url $MONAD_TESTNET_RPC -vvvv --gas-limit 18446744073709551615 --legacy --broadcast
```

---

## Security

When working with src, especially in a live environment, security is paramount. Follow best practices and always stay updated with the latest security advisories.

**Guidelines:**

- Always test new code in a sandboxed environment before deploying.
- Regularly audit your src for vulnerabilities.
- Keep private keys and sensitive information secure.

If you discover any security issues or vulnerabilities, please report them responsibly to our team via [official communication channel](mailto:contact@standardweb3.com).

---

## Deploying and Using Locally

For developers looking to work on the src within a local environment, follow the deployment instructions detailed in our [deployment guide](). This guide provides a comprehensive walkthrough on setting up, interacting with, and debugging the src in a controlled local setting.

## Documentation

For a comprehensive understanding of exchange and its functionalities, visit the official [documentation](https://docs.standardweb3.com).


## Licensing

The license for the codes in this monorepo is the Business Source License 1.1 (`BSL-1.1`). See [LICENSE](./LICENSE)

For information about alternative licensing arrangements for the Licensed Work, please contact [official communication channel](mailto:contact@standardweb3.com)
