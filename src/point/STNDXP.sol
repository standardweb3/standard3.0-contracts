// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract STNDXP is ERC20, ERC20Burnable, ERC20Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    mapping(address => uint256) public penalties;

    error AmountExceededBalance(
        address account,
        uint256 amount,
        uint256 balance
    );

    constructor() ERC20("Standard(STND) Xperience Point", "STNDXP") {
        // Grant the contract deployer the default admin role: they can grant and revoke any roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Grant the minter and pauser roles to the deployer
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    function mint(
        address to,
        uint256 amount
    ) public onlyRole(MINTER_ROLE) returns (uint256 minted) {
        if (penalties[to] >= amount) {
            penalties[to] -= amount;
            return 0;
        } else {
            penalties[to] = 0;
            _mint(to, amount - penalties[to]);
            return amount - penalties[to];
        }
    }

    function mintMatch(
        address sender,
        address owner,
        uint256 sdrAmount,
        uint256 onrAmount
    )
        public
        onlyRole(MINTER_ROLE)
        returns (uint256 sdrMinted, uint256 onrMinted)
    {
        _mint(sender, sdrAmount);
        _mint(owner, onrAmount);
        return (sdrAmount, onrAmount);
    }

    function penaltyOf(
        address account
    ) external view returns (uint256 penalty) {
        return penalties[account];
    }

    function burn(
        address to,
        uint256 amount
    ) public onlyRole(BURNER_ROLE) returns (uint256 burned) {
        _burn(to, amount);
        return amount;
    }

    function fine(
        address to,
        uint256 amount
    ) public onlyRole(MINTER_ROLE) returns (uint256 fined) {
        penalties[to] += amount;
        return amount;
    }

    function removePenalty(
        address to,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) returns (uint256 removed) {
        // check point balance
        if (amount > balanceOf(to)) {
            revert AmountExceededBalance(to, amount, balanceOf(to));
        }
        _burn(to, amount);
        penalties[to] -= amount;
        return amount;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20, ERC20Pausable) whenNotPaused {
        super._update(from, to, value);
    }
}
