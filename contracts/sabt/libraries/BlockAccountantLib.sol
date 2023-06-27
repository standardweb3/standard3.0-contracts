// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface IAccountant {
    function convert(
        address base,
        address quote,
        uint256 amount,
        bool isBid
    ) external view returns (uint256 converted);

    function isSubscribed(uint32 uid_) external view returns (bool);

    function decimals() external view returns (uint8);

    function balanceOf(
        address owner,
        uint256 id
    ) external view returns (uint256);

    function subtractMP(
        address account,
        uint256 nthEra,
        uint256 amount
    ) external;
}

/// @author Hyungsuk Kang <hskang9@gmail.com>
/// @title Standard Membership Accountant to report membership points
library BlockAccountantLib {
    struct Storage {
        uint256 fb;
        /// @dev pointOf: The mapping of the month to the mapping of the member UID to the point, each accountant can account 4,294,967,295 eras, each era is 28 days
        mapping(uint32 => mapping(uint32 => uint64)) pointOf;
        /// @dev totalPointsOn: The mapping of the month to the total point of the month
        mapping(uint32 => uint64) totalPointsOn;
        /// @dev totalTokensOn: The mapping of the token address to the mapping of the month to the total token amount of the month
        mapping(bytes32 => uint256) totalTokensOn;
        /// @dev refundOf: The mapping of the member UID to the refund amount
        mapping(uint32 => uint256) refundOf;
        /// @dev membership: The address of the membership contract
        address membership;
        /// @dev engine: The address of the orderbook dex entry point
        address engine;
        /// @dev treasury: The address of the treasury contract
        address treasury;
        /// @dev stablecoin: The address of the stablecoin contract
        address stablecoin;
        /// @dev stc1: One stablecoin with decimals 
        uint256 stc1;
        /// @dev spb: The number of seconds per a block
        uint32 spb;
        /// @dev era: The number of blocks per an era
        uint32 era;
    }

    error NotTheSameOwner(uint32 fromUid, uint32 toUid, address owner);
    error InsufficientPoint(uint32 nthEra, uint32 uid, uint256 amount);

    function _setTotalTokens(
        Storage storage self,
        address token,
        uint32 era,
        uint256 amount,
        bool isAdd
    ) internal {
        bytes32 key = keccak256(abi.encodePacked(token, era));
        isAdd
            ? self.totalTokensOn[key] += amount
            : self.totalTokensOn[key] -= amount;
    }

    function _totalTokens(
        Storage storage self,
        address token,
        uint32 era
    ) internal view returns (uint256) {
        bytes32 key = keccak256(abi.encodePacked(token, era));
        return self.totalTokensOn[key];
    }

    function _getEra(
        Storage storage self
    ) internal view returns (uint32 nthEra) {
        return
            (block.number - self.fb) > self.era
                ? uint32((block.number - self.fb) / self.era)
                : 0;
    }

    /**  @dev reportAdd: Report the membership point of the member
     * @param uid The member UID
     * @param token The token address
     * @param amount The amount of the membership point
     * @param isAdd The flag to add or subtract the point
     */
    function _report(
        Storage storage self,
        uint32 uid,
        address token,
        uint256 amount,
        bool isAdd
    ) internal {
        // check if the asset has pair in the orderbook dex between stablecoin
        uint256 converted = IAccountant(self.engine).convert(
            token,
            self.stablecoin,
            amount,
            true
        );
        if (converted == 0) {
            // if price is zero, return as the asset cannot be accounted
            return;
        } else {
            // if it is, get USD value then calculate the point by 5 decimals
            uint32 nthEra = (block.number - self.fb) > self.era
                ? uint32((block.number - self.fb) / self.era)
                : 0;
            uint256 result = (converted * 1e5) /
                self.stc1;
            uint64 point = result > type(uint64).max
                ? type(uint64).max
                : uint64(result);
            isAdd
                ? self.pointOf[nthEra][uid] += point
                : self.pointOf[nthEra][uid] -= point;
            isAdd
                ? self.totalPointsOn[nthEra] += point
                : self.totalPointsOn[nthEra] -= point;
            _setTotalTokens(self, token, nthEra, amount, isAdd);
        }
    }

    /// @dev migrate: Migrate the membership point from one era to other uid
    /// @param fromUid_ The uid to migrate from
    /// @param toUid_ The uid to migrate to
    /// @param nthEra_ The era to migrate
    /// @param amount_ The amount of the point to migrate
    function _migrate(
        Storage storage self,
        address sender,
        uint32 fromUid_,
        uint32 toUid_,
        uint32 nthEra_,
        uint256 amount_
    ) internal {
        if (
            IAccountant(self.membership).balanceOf(sender, fromUid_) == 0 ||
            IAccountant(self.membership).balanceOf(sender, toUid_) == 0
        ) {
            revert NotTheSameOwner(fromUid_, toUid_, sender);
        }
        if (self.pointOf[nthEra_][fromUid_] < amount_) {
            revert InsufficientPoint(nthEra_, fromUid_, amount_);
        }
        self.pointOf[nthEra_][fromUid_] -= uint64(amount_);
        self.pointOf[nthEra_][toUid_] += uint64(amount_);
    }

    function _isSubscribed(
        Storage storage self,
        uint32 uid
    ) internal view returns (bool) {
        return IAccountant(self.membership).isSubscribed(uid);
    }

    function _subtractMP(
        Storage storage self,
        uint32 uid,
        uint32 nthEra,
        uint64 point
    ) internal {
        if (self.pointOf[nthEra][uid] < point) {
            revert InsufficientPoint(nthEra, uid, self.pointOf[nthEra][uid]);
        }
        self.pointOf[nthEra][uid] -= point;
    }

    function _totalPoints(
        Storage storage self,
        uint32 nthEra
    ) internal view returns (uint64) {
        return self.totalPointsOn[nthEra];
    }

    function _getMP(
        Storage storage self,
        uint32 uid,
        uint32 nthEra
    ) internal view returns (uint64) {
        return self.pointOf[nthEra][uid];
    }
}
