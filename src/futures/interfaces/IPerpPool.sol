// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import "../libraries/FuturesPool.sol";
interface IPerpPool {
   function initialize(
        uint256 id_,
        address base_,
        address quote_,
        address collateral_,
        address engine_,
        address perp_
    ) external;

    function placeShort(
        address owner,
        uint256 price,
        uint256 amount,
        bool autoUpdate
    ) external returns (uint32 id);

    function placeLong(
        address owner,
        uint256 price,
        uint256 amount,
        bool autoUpdate
    ) external returns (uint32 id);

    function closePosition(
        bool isLong,
        uint256 positionId,
        address owner
    ) external returns (uint256 remaining);

    function liquidate(
        bool isLong,
        uint32 positionId
    ) external returns (address owner);

    function getPosition(
        bool isLong,
        uint32 positionId
    ) external view returns (FuturesPool.Position memory);
}
