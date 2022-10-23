// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.5.0;

interface IOrderbook {
    function pairInfo()
        external
        returns (
            string memory,
            uint256,
            address,
            address
        );

    function initialize(
        uint256 id_,
        string memory pairName_,
        address bid_,
        address ask_,
        address orderFactory_,
        address engine_
    ) external;

    function dequeue(uint256 price, bool isAsk)
        external
        returns (uint256 orderId);

    function length(uint256 price, bool isAsk) external view returns (uint256);

    function isEmpty(uint256 price, bool isAsk) external view returns (bool);

    function engine() external view returns (address);

    function id() external view returns (uint256 bookId);

    function getOrder(uint256 orderId) external view returns (address order); 

    function getQuote(address deposit) external view returns (address quote);

    function placeAsk(uint256 price, uint256 amount) external;

    function placeBid(uint256 price, uint256 amount) external;
}
