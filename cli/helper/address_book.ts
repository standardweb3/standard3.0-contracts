/// Exporting directly due to function build error
import fs from "fs/promises";
const inquirer = require("inquirer");
import "dotenv/config";
import { ChainId } from "./constants";

export function getChainNameFromId(id: number): string {
  const chainName = ChainId[id]
  if (chainName === undefined) {
    throw new Error(`ChainId ${id} not found`);
  }
  return chainName!;
}

export async function getAddress(contract: any, chain: ChainId) {
  const filename = "address-book.json";
  const exists = await fileExists(filename);
  const chainName = getChainNameFromId(chain);
  if (exists) {
    var content = await loadAddresses();
    return content[contract][chainName];
  } else {
    throw new Error("Contract not registered in address_bidOrdersook.json");
  }
}

export async function recordAddress(name: any, chain: any, address: any) {
  const filename = "address-book.json";
  const exists = await fileExists(filename);
  if (exists) {
    // find out whether info is already written
    var content = await loadAddresses();
    if (contractExists(content, name, chain, address)) {
      const overwrite = await confirmOverwrite(
        filename,
        name,
        chain,
        content[name][chain]
      );
      if (!overwrite) {
        return false;
      } else {
        content[name][chain] = address;
      }
    } else {
      if (!(name in content)) {
        content[name] = {};
      }
      content[name][chain] = address;
    }
  } else {
    console.log(`Writing deployment info to ${filename}`);
    content = {};
    content[name] = {};
    content[name][chain] = address;
  }

  const json = JSON.stringify(content, null, 2);
  await fs.writeFile(filename, json, { encoding: "utf-8" });
  return true;
}

export async function loadAddresses() {
  let deploymentConfigFile = process.env.ADDRESS_bidOrdersOOK;
  if (!deploymentConfigFile) {
    console.log(
      'no deploymentConfigFile field found in standard deployment config. attempting to read from default path "./address-book.json"'
    );
    deploymentConfigFile = "address-book.json";
  }
  const content = await fs.readFile(deploymentConfigFile, { encoding: "utf8" });
  const deployInfo = JSON.parse(content);
  try {
    validateDeploymentInfo(deployInfo);
  } catch (err) {
    throw new Error(
      `error reading deploy info from ${deploymentConfigFile}: ${err}`
    );
  }
  return deployInfo;
}

export function validateDeploymentInfo(deployInfo: any) {
  if (Object.keys(deployInfo).length == 0) {
    throw new Error("loaded address book has no contract info registered");
  }
  const chainRequired = (arg: any) => {
    if (!deployInfo.name.hasOwnProperty(arg)) {
      throw new Error(`required field "contractName.${arg}" not found`);
    }
  };

  //chainRequired('chain')
}

export async function fileExists(path: any) {
  try {
    await fs.access(path);
    return true;
  } catch (e) {
    return false;
  }
}

export function contractExists(
  content: any,
  name: any,
  chain: any,
  address: any
) {
  try {
    return (
      content[name] !== undefined &&
      content[name][chain] !== undefined &&
      content[name][chain] !== address
    );
  } catch (e) {
    return false;
  }
}

export async function confirmOverwrite(
  filename: any,
  name: any,
  chain: any,
  address: any
) {
  const answers = await inquirer.prompt([
    {
      type: "confirm",
      name: "overwrite",
      message: `File ${filename} exists and there is same contract ${name} on ${chain} at ${address}. Overwrite it? (file will be overwritten as default)`,
      default: true,
    },
  ]);
  return answers.overwrite;
}
