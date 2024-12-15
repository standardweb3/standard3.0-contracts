// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import {IPerpFutures} from "../interfaces/IPerpFutures.sol";

library FuturesPool {
    // Position struct
    struct Position {
        address owner;
        uint256 entryPrice;
        uint32 leverage;
        uint256 margin;
        bool autoUpdate;
    }

    uint32 public constant feeDenom = 10000;

    // Position State
    struct PositionStorage {
        mapping(uint256 => Position) positions;
        // count of the orders, used for array allocation
        uint256 count;
        address perp;
    }

    error PositionIdIsZero(uint256 id);
    error MarkPriceIsZero(uint256 price);

    function _createPosition(
        PositionStorage storage self,
        address owner,
        uint256 entryPrice,
        uint256 margin,
        uint32 leverage,
        bool autoUpdate
    ) internal returns (uint256 id) {
        if (entryPrice == 0) {
            revert MarkPriceIsZero(entryPrice);
        }
        Position memory order = Position({
            owner: owner,
            entryPrice: entryPrice,
            margin: margin,
            leverage: leverage == 0 ? 1 : leverage,
            autoUpdate: autoUpdate
        });
        // In order to prevent order overflow, order id must start from 1
        self.count = self.count == 0 || self.count == type(uint256).max
            ? 1
            : self.count + 1;
        self.positions[self.count] = order;
        return self.count;
    }

    function _liquidate(
        PositionStorage storage self,
        uint256 id
    ) internal returns (uint256 feeFund, uint256 poolFund) {
        (, , uint32 liqBP) = _fees(self);
        Position memory position = self.positions[id];
        // send the remaining margin to the pool
        feeFund = (position.margin * liqBP) / feeDenom;
        poolFund = position.margin - feeFund;
        delete self.positions[id];
        return (feeFund, poolFund);
    }

    function _increaseMargin(
        PositionStorage storage self,
        uint256 id,
        uint256 amount
    ) internal returns (uint256 margin) {
        margin = self.positions[id].margin + amount;
        self.positions[id].margin = margin;
        return margin;
    }

    function _decreaseMargin(
        PositionStorage storage self,
        uint256 id,
        uint256 amount,
        uint256 dust,
        bool clear
    ) internal returns (uint256 sendFund, uint256 deletePrice) {
        uint256 decreased = self.positions[id].margin < amount
            ? 0
            : self.positions[id].margin - amount;
        // remove dust
        if (decreased <= dust || clear) {
            decreased = self.positions[id].margin;
            deletePrice = _deletePosition(self, id);
            return (decreased, deletePrice);
        } else {
            self.positions[id].margin = decreased;
            return (amount, deletePrice);
        }
    }

    function _deletePosition(
        PositionStorage storage self,
        uint256 id
    ) internal returns (uint256 entryPrice) {
        entryPrice = self.positions[id].entryPrice;
        delete self.positions[id];
        return entryPrice;
    }

    function _getPosition(
        PositionStorage storage self,
        uint256 id
    ) internal view returns (Position memory) {
        return self.positions[id];
    }

    // get number of contracts(position size) from deposit and entry price
    function _contractsFromPosition(
        PositionStorage storage self,
        uint256 id
    ) internal view returns (uint256) {
        return
            _contracts(
                self.positions[id].margin,
                self.positions[id].entryPrice,
                self.positions[id].leverage
            );
    }

    function _contracts(
        uint256 margin,
        uint256 entryPrice,
        uint32 leverage
    ) internal pure returns (uint256) {
        uint256 notional = margin * leverage;
        return notional / entryPrice;
    }

    function _priceDiff(
        PositionStorage storage self,
        uint256 id,
        uint256 mktPrice,
        bool isLong
    ) internal view returns (int256) {
        return
            isLong
                ? int256(mktPrice) - int256(self.positions[id].entryPrice)
                : int256(self.positions[id].entryPrice) - int256(mktPrice);
    }

    function _fees(
        PositionStorage storage self
    ) internal view returns (uint32 openFee, uint32 closeFee, uint32 liqFee) {
        return IPerpFutures(self.perp).fees();
    }

    function _cost(
        PositionStorage storage self,
        uint256 id
    ) internal view returns (uint256) {
        (uint32 openBP, uint32 closeBP,) = _fees(self);
        uint256 open = (self.positions[id].margin * openBP) / feeDenom;
        uint256 close = (self.positions[id].margin * closeBP) / feeDenom;
        return open + close + self.positions[id].margin;
    }

    // breakeven price = entry price + (cost / position size in number of contracts)
    function _breakeven_price(
        PositionStorage storage self,
        uint256 id
    ) internal view returns (uint256) {
        return
            self.positions[id].entryPrice +
            _cost(self, id) /
            _contractsFromPosition(self, id);
    }

    // Position size * (mktPrice(current price) - entryPrice(entry price))
    function _pnl(
        PositionStorage storage self,
        uint256 id,
        uint256 mktPrice,
        bool isLong
    ) internal view returns (int256 pnl) {
        uint positionSize = _contractsFromPosition(self, id);

        return _priceDiff(self, id, mktPrice, isLong) * int256(positionSize);
    }

    // maintenance margin = position_size * mark_price / leverage * maintenance_margin_rate

    // position_size * mark_price / leverage
    function _initialMarginRequired(
        uint256 entryPrice,
        uint32 leverage,
        uint256 amount
    ) internal pure returns (uint256) {
        // position_size * mark_price / leverage
        return _contracts(entryPrice, amount, leverage);
    }

    /**
     * @dev Returns the maintenance margin in basis points for a given leverage in a position.
     * The maintenance margin is half of the initial margin at max leverage, which varies from 3-50x.
     * In other words, the maintenance margin is between 1% (for 50x max leverage assets) and 16.7% (for 3x max leverage assets) depending on the asset.
     * @param leverage The leverage of the asset (e.g., 3x, 50x, etc.)
     * @return maintenanceMargin The maintenance margin rate in basis points.
     */
    function _maintenanceMargin(
        uint32 leverage
    ) internal pure returns (uint256 maintenanceMargin) {
        return 5000 / leverage;
    }

    function _maintenanceMarginFromPosition(
        PositionStorage storage self,
        uint256 id
    ) internal view returns (uint256) {
        return _maintenanceMargin(self.positions[id].leverage);
    }

    // Positions are liquidated when the account value (including unrealized pnl) is less than the maintenance margin times the open notional position.
    function _isLiquidatable(
        PositionStorage storage self,
        uint256 id,
        uint256 mktPrice
    ) internal view returns (bool) {
        Position memory position = self.positions[id];
        uint256 positionSize = _contractsFromPosition(self, id);
        uint256 openNotional = positionSize * mktPrice;

        // Maintenance margin in bps
        uint256 maintenanceMarginBps = _maintenanceMarginFromPosition(self, id);

        // Compute pnl (Note: `_pnl` returns int256)
        int256 pnl = _pnl(self, id, mktPrice, true);

        // Account value = margin + pnl
        int256 accountValue = int256(position.margin) + pnl;

        // requiredMargin = (maintenanceMarginBps / 10000) * openNotional
        // cast to int256 to compare with accountValue
        int256 requiredMargin = int256(
            (openNotional * maintenanceMarginBps) / 10000
        );

        return accountValue < requiredMargin;
    }
}
