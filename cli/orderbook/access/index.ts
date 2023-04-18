const { task } = require("hardhat/config");
const { Contract } = require("ethers");
const { ethers } = require("hardhat");
const { keccak256 } = require("ethers/lib/utils");
const { AccessControl } = require("@openzeppelin/contracts");

task(
  "grant-role",
  "Grants a role to an address using AccessControl.sol contract"
)
  .addParam("address", "The address to grant the role to")
  .addOptionalParam("role", "The name of the role to grant", "")
  .setAction(async ({ address, role }) => {
    // Get the contract owner's signer account
    const [owner] = await ethers.getSigners();

    // Deploy the AccessControl.sol contract
    const accessControl = await new Contract(
      "ACCESS_CONTROL_CONTRACT_ADDRESS",
      AccessControl.abi,
      owner
    );

    // Define the role's hash
    const roleHash = keccak256(Buffer.from(role));

    // Grant the role to the specified address
    await accessControl.grantRole(roleHash, address);

    console.log(`Role ${role} granted to ${address}`);
  });

task(
  "remove-role",
  "Removes a role from an address using AccessControl.sol contract"
)
  .addParam("address", "The address to remove the role from")
  .addParam("role", "The name of the role to remove")
  .setAction(async ({ address, role }) => {
    // Get the contract owner's signer account
    const [owner] = await ethers.getSigners();

    // Deploy the AccessControl.sol contract
    const accessControl = await new Contract(
      "ACCESS_CONTROL_CONTRACT_ADDRESS",
      AccessControl.abi,
      owner
    );

    // Define the role's hash
    const roleHash = keccak256(Buffer.from(role));

    // Revoke the role from the specified address
    await accessControl.revokeRole(roleHash, address);

    console.log(`Role ${role} revoked from ${address}`);
  });
