// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import {IPerpPool} from "../interfaces/IPerpPool.sol";
import {Initializable} from "../../security/Initializable.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";
import {FuturesPool} from "../libraries/FuturesPool.sol";

interface IWETHMinimal {
    function WETH() external view returns (address);

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

contract PerpPool is IPerpPool, Initializable {
    using FuturesPool for FuturesPool.PositionStorage;

    // Pool Struct
    struct Pool {
        uint256 id;
        address base;
        address quote;
        address collateral;
        address engine;
        address perp;
    }

    Pool private pool;

    uint256 collateralOne;

    FuturesPool.PositionStorage private _shortPositions;
    FuturesPool.PositionStorage private _longPositions;

    error InvalidDecimals(uint8 base, uint8 quote);
    error InvalidAccess(address sender, address allowed);
    error PriceIsZero(uint256 price);

    function initialize(
        uint256 id_,
        address base_,
        address quote_,
        address collateral_,
        address engine_,
        address perp_
    ) external initializer {
        uint8 baseD = TransferHelper.decimals(base_);
        uint8 quoteD = TransferHelper.decimals(quote_);
        uint8 collD = TransferHelper.decimals(collateral_);
        if (baseD > 18 || quoteD > 18) {
            revert InvalidDecimals(baseD, quoteD);
        }
        collateralOne = 10 ** (collD);
        pool = Pool(id_, base_, quote_, collateral_, engine_, perp_);
    }

    modifier onlyEngine() {
        if (msg.sender != pool.engine) {
            revert InvalidAccess(msg.sender, pool.engine);
        }
        _;
    }

    function placeShort(
        address owner,
        uint256 price,
        uint256 amount,
        uint32 leverage,
        bool autoUpdate
    ) external onlyEngine returns (uint32 id) {
        _shortPositions._createPosition(
            owner,
            price,
            amount,
            leverage,
            autoUpdate
        );
        return id;
    }

    function placeLong(
        address owner,
        uint256 price,
        uint256 amount,
        uint32 leverage,
        bool autoUpdate
    ) external onlyEngine returns (uint32 id) {
        _longPositions._createPosition(
            owner,
            price,
            amount,
            leverage,
            autoUpdate
        );
        return id;
    }

    function closePosition(
        bool isLong,
        uint256 positionId,
        address owner
    ) external onlyEngine returns (uint256 remaining) {
        // check position owner
        FuturesPool.Position memory position = isLong
            ? _longPositions._getPosition(positionId)
            : _shortPositions._getPosition(positionId);

        if (position.owner != owner) {
            revert InvalidAccess(owner, position.owner);
        }

        isLong
            ? _sendFunds(pool.quote, owner, position.margin)
            : _sendFunds(pool.base, owner, position.margin);

        return (position.margin);
    }

    function liquidate(
        bool isLong,
        uint32 positionId
    ) public onlyEngine returns (address owner) {
        FuturesPool.Position memory position = isLong
            ? _longPositions._getPosition(positionId)
            : _shortPositions._getPosition(positionId);
        // if isLong == true, sender is matching ask position with bid position(i.e. selling base to receive quote), otherwise sender is matching bid position with ask position(i.e. buying base with quote)
        if (isLong) {
            _longPositions._liquidate(positionId);
        }
        // if the position is bid position on the base/quote pool
        else {
            _shortPositions._liquidate(positionId);
        }
        return position.owner;
    }

    function batchLiquidate(
        bool[] memory isLong,
        uint32[] memory positionId
    ) external onlyEngine returns (address owner) {
        for (uint i = 0; i < positionId.length; i++) {
            liquidate(isLong[i], positionId[i]);
        }
    }

    function _sendFunds(
        address token,
        address to,
        uint256 amount
    ) internal returns (bool) {
        address weth = IWETHMinimal(pool.engine).WETH();
        if (token == weth) {
            IWETHMinimal(weth).withdraw(amount);
            return payable(to).send(amount);
        } else {
            TransferHelper.safeTransfer(token, to, amount);
            return true;
        }
    }

    function _absdiff(uint8 a, uint8 b) internal pure returns (uint8, bool) {
        return (a > b ? a - b : b - a, a > b);
    }

    function getPosition(
        bool isLong,
        uint32 positionId
    ) external view returns (FuturesPool.Position memory) {
        return
            isLong
                ? _longPositions._getPosition(positionId)
                : _shortPositions._getPosition(positionId);
    }

    receive() external payable {
        assert(msg.sender == IWETHMinimal(pool.engine).WETH());
    }

    function placeShort(
        address owner,
        uint256 price,
        uint256 amount,
        bool autoUpdate
    ) external override returns (uint32 id) {}

    function placeLong(
        address owner,
        uint256 price,
        uint256 amount,
        bool autoUpdate
    ) external override returns (uint32 id) {}
}
