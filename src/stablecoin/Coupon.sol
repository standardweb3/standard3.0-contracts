// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ICoupon.sol";
import "./interfaces/INetworkState.sol";

contract Coupon is ERC721, AccessControl {
    // Create a new role identifier for the minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    address manager;

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    constructor(address manager_) ERC721("SAFU BOND COUPON", "COUPON") {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _grantRole(MINTER_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, manager);
        _grantRole(BURNER_ROLE, _msgSender());
        manager = manager_;
    }

    function setManager(address manager_) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "MTRV1: Caller is not a default admin");
        manager = manager_;
    }

    function mint(address to, uint256 tokenId_) external {
        // Check that the calling account has the minter role
        require(hasRole(MINTER_ROLE, msg.sender), "MTRV1: Caller is not a minter");
        _mint(to, tokenId_);
    }

    function burn(uint256 tokenId_) external {
        require(hasRole(BURNER_ROLE, _msgSender()), "MTRV1: must have burner role to burn");

        _burn(tokenId_);
    }

    function burnFromVault(uint256 vaultId_) external {
        require(INetworkState(manager).getVault(vaultId_) == _msgSender(), "MTRV1: Caller is not vault");
        _burn(vaultId_);
    }
}
