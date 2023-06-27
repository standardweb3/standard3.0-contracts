// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import {TransferHelper} from "./TransferHelper.sol";

interface ISABT {
    function mint(address to_, uint16 metaId_) external returns (uint32);

    function balanceOf(
        address owner_,
        uint256 uid_
    ) external view returns (uint256);

    function setRegistered(uint256 id_, bool yesOrNo) external;

    function metaId(uint32 uid_) external view returns (uint16);
}

library MembershipLib {
    struct Member {
        /// @dev mapping of member id to subscription status
        mapping(uint32 => SubStatus) subscriptions;
        /// @dev mapping of subscribed STND of member id
        mapping(uint32 => uint64) subSTND;
        /// @dev mapping of meta id to register fee status
        mapping(uint16 => Meta) metas;
        /// @dev mapping of meta id to register fee status
        mapping(uint16 => mapping(address => Fees)) fees;
        /// @dev address of SABT
        address sabt;
        /// @dev address of STND
        address stnd;
        /// @dev address of foundation
        address foundation;
    }

    struct SubStatus {
        uint256 at;
        uint256 until;
        uint256 bonus;
        address with;
    }

    struct Meta {
        uint16 metaId;
        uint32 quota;
    }

    struct Fees {
        address feeToken;
        uint256 regFee;
        uint256 subFee;
    }

    error InvalidFeeToken(address feeToken_, uint16 metaId_);
    error MembershipNotOwned(uint32 uid, address owner);
    error NoMultiTokenAccounting(address subscribedWith, address feeToken_);

    function _setMembership(
        Member storage self,
        uint16 metaId_,
        address feeToken_,
        uint32 regFee_,
        uint32 subFee_,
        uint32 quota_
    ) internal {
        self.metas[metaId_].metaId = metaId_;
        uint8 decimals = TransferHelper.decimals(feeToken_);
        self.fees[metaId_][feeToken_].regFee = regFee_ * 10 ** decimals;
        self.fees[metaId_][feeToken_].subFee = subFee_ * 10 ** decimals;
        self.metas[metaId_].quota = quota_;
    }

    function _setQuota(
        Member storage self,
        uint16 metaId_,
        uint32 quota_
    ) internal {
        self.metas[metaId_].quota = quota_;
    }

    function _setSTND(Member storage self, address stnd) internal {
        self.stnd = stnd;
    }

    function _setFees(
        Member storage self,
        uint16 metaId_,
        address feeToken_,
        uint256 regFee_,
        uint256 subFee_
    ) internal {
        uint8 decimals = TransferHelper.decimals(feeToken_);
        self.fees[metaId_][feeToken_].regFee = regFee_ * 10 ** decimals;
        self.fees[metaId_][feeToken_].subFee = subFee_ * 10 ** decimals;
    }

    function _register(
        Member storage self,
        uint16 metaId_,
        address feeToken_
    ) internal returns (uint32 uid) {
        uint256 regFee = self.fees[metaId_][feeToken_].regFee;
        // check if the fee token is supported
        if (regFee == 0) {
            revert InvalidFeeToken(feeToken_, metaId_);
        }
        // Transfer required fund
        TransferHelper.safeTransferFrom(
            feeToken_,
            msg.sender,
            address(this),
            regFee
        );
        TransferHelper.safeTransfer(feeToken_, self.foundation, regFee);
        // issue membership from SABT and get id
        return ISABT(self.sabt).mint(msg.sender, metaId_);
    }

    /// @dev subscribe: Subscribe to the membership until certain block height
    /// @param uid_ The uid of the ABT to subscribe with
    /// @param blocks_ The number of blocks to subscribe
    function _subscribe(
        Member storage self,
        uint32 uid_,
        uint64 blocks_,
        address feeToken_
    ) internal {
        // check if the member has the ABT with input id
        if (ISABT(self.sabt).balanceOf(msg.sender, uid_) == 0) {
            revert MembershipNotOwned(uid_, msg.sender);
        }
        uint256 bh = block.number;
        uint16 metaId = ISABT(self.sabt).metaId(uid_);
        SubStatus memory sub = self.subscriptions[uid_];
        Fees memory fees = self.fees[metaId][feeToken_];
        // check if previous subscription was done with the same token
        if (sub.with != address(0) && sub.with != feeToken_) {
            // if not, Ask user to unsubscribed with the previous token subscription
            revert NoMultiTokenAccounting(sub.with, feeToken_);
        }
        // if the member already subscribed, refund the fee for the remaining block
        if (sub.until > bh) {
            // Transfer what has been already paid
            TransferHelper.safeTransfer(
                feeToken_,
                self.foundation,
                fees.subFee * (bh - sub.at)
            );
            // Transfer the tokens for future subscription to this contract
            TransferHelper.safeTransferFrom(
                msg.sender,
                address(this),
                feeToken_,
                fees.subFee * (blocks_ - sub.until)
            );
        } else {
            // Transfer what has been already paid
            TransferHelper.safeTransfer(
                feeToken_,
                self.foundation,
                fees.subFee * (sub.until - sub.at)
            );
            // Transfer the tokens to this contract
            TransferHelper.safeTransferFrom(
                msg.sender,
                address(this),
                feeToken_,
                fees.subFee * (blocks_ - bh)
            );
        }
        // subscribe for certain block
        self.subscriptions[uid_].at = bh;
        self.subscriptions[uid_].until = bh + blocks_;
        self.subscriptions[uid_].with = feeToken_;
        // if feeToken is STND, add it to the subSTND;
        if (feeToken_ == self.stnd) {
            self.subSTND[uid_] += uint64(
                (fees.subFee * (blocks_ - bh)) / 1e18
            );
        }
    }

    /// @dev unsubscribe: Unsubscribe from the membership
    /// @param uid_ The id of the ABT to unsubscribe with
    function _unsubscribe(Member storage self, uint32 uid_) internal {
        // check if the member has the ABT with input id
        if (ISABT(self.sabt).balanceOf(msg.sender, uid_) == 0) {
            revert MembershipNotOwned(uid_, msg.sender);
        }
        uint256 bh = block.number;
        uint16 metaId = ISABT(self.sabt).metaId(uid_);
        SubStatus memory sub = self.subscriptions[uid_];
        Fees memory fees = self.fees[metaId][sub.with];
        if (sub.until > bh) {
            // Transfer what has been already paid to foundation
            TransferHelper.safeTransfer(
                sub.with,
                self.foundation,
                fees.subFee * (bh - sub.at)
            );
            if (sub.until - bh > sub.bonus) {
                // Refund the tokens for future subscription to this contract
                TransferHelper.safeTransfer(
                    sub.with,
                    msg.sender,
                    fees.subFee * (sub.until - bh - sub.bonus)
                );
            }
        }
        // unsubscribe
        self.subscriptions[uid_].until = 0;
        self.subscriptions[uid_].at = 0;
        self.subscriptions[uid_].bonus = 0;
        self.subscriptions[uid_].with = address(0);
        // subtract subSTND if STND was used to subscribe
        if(sub.with == self.stnd) {
            self.subSTND[uid_] -= uint64(fees.subFee * (sub.until - bh - sub.bonus) / 1e18);
        }
    }

    /// @dev offerBonus: Offer bonus blocks to the subscription by promoters
    function _offerBonus(
        Member storage self,
        uint32 uid_,
        address holder_,
        uint256 blocks_
    ) internal {
        // check if the member has the ABT with input id
        if (ISABT(self.sabt).balanceOf(holder_, uid_) == 0) {
            revert MembershipNotOwned(uid_, holder_);
        }
        // Add the bonus blocks to the subscription
        self.subscriptions[uid_].until += blocks_;
        // Mark added bonus blocks in the subscription
        self.subscriptions[uid_].bonus += blocks_;
    }

    function _balanceOf(
        Member storage self,
        address owner_,
        uint32 uid_
    ) internal view returns (uint256) {
        return ISABT(self.sabt).balanceOf(owner_, uid_);
    }

    function _isSubscribed(
        Member storage self,
        uint32 uid_
    ) internal view returns (bool) {
        return self.subscriptions[uid_].until > block.number;
    }

    function _getSubSTND(
        Member storage self,
        uint32 uid_
    ) internal view returns (uint64) {
        return self.subSTND[uid_];
    }
}
