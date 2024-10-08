pragma solidity ^0.8.24;

import {TransferHelper} from "./TransferHelper.sol";

interface IPoint {
    function mint(
        address account,
        uint256 amount
    ) external returns (uint256 minted);
    function fine(
        address account,
        uint256 amount
    ) external returns (uint256 fined);
    function removePenalty(
        address account,
        uint256 amount
    ) external returns (uint256 removed);
    function mintMatch(
        address sender,
        address owner,
        uint256 sdrAmount,
        uint256 onrAmount
    ) external returns (uint256 sdrMinted, uint256 onrMinted);
}

interface IMatchingEngine {
    function convert(
        address base,
        address quote,
        uint256 amount,
        bool isBid
    ) external view returns (uint256 converted);
    function getPair(
        address base,
        address quote
    ) external view returns (address pair);
}

library PointAccountantLib {
    struct Event {
        uint256 startDate;
        /// end date timestamp in seconds
        uint256 endDate;
    }

    // multiplier decimal representing 4 decimals, 10000 = 1.0000x
    uint256 public constant DENOM = 10000;

    struct Multiplier {
        /// multiplier on buy order numerator with 4 decimals (e.g. 100.0000x)
        uint32 buy;
        /// multiplier on sell order numerator with 4 decimals (e.g. 100.0000x)
        uint32 sell;
    }

    struct State {
        mapping(uint64 => Event) events;
        mapping(address => Multiplier) multipliers;
        /// multiplier on buy order numerator with 4 decimals (e.g. 100.0000x)
        uint32 baseMultiplier;
        address point;
        address matchingEngine;
        /// stablecoin address
        address stablecoin;
        /// one in stablecoin decimal
        uint256 scOne;
        uint32 currentEvent;
    }

    error DateNotInRange(uint256 startDate, uint256 endDate);
    error EventOverlaps(uint256 prevEndDate, uint256 newStartDate);
    error EventAlreadyPassed(uint32 eventId, uint32 currentEventId);
    error EventStillOn(uint32 eventId, uint256 endDate);
    error InvalidAddress(address addr);

    function _setStablecoin(
        State storage self,
        address stablecoin
    ) internal returns (bool) {
        if (stablecoin == address(0)) {
            revert InvalidAddress(stablecoin);
        }
        self.stablecoin = stablecoin;
        self.scOne = 10 ** TransferHelper.decimals(stablecoin);
        return true;
    }

    function _setBaseMultiplier(
        State storage self,
        uint32 x
    ) internal returns (uint32) {
        self.baseMultiplier = x;
    }

    function _setMultiplier(
        State storage self,
        address base,
        address quote,
        bool isBid,
        uint32 x
    ) internal returns (address pair) {
        pair = IMatchingEngine(self.matchingEngine).getPair(base, quote);
        if (isBid) {
            self.multipliers[pair].buy = x;
        } else {
            self.multipliers[pair].sell = x;
        }
        return pair;
    }

    function _createEvent(
        State storage self,
        uint256 startDate,
        uint256 endDate
    ) internal returns (uint32 eventId) {
        if (self.currentEvent == 0) {
            self.currentEvent = 1;
            if (startDate > endDate) {
                revert DateNotInRange(startDate, endDate);
            }
            self.events[self.currentEvent].startDate = startDate;
            self.events[self.currentEvent].endDate = endDate;
        } else {
            Event memory prevEvent = self.events[self.currentEvent];
            // check if the current event passed
            if (block.timestamp < prevEvent.endDate) {
                revert EventStillOn(self.currentEvent, prevEvent.endDate);
            }
            if (startDate < prevEvent.endDate) {
                revert EventOverlaps(prevEvent.endDate, startDate);
            }
            self.currentEvent += 1;
            if (startDate > endDate) {
                revert DateNotInRange(startDate, endDate);
            }
            self.events[self.currentEvent].startDate = startDate;
            self.events[self.currentEvent].endDate = endDate;
        }
        return self.currentEvent;
    }

    function _setEvent(State storage self, uint256 endDate) internal {
        self.events[self.currentEvent].endDate = endDate;
    }

    function _getEvent(
        State storage self,
        uint32 eventId
    ) internal view returns (Event memory pEvent) {
        return self.events[eventId];
    }

    function _checkEventOn(
        State storage self
    ) internal view returns (bool isEventOn) {
        if (self.currentEvent == 0) {
            return false;
        }
        return
            block.timestamp <= self.events[self.currentEvent].endDate &&
            block.timestamp >= self.events[self.currentEvent].startDate;
    }

    function _getMultiplier(
        State storage self,
        address pair,
        bool isBid
    ) internal view returns (uint32 x) {
        return isBid ? self.multipliers[pair].buy : self.multipliers[pair].sell;
    }

    function _reportCancel(
        State storage self,
        uint32 uid,
        address base,
        address quote,
        bool isBid,
        address account,
        uint256 amount,
        uint32 pointx
    ) internal returns (uint256 points) {
        // check uid
        // if a user just wants to save gas, set uid 0 and don't participate in event
        if (uid == 0) {
            return 0;
        }
        // check event id and end date
        if (!_checkEventOn(self)) {
            return 0;
        }

        // compute usdt value
        address asset = isBid ? quote : base;
        address pair = IMatchingEngine(self.matchingEngine).getPair(base, quote);
        uint256 stablecoinValue = IMatchingEngine(self.matchingEngine).convert(
            asset,
            self.stablecoin,
            amount,
            true
        );
        uint32 multipliers = self.baseMultiplier *
            _getMultiplier(self, pair, isBid);
        // points = (multipliers in 4 decimals x2) * (point decimal) / (denominator x3) * (stablecoin value decimal)
        points =
            (((multipliers * stablecoinValue) * 1e18 * pointx) / (1e12)) *
            self.scOne;
        IPoint(self.point).fine(account, points);
        return (points);
    }

    function _report(
        State storage self,
        address orderbook,
        address give,
        bool isBid,
        address sender,
        address owner,
        uint256 amount,
        uint32 sndPointx,
        uint32 onrPointx
    ) internal returns (uint256 points) {
        // check uid
        // if a user just wants to save gas, set uid 0 and don't participate in event
        /*
        if (saveGas) {
            return 0;
        }
        */
        // check event id and end date
        if (!_checkEventOn(self)) {
            return 0;
        }

        // compute usdt value
        uint256 stablecoinValue = IMatchingEngine(self.matchingEngine).convert(
            give,
            self.stablecoin,
            amount,
            true
        );

        uint256 snd = _getPointAmount(self, orderbook, isBid, stablecoinValue, sndPointx);
        uint256 onr = _getPointAmount(self, orderbook, isBid, stablecoinValue, onrPointx);

        IPoint(self.point).mintMatch(
            sender,
            owner,
            snd,
            onr
        );

        return (points);
    }

    function _getPointAmount(
        State storage self,
        address orderbook,
        bool isBid,
        uint256 stablecoinValue,
        uint32 pointx
    ) internal view returns (uint256 point) {
        uint32 multipliers = self.baseMultiplier *
            _getMultiplier(self, orderbook, isBid);
        uint256 numerator = multipliers * stablecoinValue * pointx * 1e18;
        uint256 denominator = 1e12 * self.scOne;
        return numerator / denominator;
    }

    function _reportBonus(
        State storage self,
        address account,
        uint256 amount
    ) internal returns (bool) {
        IPoint(self.point).mint(account, amount);
        return true;
    }

    function _reportPenalty(
        State storage self,
        address account,
        uint256 amount
    ) internal returns (bool) {
        IPoint(self.point).fine(account, amount);
        return true;
    }

    function _removePenalty(
        State storage self,
        address account,
        uint256 amount
    ) internal returns (bool) {
        IPoint(self.point).removePenalty(account, amount);
        return true;
    }
}
