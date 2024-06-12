// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/src/token/ERC20/ERC20.sol";
import "@openzeppelin/src/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/src/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/src/access/AccessControl.sol";

contract ERC20MintablePausableBurnable is ERC20, ERC20Burnable, ERC20Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 private constant MAX_SUPPLY = 20000000 * (10 ** 18); // 20 million tokens with 18 decimal places

    constructor() ERC20("StandardX", "STNDX") {
        // Grant the contract deployer the default admin role: they can grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Grant the minter and pauser roles to the deployer
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);

        // Mint initial supply to contract deployer
        _mint(msg.sender, MAX_SUPPLY);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(to, amount);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}
