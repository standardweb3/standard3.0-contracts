pragma solidity ^0.8.10;

import "./TransferHelper.sol";

interface ITreasury {
    function balanceOf(
        address owner_,
        uint256 id_
    ) external view returns (uint256);

    function metaId(uint32 id_) external view returns (uint16);

    function getTotalPoints(uint32 nthEra_) external view returns (uint256);

    function getTotalTokens(
        uint32 nthEra_,
        address token_
    ) external view returns (uint256);

    function subtractMP(uint32 uid_, uint32 nthEra_, uint64 point_) external;
}

library TreasuryLib {
    struct Storage {
        address accountant;
        address sabt;
        mapping(uint32 => uint32) claims;
        uint32 totalClaim;
        uint32 settlementId;
    }

    uint8 constant USER_META_ID = 0;
    uint8 constant INVESTOR_META_ID = 1;
    uint8 constant FOUNDATION_META_ID = 2;

    uint32 constant denom = 100000;

    struct Claim {
        uint32 num;
        uint32 denom;
    }

    function _checkMembership(
        Storage storage self,
        uint32 uid_,
        uint8 metaId_
    ) internal view {
        // the sender owns the membership with UID
        require(ITreasury(self.sabt).balanceOf(msg.sender, uid_) > 0, "IA");
        require(ITreasury(self.sabt).metaId(uid_) == metaId_, "IM");
    }

    function _exchange(
        Storage storage self,
        address token,
        uint32  nthEra,
        uint32 uid,
        uint64 point
    ) internal {
        // check if the sender has UID with user meta id
        _checkMembership(self, uid, USER_META_ID);
        // subtract membership point in accountant
        ITreasury(self.accountant).subtractMP(uid, nthEra, point);
        // exchange membership point with reward
        uint256 reward = _getReward(self, token, nthEra, point);
        // exchange reward with token
        TransferHelper.safeTransfer(token, msg.sender, reward);
    }

    function _claim(
        Storage storage self,
        address token,
        uint32  nthEra,
        uint32 uid
    ) internal {
        // check if the sender has UID with investor meta id
        _checkMembership(self, uid, INVESTOR_META_ID);
        // get reward from accountant
        uint256 claim = _getClaim(self, token, uid, nthEra);
        // exchange reward with token
        TransferHelper.safeTransfer(token, msg.sender, claim);
    }

    function _settle(
        Storage storage self,
        address token,
        uint32  nthEra,
        uint32 uid
    ) internal {
        // check if the sender has UID with foundation meta id
        _checkMembership(self, uid, FOUNDATION_META_ID);
        uint256 settlement = _getSettlement(self, token, nthEra);
        TransferHelper.safeTransfer(token, msg.sender, settlement);
    }

    function _setClaim(Storage storage self, uint32 uid, uint32 num) internal {
        self.claims[uid] = num;
        self.totalClaim += num;
        require(self.totalClaim <= 600000, "OVERFLOW");
    }

    function _setSettlement(
        Storage storage self,
        uint32 uid
    ) internal {
        self.settlementId = uid;
    }

    function _getReward(
        Storage storage self,
        address token,
        uint32  nthEra,
        uint256 point
    ) internal view returns (uint256) {
        // get reward from Treasury ratio
        // 1. get total supply of mp
        uint256 totalMP = ITreasury(self.accountant).getTotalPoints(nthEra);
        // 2. get fee collected on nthEra
        uint256 totalTokens = ITreasury(self.accountant).getTotalTokens(
            nthEra,
            token
        );
        // 3. get reward from community Treasury ratio
        return ((point * totalTokens * 4) / 10) / totalMP;
    }

    function _getClaim(
        Storage storage self,
        address token,
        uint32 uid,
        uint32 nthEra
    ) internal view returns (uint256) {
        // check if sender has UID
        require(ITreasury(self.sabt).balanceOf(msg.sender, uid) != 0, "NO_UID");
        // 1. get fee collected on nthEra
        uint256 totalTokens = ITreasury(self.accountant).getTotalTokens(
            nthEra,
            token
        );
        // 2. get reward from community Treasury ratio
        return ((totalTokens * (self.claims[uid])) / denom);
    }

    function _getSettlement(
        Storage storage self,
        address token,
        uint32 nthEra
    ) internal view returns (uint256) {
        // check if sender has UID
        require(ITreasury(self.sabt).balanceOf(msg.sender, self.settlementId) != 0, "NO_UID");
        // 1. get fee collected on nthEra
        uint256 totalTokens = ITreasury(self.accountant).getTotalTokens(
            nthEra,
            token
        );
        // 2. get reward from community Treasury ratio
        return ((totalTokens * (600000 - self.totalClaim)) / denom);
    }
}
