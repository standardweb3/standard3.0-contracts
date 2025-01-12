// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Standard is
    ERC20,
    ERC20Burnable,
    AccessControl
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private constant MAX_SUPPLY = 500_000_000 * 10**18; // 500 million tokens with 18 decimals
    error MaxSupplyReached(uint256 currentSupply, uint256 newSupply);


    constructor() ERC20("Standard", "STND") {
        // Grant the contract deployer the default admin role: they can grant and revoke any roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Grant the minter and pauser roles to the deployer
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert MaxSupplyReached(totalSupply(), totalSupply() + amount);
        }
        _mint(to, amount);
    }

    function remainingMintableSupply() public view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }
}
