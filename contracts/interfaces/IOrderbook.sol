// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.5.0;

interface IOrderbook {
    function initialize(
        address base_,
        address quote_,
        address engine_
    ) external;

    function dequeue(uint256 price, bool isAsk)
        external
        returns (uint256 orderId);

    function mktPrice() external view returns (uint256);

    function length(uint256 price, bool isAsk) external view returns (uint256);

    function isEmpty(uint256 price, bool isAsk) external view returns (bool);

    function getOrderDepositAmount(uint256 orderId) external view returns (uint256 depositAmount); 

    function placeAsk(address owner, uint256 price, uint256 amount) external;

    function placeBid(address owner, uint256 price, uint256 amount) external;

    function execute(uint256 orderId, address sender, uint256 amount) external;

    function heads() external view returns (uint256 askHead, uint256 bidHead);
}
