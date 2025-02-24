// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

interface IPerpFutures {
    // admin functions
    function setFeeTo(address feeTo_) external returns (bool success);
    function setDefaultLeverageLimit(uint32 long, uint32 short) external returns (bool success);
    function setLeverageLimit(address base, address quote, address collateral, uint32 long, uint32 short)
        external
        returns (bool success);
    function setFees(uint32 openFee, uint32 closeFee, uint32 liqFee) external returns (bool success);

    // user functions
    function long(
        address base,
        address quote,
        uint256 price,
        address collateral,
        uint256 amount,
        uint32 leverage,
        address recipient
    ) external returns (uint256 mktPrice, uint256 markPrice, uint256 placed, uint32 positionId);

    function short(
        address base,
        address quote,
        uint256 price,
        address collateral,
        uint256 amount,
        uint32 leverage,
        address recipient
    ) external returns (uint256 mktPrice, uint256 markPrice, uint256 placed, uint32 positionId);

    function longETH(address base, address quote, uint256 price, uint256 amount, uint32 leverage, address recipient)
        external
        payable
        returns (uint256 mktPrice, uint256 makePrice, uint256 placed, uint32 id);

    function shortETH(address base, address quote, uint256 price, uint256 amount, uint32 leverage, address recipient)
        external
        payable
        returns (uint256 mktPrice, uint256 makePrice, uint256 placed, uint32 id);

    function closePosition(address base, address quote, address collateral, bool isLong, uint32 positionId)
        external
        returns (uint32 id, uint256 markPrice, uint256 mktPrice, int256 pnl);

    function addPair(address base, address quote, address collateral, uint256 listingDate, address payment)
        external
        returns (address pair);

    function addPairETH(address base, address quote, address collateral, uint256 listingDate)
        external
        returns (address pair);

    function closePositions(
        address[] memory base,
        address[] memory quote,
        address[] memory collateral,
        bool[] memory isLong,
        uint32[] memory orderIds
    )
        external
        returns (uint32[] memory id, uint256[] memory markPrice, uint256[] memory mktPrice, int256[] memory pnl);

    function liquidate(address base, address quote, address collateral, uint32 positionId)
        external
        returns (uint256 pnl);

    function getPositionById(uint256 id) external view returns (address);

    function getPrices(address base, address quote, address collateral, bool isLong, uint32 n)
        external
        view
        returns (uint256[] memory);

    function getPositions(address base, address quote, bool isBid, uint256 price, uint32 n)
        external
        view
        returns (address[] memory);

    function getPosition(address base, address quote, address collateral, bool isLong, uint32 positionId)
        external
        view
        returns (address);

    function getPositionIds(address base, address quote, bool isBid, uint256 price, uint32 n)
        external
        view
        returns (uint32[] memory);

    function getPool(address base, address quote, address collateral) external view returns (address pool);

    function heads(address base, address quote, address collateral)
        external
        view
        returns (uint256 longHead, uint256 shortHead);

    function mktPrice(address base, address quote, address collateral) external view returns (uint256);

    function pnl(address base, address quote, address collateral, uint256 amount, uint256 markPrice, bool isLong)
        external
        view
        returns (uint256 converted);

    function fees() external view returns (uint32 openFee, uint32 closeFee, uint32 liqFee);
}
