// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IMatchingEngine} from "../exchange/interfaces/IMatchingEngine.sol";

contract Deposit is AccessControl {
    mapping(address => bool) public supportedTokens;

    struct APICreateOrderInput {
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

    struct APICancelOrderInput {
        address matchingEngine;
        address base;
        address quote;
        uint32 orderId;
        bool isBid;
    }

    struct APIUpdateOrderInput {
        address matchingEngine;
        address base;
        address quote;
        bool isBid;
        uint32 orderId;
        uint256 price;
        uint256 amount;
        uint32 n;
        address recipient;
    }

    event DepositETH(address indexed to, uint256 amount);
    event DepositToken(address indexed to, address indexed token, uint256 amount);
    event DepositNFT(address indexed to, address indexed token, uint256 tokenId);
    event DepositERC1155(address indexed to, address indexed token, uint256 tokenId, uint256 amount);
    event SetSupportedTokens(address[] tokens, bool[] isSupported);

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
    function depositERC721(address to, address token, uint256 tokenId) public {
        // send NFT to the API service
        // check if the token is supported
        require(supportedTokens[token], "Token not supported");
        IERC721(token).transferFrom(msg.sender, to, tokenId);
        emit DepositNFT(to, token, tokenId);
    }

    function depositERC1155(address to, address token, uint256 tokenId, uint256 amount) public {
        // send ERC1155 to the API service
        // check if the token is supported
        require(supportedTokens[token], "Token not supported");
        IERC1155(token).safeTransferFrom(msg.sender, to, tokenId, amount, "");
        emit DepositERC1155(to, token, tokenId, amount);
    }

    function createOrders(APICreateOrderInput[] memory orders) public payable {
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

    function cancelOrders(APICancelOrderInput[] memory cancelOrderData) public {
        for (uint256 i = 0; i < cancelOrderData.length; i++) {
            IMatchingEngine(cancelOrderData[i].matchingEngine).cancelOrder(
                cancelOrderData[i].base, 
                cancelOrderData[i].quote, 
                cancelOrderData[i].isBid, 
                cancelOrderData[i].orderId
            );
        }
    }

    function updateOrders(APIUpdateOrderInput[] memory orders) public {
        for (uint256 i = 0; i < orders.length; i++) {
            IMatchingEngine.UpdateOrderInput memory updateOrderData = IMatchingEngine.UpdateOrderInput({
                base: orders[i].base,
                quote: orders[i].quote,
                isBid: orders[i].isBid,
                orderId: orders[i].orderId,
                price: orders[i].price,
                amount: orders[i].amount,
                n: orders[i].n,
                recipient: orders[i].recipient
            });
            IMatchingEngine(orders[i].matchingEngine).updateOrder(updateOrderData);
        }
    }
}