// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract BulkSender is AccessControl {
    // The address of the token to send
    address private relayer;
    uint256 private fee;

    constructor(address _relayer, uint256 _fee) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        relayer = _relayer;
        fee = 0.0001 ether;
    }

    function set(address _relayer, uint256 _fee) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Caller is not an admin"
        );
        relayer = _relayer;
        fee = _fee;
    }

    // This function is called by the owner to send tokens to a list of addresses
    function sendBulk(
        address tokenAddress,
        address[] calldata addresses,
        uint256[] calldata amounts
    ) external payable {
        // require fee
        require(msg.value > fee, "FL");
        require(
            addresses.length == amounts.length,
            "Arrays must have the same length"
        );
        for (uint256 i = 0; i < addresses.length; i++) {
            require(
                IERC20(tokenAddress).transferFrom(
                    msg.sender,
                    addresses[i],
                    amounts[i]
                ),
                "Transfer failed"
            );
        }
    }

    // This function is called by the owner to send tokens to a list of addresses
    function sendBulkEth(
        address[] calldata addresses,
        uint256[] calldata amounts
    ) external payable {
        // require fee
        require(msg.value > fee, "FL");
        // send fee to the meta transaction relayer
        payable(relayer).transfer(fee);
        require(
            addresses.length == amounts.length,
            "Arrays must have the same length"
        );
        for (uint256 i = 0; i < addresses.length; i++) {
            payable(addresses[i]).transfer(amounts[i]);
        }
    }
}
