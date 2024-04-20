// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import {TransferHelper} from "./TransferHelper.sol";

interface IPass {
    function mint(address to_, uint8 metaId_) external returns (uint32);

    function balanceOf(address owner_, uint256 uid_) external view returns (uint256);

    function setRegistered(uint256 id_, bool yesOrNo) external;

    function metaId(uint32 uid_) external view returns (uint8);

    function setMeta(uint32 uid_, uint8 meta_) external;

    function getLvl(uint32 uid_) external view returns (uint8);
}

interface IWETHMinimal {
    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
}

library MembershipLib {
    struct Member {
        /// @dev mapping of member id to subscription status
        mapping(uint32 => SubStatus) subscriptions;
        /// @dev mapping of subscribed STND of member id
        mapping(uint32 => uint64) subSTND;
        /// @dev mapping of meta id to register fee status
        mapping(uint8 => Meta) metas;
        /// @dev mapping of meta id to register fee status
        mapping(uint8 => mapping(address => Fees)) fees;
        /// @dev address of pass
        address pass;
        /// @dev address of STND
        address stnd;
        /// @dev address of foundation
        address foundation;
        /// @dev address of WETH
        address weth;
    }

    struct SubStatus {
        uint256 at;
        uint256 until;
        uint256 bonus;
        address with;
    }

    struct Meta {
        uint8 metaId;
        uint32 quota;
    }

    struct Fees {
        address feeToken;
        // One time registration fee token amount
        uint256 regFee;
        // fee token amount to pay per block
        uint256 subFee;
    }

    error InvalidFeeToken(address feeToken_, uint8 metaId_);
    error MembershipNotOwned(uint32 uid, address owner);
    error NoMultiTokenAccounting(address subscribedWith, address feeToken_);

    function _setMembership(
        Member storage self,
        uint8 metaId_,
        address feeToken_,
        uint256 regFee_,
        uint256 subFee_,
        uint32 quota_
    ) internal {
        self.metas[metaId_].metaId = metaId_;
        self.fees[metaId_][feeToken_].regFee = regFee_;
        self.fees[metaId_][feeToken_].subFee = subFee_;
        self.metas[metaId_].quota = quota_;
    }

    function _setQuota(Member storage self, uint8 metaId_, uint32 quota_) internal {
        self.metas[metaId_].quota = quota_;
    }

    function _setMeta(Member storage self, uint32 uid_, uint8 metaId_) internal {
        IPass(self.pass).setMeta(uid_, metaId_);
    }

    function _setSTND(Member storage self, address stnd) internal {
        self.stnd = stnd;
    }

    function _setFees(Member storage self, uint8 metaId_, address feeToken_, uint256 regFee_, uint256 subFee_)
        internal
    {
        self.fees[metaId_][feeToken_].regFee = regFee_;
        self.fees[metaId_][feeToken_].subFee = subFee_;
    }

    function _register(Member storage self, uint8 metaId_, address feeToken_, bool isDev) internal returns (uint32 uid) {
        if(!isDev) {
            uint256 regFee = self.fees[metaId_][feeToken_].regFee;
            // check if the fee token is supported
            if (regFee == 0) {
                revert InvalidFeeToken(feeToken_, metaId_);
            }
            // Transfer required fund
            TransferHelper.safeTransferFrom(feeToken_, msg.sender, address(this), regFee);
            TransferHelper.safeTransfer(feeToken_, self.foundation, regFee);
        }
        // issue membership from pass and get id
        return IPass(self.pass).mint(msg.sender, metaId_);
    }

    /// @dev subscribe: Subscribe to the membership until certain block height
    /// @param uid_ The uid of the ABT to subscribe with
    /// @param feeToken_ address of the token contract to pay as fee
    /// @param blocks_ The number of blocks to subscribe
    function _subscribe(Member storage self, uint32 uid_, address feeToken_, uint64 blocks_) internal returns (uint256 at, uint256 until, address with) {
        // check if the member has the ABT with input id
        if (IPass(self.pass).balanceOf(msg.sender, uid_) == 0) {
            revert MembershipNotOwned(uid_, msg.sender);
        }
        uint256 bh = block.number;
        uint8 metaId = IPass(self.pass).metaId(uid_);
        SubStatus memory sub = self.subscriptions[uid_];
        Fees memory fees = self.fees[metaId][feeToken_];
        // check if previous subscription was done with the same token
        if (sub.with != address(0) && sub.with != feeToken_) {
            // if not, Ask user to unsubscribed with the previous token subscription
            revert NoMultiTokenAccounting(sub.with, feeToken_);
        }
        // Transfer what has been already paid
        TransferHelper.safeTransfer(
            feeToken_,
            self.foundation,
            sub.until > bh ? fees.subFee * uint256(bh - sub.at) : fees.subFee * uint256(sub.until - sub.at)
        );
        // Transfer the tokens to this contract
        TransferHelper.safeTransferFrom(feeToken_, msg.sender, address(this), fees.subFee * uint256(blocks_));

        // subscribe for certain block
        self.subscriptions[uid_].at = bh;
        self.subscriptions[uid_].until = bh + blocks_;
        self.subscriptions[uid_].with = feeToken_;
        // if feeToken is STND, add it to the subSTND;
        if (feeToken_ == self.stnd) {
            self.subSTND[uid_] += uint64((fees.subFee * blocks_) / 1e18);
        }
        return (self.subscriptions[uid_].at, self.subscriptions[uid_].until, self.subscriptions[uid_].with);
    }

    /// @dev unsubscribe: Unsubscribe from the membership
    /// @param uid_ The id of the ABT to unsubscribe with
    function _unsubscribe(Member storage self, uint32 uid_) internal {
        // check if the member has the ABT with input id
        if (IPass(self.pass).balanceOf(msg.sender, uid_) == 0) {
            revert MembershipNotOwned(uid_, msg.sender);
        }
        uint256 bh = block.number;
        uint8 metaId = IPass(self.pass).metaId(uid_);
        SubStatus memory sub = self.subscriptions[uid_];
        Fees memory fees = self.fees[metaId][sub.with];
        if (sub.until > bh) {
            // Transfer what has been already paid to foundation
            TransferHelper.safeTransfer(sub.with, self.foundation, fees.subFee * (bh - sub.at));
            if (sub.until - bh > sub.bonus) {
                // Refund the tokens for future subscription to this contract
                TransferHelper.safeTransfer(sub.with, msg.sender, fees.subFee * (sub.until - bh - sub.bonus));
            }
        }
        // unsubscribe
        self.subscriptions[uid_].until = 0;
        self.subscriptions[uid_].at = 0;
        self.subscriptions[uid_].bonus = 0;
        self.subscriptions[uid_].with = address(0);
        // subtract subSTND if STND was used to subscribe
        if (sub.with == self.stnd) {
            self.subSTND[uid_] -= uint64((fees.subFee * (sub.until - bh - sub.bonus)) / 1e18);
        }
    }

    /// @dev offerBonus: Offer trial blocks to the subscription by promoters
    function _offerTrial(Member storage self, uint32 uid_, address holder_, uint256 blocks_) internal {
        // check if the member has the ABT with input id
        if (IPass(self.pass).balanceOf(holder_, uid_) == 0) {
            revert MembershipNotOwned(uid_, holder_);
        }
        // Add the bonus blocks to the subscription
        self.subscriptions[uid_].until += blocks_;
        // Mark added bonus blocks in the subscription
        self.subscriptions[uid_].bonus += blocks_;
    }

    function getFees(Member storage self, uint8 metaId_, address feeToken) internal view returns (MembershipLib.Fees memory fee) {
        return self.fees[metaId_][feeToken];
    }

    function _balanceOf(Member storage self, address owner_, uint32 uid_) internal view returns (uint256) {
        return IPass(self.pass).balanceOf(owner_, uid_);
    }

    function _isSubscribed(Member storage self, uint32 uid_) internal view returns (bool) {
        return self.subscriptions[uid_].until > block.number;
    }

    function _getSubSTND(Member storage self, uint32 uid_) internal view returns (uint64) {
        return self.subSTND[uid_];
    }

    function _getLvl(Member storage self, uint32 uid_) internal view returns (uint8) {
        return IPass(self.pass).metaId(uid_);
    }

    function _revenueOf(Member storage self, address token) internal view returns (uint256) {
        return IERC20Minimal(token).balanceOf(address(this));
    }

    function _sendFunds(
        Member storage self,
        address token,
        address to,
        uint256 amount
    ) internal returns (bool) {
        if (token == self.weth) {
            IWETHMinimal(token).withdraw(amount);
            return payable(to).send(amount);
        } else {
            TransferHelper.safeTransfer(token, to, amount);
            return true;
        }
    }

    function _getFeeRate(Member storage self, uint32 uid, bool isMaker)
        internal
        view
        returns (uint32 feeNum)
    {
        uint8 level = _getLvl(self, uid);
        // get subscribed STND tokens
        uint64 subSTND = _getSubSTND(self, uid);
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
