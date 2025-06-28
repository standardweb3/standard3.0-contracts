// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Deposit is AccessControl {

    event DepositETH(address indexed to, uint256 amount);
    event DepositToken(address indexed to, address indexed token, uint256 amount);
    event DepositNFT(address indexed to, address indexed token, uint256 tokenId);

    mapping(address => bool) public supportedTokens;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setSupportedTokens(address[] memory tokens, bool[] memory isSupported) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < tokens.length; i++) {
            supportedTokens[tokens[i]] = isSupported[i];
        }
    }

    // Depost Native Token to api account
    function depositETH(address to) public payable {
        // send ETH to the API service
        payable(to).transfer(msg.value);
        emit DepositETH(to, msg.value);
    }

    // Deposit ERC20 token to api account
    function depositToken(address to, address token, uint256 amount) public {
        // send token to the API service
        // check if the token is supported
        require(supportedTokens[token], "Token not supported");
        IERC20(token).transferFrom(msg.sender, to, amount);
        emit DepositToken(to, token, amount);
    }

    // Deposit NFT to api account
    function depositNFT(address to, address token, uint256 tokenId) public {
        // send NFT to the API service
        // check if the token is supported
        require(supportedTokens[token], "Token not supported");
        IERC721(token).transferFrom(msg.sender, to, tokenId);
        emit DepositNFT(to, token, tokenId);
    }
}