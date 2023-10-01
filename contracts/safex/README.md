# SAFEX

## **Trading Digital Assets with [SAFEX](./contracts/safex/README.md)**

Standard offers the SAFEX app, which allows users to trade digital assets at their preferred prices and quantities. Whether you're a seasoned trader or new to the digital market, SAFEX offers the tools to buy and sell with precision and control.

## Table of Contents

- [Pre-requisites](#pre-requisites) : Essential tools and packages required before building or testing the contracts.
- [Usage](#usage) : Step-by-step guide on how to utilize the Standard monorepo contracts.
- [Security](#security) : Best practices and guidelines to ensure safe contract interaction.
- [Deploying and Using Locally](#deploying-and-using-locally) : Procedures to deploy the contracts in a local environment for testing or development purposes.

---

## Pre-requisites

Before delving into the Standard monorepo contracts, ensure your environment is prepared and know how to use these tools.

**Required Tools**:

- [**Foundry**](https://book.getfoundry.sh/getting-started/installation): A core development tool for the contracts.
- [**Forge**](https://book.getfoundry.sh/forge/): An essential package for building and deploying.
- [**Yarn**](https://yarnpkg.com/getting-started/install): A fast, reliable, and secure dependency management tool used to install and manage the project's dependencies.

To set up these tools, visit their respective [official documentation](https://book.getfoundry.sh/forge/) for [installation instructions](https://book.getfoundry.sh/getting-started/installation).

---

## Usage

Navigate your way through the Standard monorepo contracts with the following procedures:

### 1. Install

Install all the necessary dependencies by running:

```bash
yarn
```

### 2. Build

Compile the contracts to ensure they're ready for deployment or testing:

```
forge build
```

### 3. Test

To ensure the contracts function as expected, run tests specifically for the SABT module:

```
forge test --match-path test/safex/*
```

---

## Security

When working with contracts, especially in a live environment, security is paramount. Follow best practices and always stay updated with the latest security advisories.

**Guidelines:**

- Always test new code in a sandboxed environment before deploying.
- Regularly audit your contracts for vulnerabilities.
- Keep private keys and sensitive information secure.

If you discover any security issues or vulnerabilities, please report them responsibly to our team via [official communication channel](mailto:contact@standardweb3.com).

---

## Deploying and Using Locally

For developers looking to work on the contracts within a local environment, follow the deployment instructions detailed in our [deployment guide](). This guide provides a comprehensive walkthrough on setting up, interacting with, and debugging the contracts in a controlled local setting.

## Documentation

For a comprehensive understanding of SAFEX and its functionalities, visit the official [documentation](https://docs.standardweb3.com).


## Licensing

The license for the codes in this monorepo is the Business Source License 1.1 (`BSL-1.1`). See [LICENSE](./LICENSE)

For information about alternative licensing arrangements for the Licensed Work, please contact [official communication channel](mailto:contact@standardweb3.com)
