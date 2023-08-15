# Standard Monorepo Smart Contract Deployment Guide

This guide provides steps to deploy smart contracts from the Standard monorepo using Foundry and Forge. Ensure you have completed the [pre-requisites](./README.md#pre-requisites) before proceeding.

## Table of Contents

- [Pre-requisites](#pre-requisites)
- [Configurations](#configurations)
- [Deployment](#deployment)
- [Verifying Contracts](#verifying-contracts)
- [Interacting with Deployed Contracts](#interacting-with-deployed-contracts)

---

## Pre-requisites

Before delving into the Standard monorepo contracts, ensure your environment is prepared and know how to use these tools.

**Required Tools**:

- [**Foundry**](https://book.getfoundry.sh/getting-started/installation): A core development tool for the contracts.
- [**Forge**](https://book.getfoundry.sh/forge/): An essential package for building and deploying.

To set up these tools, visit their respective [official documentation](https://book.getfoundry.sh/forge/) for [installation instructions](https://book.getfoundry.sh/getting-started/installation).

---

## Configurations

1. **Wallet and Private Key**:

   - Always use a hardware wallet or a secure method to store and access private keys.
   - Ensure private keys are stored securely and not exposed in `.env`.

2. **RPC API Key:**
   - Sign up in [infura.io](https://app.infura.io/login) and get API key to connect to personalized RPC.
   - Ensure API keys are stored securely and not exposed in `.env`.

The environment variable file(`.env`) should store list of unexposed informaiton with variable declarations as below:

```
RINKEBY_RPC=https://rinkeby.infura.io/v3/<INFURA_RPC_API_KEY>
PRIVATE_KEY=<PRIVATE KEY>
```

Make sure the file is included in `.gitignore`.

After setting up sensitive information, run command below on the root project directory:

```
source .env
```

---

## Deployment

1. **Compile Contracts**:

   ```bash
   forge build
   ```

2. **Deploy**:
   Standard has customized deployment `forge-script` for each app in each network in `script` folder.
   For deploying an app to a specific network, let's say we deploy SAFEX in Linea Testnet(Goerli).

   Use this command below to test results after deployment.

   ```bash
   forge script script/safex/LineaTestnet.s.sol:DeployAll  -vvvv
   ```

   ***

   To setup deployer, modify `_setDeployer` function in the Deployer contract within the script file as below:

   ```
   contract Deployer is Script {
   function _setDeployer() internal {
       uint256 deployerPrivateKey = vm.envUint("<PRIVATE_KEY_VARIABLE_IN_ENV>");
       vm.startBroadcast(deployerPrivateKey);
   }
   ```

   ***

   Next, setup addresses on `DeployAll` contract withnin the script to adjust configuration as below:

   ```
   contract DeployAll is Deployer {

    // Change address constants on deploying to other networks or private keys
    address constant deployer_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant trader1_address =
        0x6408fb579e106fC59f964eC33FE123738A2D0Da3;
    address constant trader2_address =
        0xf5aE3B9dF4e6972a229E7915D55F9FBE5900fE95;
    address constant foundation_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    // seconds per block
    uint32 spb = 12;

   ...
   ```

   ***

   If you think you are ready to deploy after calculating costs, add `--broadcast` option to send deploying transaciton to the network as below:

   ```bash
   forge script script/safex/LineaTestnet.s.sol:DeployAll  -vvvv --broadcast
   ```

---

## Verifying Contracts

If you're using Foundry and Forge, contract verification might be integrated within the tools, or you can follow the standard process:

1. Navigate to the respective block explorer for the network you deployed on.
2. Search for your contract address.
3. Use the "Verify and Publish" functionality.
4. Follow the steps to verify your contract, providing the source code and compiler details.

---

Remember, always test your contracts on test networks before any mainnet deployment. Proper testing can prevent potential issues and losses.
