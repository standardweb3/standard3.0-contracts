// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IMatchingEngine} from "../exchange/interfaces/IMatchingEngine.sol";

contract Deposit is AccessControl {

    event DepositETH(address indexed to, uint256 amount);
    event DepositToken(address indexed to, address indexed token, uint256 amount);
    event DepositNFT(address indexed to, address indexed token, uint256 tokenId);
    event SetSupportedTokens(address[] tokens, bool[] isSupported);

    mapping(address => bool) public supportedTokens;

    struct Order {
        address matchingEngine;
        bool isBid;
        bool isLimit;
        bool isETH;
        address base;
        address quote;
        uint256 price;
        uint256 amount;
        address recipient;
        uint32 matchN;
    }

    struct CancelOrder {
        address matchingEngine;
        address base;
        address quote;
        uint32 orderId;
        bool isBid;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setSupportedTokens(address[] memory tokens, bool[] memory isSupported) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < tokens.length; i++) {
            supportedTokens[tokens[i]] = isSupported[i];
        }
        emit SetSupportedTokens(tokens, isSupported);
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

    function createOrders(Order[] memory orders) public payable {
        // create orders
        // check if the token is supported

        for (uint256 i = 0; i < orders.length; i++) {
            if(orders[i].isLimit) {
                if(orders[i].isBid) {
                    if(orders[i].isETH) {
                        IMatchingEngine(orders[i].matchingEngine).limitBuyETH{value: orders[i].amount}(orders[i].base, orders[i].price, false, orders[i].matchN, orders[i].recipient);
                    }
                    else {
                        IMatchingEngine(orders[i].matchingEngine).limitBuy(orders[i].base, orders[i].quote, orders[i].price, orders[i].amount, false, orders[i].matchN, orders[i].recipient);
                    }
                }
                else {
                    if(orders[i].isETH) {
                        IMatchingEngine(orders[i].matchingEngine).limitSellETH{value: orders[i].amount}(orders[i].quote, orders[i].price, false, orders[i].matchN, orders[i].recipient);
                    }
                    else {
                        IMatchingEngine(orders[i].matchingEngine).limitSell(orders[i].base, orders[i].quote, orders[i].price, orders[i].amount, false, orders[i].matchN, orders[i].recipient);
                    }
                }
            } else {
                if(orders[i].isBid) {
                    if(orders[i].isETH) {
                        IMatchingEngine(orders[i].matchingEngine).marketBuyETH{value: orders[i].amount}(orders[i].base, false, orders[i].matchN, orders[i].recipient, 0);
                    }
                    else {
                        IMatchingEngine(orders[i].matchingEngine).marketBuy(orders[i].base, orders[i].quote, orders[i].amount, false, orders[i].matchN, orders[i].recipient, 0);
                    }
                }
                else {
                    if(orders[i].isETH) {
                        IMatchingEngine(orders[i].matchingEngine).marketSellETH{value: orders[i].amount}(orders[i].quote, false, orders[i].matchN, orders[i].recipient, 0);
                    }
                    else {
                        IMatchingEngine(orders[i].matchingEngine).marketSell(orders[i].base, orders[i].quote, orders[i].amount, false, orders[i].matchN, orders[i].recipient, 0);
                    }
                }
            }
        }
    }

    function cancelOrders(CancelOrder[] memory cancelOrderData) public {
        for (uint256 i = 0; i < cancelOrderData.length; i++) {
            IMatchingEngine(cancelOrderData[i].matchingEngine).cancelOrder(
                cancelOrderData[i].base, 
                cancelOrderData[i].quote, 
                cancelOrderData[i].isBid, 
                cancelOrderData[i].orderId
            );
        }
    }
}