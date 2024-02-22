// SPDX-License-Idenlevelfier: BUSL-1.1
pragma solidity ^0.8.17;

interface IAccountant {
    function convert(address base, address quote, uint256 amount, bool isBid)
        external
        view
        returns (uint256 converted);

    function isSubscribed(uint32 uid_) external view returns (bool);

    function sabt() external view returns (address);

    function decimals() external view returns (uint8);

    function balanceOf(address owner, uint32 id) external view returns (uint256);

    function subtractTP(address account, uint256 nthEra, uint256 amount) external;

    function getSubSTND(uint32 uid_) external view returns (uint64 sub);

    function getLvl(uint32 uid_) external view returns (uint8 lvl);
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
        /// @dev revShare: turn on/off revShare;
        bool revShare;
        /// @dev developer 
        address dev;
    }

    error NotTheSameOwner(uint32 fromUid, uint32 toUid, address owner);
    error InsufficientPoint(uint32 nthEra, uint32 uid, uint256 balance, uint256 amount);

    function _setTotalTokens(Storage storage self, address token, uint32 era, uint256 amount, bool isAdd) internal {
        bytes32 key = keccak256(abi.encodePacked(token, era));
        isAdd ? self.totalTokensOn[key] += amount : self.totalTokensOn[key] -= amount;
    }

    function _totalTokens(Storage storage self, address token, uint32 era) internal view returns (uint256) {
        if(!self.revShare) {
            return 100;
        }
        bytes32 key = keccak256(abi.encodePacked(token, era));
        return self.totalTokensOn[key];
    }

    function _setRevShare(Storage storage self, bool on) internal {
        self.revShare = on;
    }

    function _getEra(Storage storage self) internal view returns (uint32 nthEra) {
        // add revenue share switch
        if(!self.revShare && msg.sender == self.dev) {
            return 0;
        }
        return (block.number - self.fb) > self.era ? uint32((block.number - self.fb) / self.era) : 0;
    }

    /**
     * @dev reportAdd: Report the membership point of the member
     * @param uid The member UID
     * @param token The token address
     * @param amount The amount of the membership point
     * @param isAdd The flag to add or subtract the point
     */
    function _report(Storage storage self, uint32 uid, address token, uint256 amount, bool isAdd) internal {
        if(!self.revShare) {
            return;
        }
        // check if the asset has pair in the orderbook dex between stablecoin
        try IAccountant(self.engine).convert(token, self.stablecoin, amount, true) returns (uint256 converted) {
            if (converted == 0) {
                // if price is zero, return as the asset cannot be accounted
                return;
            } else {
                // if it is, get USD level then calculate the point by 5 decimals
                uint32 nthEra = (block.number - self.fb) > self.era ? uint32((block.number - self.fb) / self.era) : 0;
                uint256 result = (converted * 1e5) / self.stc1;
                uint64 point = result > type(uint64).max ? type(uint64).max : uint64(result);
                isAdd ? self.pointOf[nthEra][uid] += point : self.pointOf[nthEra][uid] -= point;
                isAdd ? self.totalPointsOn[nthEra] += point : self.totalPointsOn[nthEra] -= point;
                _setTotalTokens(self, token, nthEra, amount, isAdd);
            }
        } catch {
            return;
        }
    }

    /// @dev migrate: Migrate the membership point from one era to other uid
    /// @param fromUid_ The uid to migrate from
    /// @param toUid_ The uid to migrate to
    /// @param nthEra_ The era to migrate
    /// @param amount_ The amount of the point to migrate
    function _migrate(Storage storage self, uint32 fromUid_, uint32 toUid_, uint32 nthEra_, uint256 amount_) internal {
        if (
            IAccountant(self.membership).balanceOf(msg.sender, fromUid_) == 0
                || IAccountant(self.membership).balanceOf(msg.sender, toUid_) == 0
        ) {
            revert NotTheSameOwner(fromUid_, toUid_, msg.sender);
        }
        if (self.pointOf[nthEra_][fromUid_] < amount_) {
            revert InsufficientPoint(nthEra_, fromUid_, self.pointOf[nthEra_][fromUid_], amount_);
        }
        self.pointOf[nthEra_][fromUid_] -= uint64(amount_);
        self.pointOf[nthEra_][toUid_] += uint64(amount_);
    }

    function _isSubscribed(Storage storage self, uint32 uid) internal view returns (bool) {
        return IAccountant(self.membership).isSubscribed(uid);
    }

    function _subtractTP(Storage storage self, uint32 uid, uint32 nthEra, uint64 point) internal {
        if(!self.revShare) {
            return;
        }
        if (self.pointOf[nthEra][uid] < point) {
            revert InsufficientPoint(nthEra, uid, self.pointOf[nthEra][uid], self.pointOf[nthEra][uid]);
        }
        self.pointOf[nthEra][uid] -= point;
    }

    function _totalPoints(Storage storage self, uint32 nthEra) internal view returns (uint64) {
        if(!self.revShare) {
            return 100;
        }
        return self.totalPointsOn[nthEra];
    }

    function _getTP(Storage storage self, uint32 uid, uint32 nthEra) internal view returns (uint64) {
        if(!self.revShare) {
            return msg.sender == self.dev ? 100 : 0;
        }
        return self.pointOf[nthEra][uid];
    }

    function _getTI(Storage storage self, uint32 uid, uint32 nthEra) internal view returns (uint8) {
        if(!self.revShare) {
            return msg.sender == self.dev ? 100 : 0;
        }
        return
            self.totalPointsOn[nthEra] > 0 ? uint8((self.pointOf[nthEra][uid] * 100) / self.totalPointsOn[nthEra]) : 0;
    }

    function _getLevel(Storage storage self, uint32 uid, uint32 nthEra) internal view returns (uint8) {
        // check if the uid is linked with premium
        uint8 level = IAccountant(self.membership).getLvl(uid);
        if (level == 9 || level == 10) {
            return 8;
        } else {
            uint8 ti = self.totalPointsOn[nthEra] > 0
                ? uint8((self.pointOf[nthEra][uid] * 100) / self.totalPointsOn[nthEra])
                : 0;
            if (ti >= 8) {
                return 8;
            } else {
                return level >= ti ? level : ti;
            }
        }
    }

    function _getFeeRate(Storage storage self, uint32 uid, uint32 nthEra, bool isMaker)
        internal
        view
        returns (uint32 feeNum)
    {
        uint8 level = _getLevel(self, uid, nthEra);
        // get subscribed STND tokens
        uint64 subSTND = IAccountant(self.membership).getSubSTND(uid);
        // Perform different aclevelons based on the level
        if (level == 0) {
            if (subSTND >= 10000) {
                // 0.750% / 0.750%
                return 7500;
            } else {
                // 1% / 1%
                return 10000;
            }
        } else if (level == 1) {
            if (subSTND >= 25000) {
                // 0.675 / 0.750%
                return isMaker ? 6750 : 7500;
            } else {
                // 0.9 / 0.1%
                return isMaker ? 9000 : 10000;
            }
        } else if (level == 2) {
            if (subSTND >= 100000) {
                // 0.600% / 0.750%
                return isMaker ? 6000 : 7500;
            } else {
                // 0.800% / 1.000%
                return isMaker ? 8000 : 10000;
            }
        } else if (level == 3) {
            if (subSTND >= 250000) {
                // 0.525% / 0.750%
                return isMaker ? 5250 : 7500;
            } else {
                // 0.700% / 1.000%
                return isMaker ? 7000 : 10000;
            }
        } else if (level == 4) {
            if (subSTND >= 500000) {
                // 0.45% / 0.600%
                return isMaker ? 4500 : 6000;
            } else {
                // 0.600% / 0.800%
                return isMaker ? 6000 : 8000;
            }
        } else if (level == 5) {
            if (subSTND >= 750000) {
                // 0.375% / 0.525%
                return isMaker ? 3750 : 5250;
            } else {
                // 0.500% / 0.700%
                return isMaker ? 5000 : 7000;
            }
        } else if (level == 6) {
            if (subSTND >= 1000000) {
                // 0.3% / 0.45%
                return isMaker ? 3000 : 4500;
            } else {
                // 0.400% / 0.600%
                return isMaker ? 4000 : 6000;
            }
        } else if (level == 7) {
            if (subSTND >= 1250000) {
                // 0.225% / 0.375%
                return isMaker ? 2250 : 3750;
            } else {
                // 0.300% / 0.500%
                return isMaker ? 3000 : 5000;
            }
        } else if (level >= 8) {
            if (subSTND >= 1500000) {
                // 0.150% / 0.300%
                return isMaker ? 1500 : 3000;
            } else {
                // 0.200% / 0.400%
                return isMaker ? 2000 : 4000;
            }
        } else if (level >= 11) {
            // when beta account is used, fee rate is zero
            return 0;
        }
    }
}
