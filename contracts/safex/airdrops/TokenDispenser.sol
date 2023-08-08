// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TokenDispenser
 * @dev A contract that dispenses specific amounts of tokens to users on request.
 * Only an admin can set the amount for each token.
 */
contract TokenDispenser is AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    mapping(address => uint256) public tokenAmounts;
    mapping(address => mapping(address => bool)) public received;

    // Custom error types
    error NotAdmin();
    error TokenNotSupported();
    error TokensAlreadyReceived();
    error TokenTransferFailed();

    /**
     * @dev Constructor that gives the deployer the default admin role.
     */
    constructor() {
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Sets the amount of a specific token to dispense.
     * Only callable by admins.
     * @param _token The address of the token.
     * @param _amount The amount to dispense.
     */
    function setTokenAmount(address _token, uint256 _amount) external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert NotAdmin();
        tokenAmounts[_token] = _amount;
    }

    /**
     * @dev Request tokens. User specifies which token they want.
     * Can only receive tokens once per token.
     * @param _token The address of the token to request.
     */
    function requestTokens(address _token) external {
        if (tokenAmounts[_token] == 0) revert TokenNotSupported();
        if (received[msg.sender][_token]) revert TokensAlreadyReceived();

        received[msg.sender][_token] = true;

        bool success = IERC20(_token).transfer(msg.sender, tokenAmounts[_token]);
        if (!success) revert TokenTransferFailed();
    }

    /**
     * @dev Grants the admin role to another address.
     * Only callable by current admins.
     * @param _account The address to grant the admin role.
     */
    function grantAdmin(address _account) external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert NotAdmin();
        grantRole(ADMIN_ROLE, _account);
    }

    /**
     * @dev Revokes the admin role from an address.
     * Only callable by current admins.
     * @param _account The address from which to revoke the admin role.
     */
    function revokeAdmin(address _account) external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert NotAdmin();
        revokeRole(ADMIN_ROLE, _account);
    }

    function left(address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }
}
