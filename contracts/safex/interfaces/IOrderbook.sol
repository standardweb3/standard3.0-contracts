// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;
import "../libraries/NewOrderOrderbook.sol";

interface IOrderbook {

    function initialize(
        uint256 id,
        address base_,
        address quote_,
        address engine_
    ) external;

    function fpop(bool isAsk, uint256 price) external returns (uint256 orderId);

    function setLmp(uint256 lmp) external;

    function mktPrice() external view returns (uint256);

    function assetValue(
        uint256 amount,
        bool isAsk
    ) external view returns (uint256 converted);

    function isEmpty(bool isAsk, uint256 price) external view returns (bool);

    function getRequired(
        bool isAsk,
        uint256 price,
        uint256 orderId
    ) external view returns (uint256 required);

    function placeAsk(address owner, uint256 price, uint256 amount) external;

    function placeBid(address owner, uint256 price, uint256 amount) external;

    function cancelOrder(
        uint256 orderId,
        bool isAsk,
        address owner
    ) external returns (uint256 remaining, address base, address quote);

    function execute(
        uint256 orderId,
        bool isAsk,
        uint256 price,
        address sender,
        uint256 amount
    ) external returns (address owner);

    function heads() external view returns (uint256 askHead, uint256 bidHead);

    function bidHead() external view returns (uint256);

    function askHead() external view returns (uint256);

    function getPrices(
        bool isAsk,
        uint256 n
    ) external view returns (uint256[] memory);

    function getOrders(
        bool isAsk,
        uint256 price,
        uint256 n
    ) external view returns (NewOrderOrderbook.Order[] memory);

    function getOrder(
        bool isAsk,
        uint256 orderId
    ) external view returns (NewOrderOrderbook.Order memory);

    function getOrderIds(
        bool isAsk,
        uint256 price,
        uint256 n
    ) external view returns (uint256[] memory);
}
