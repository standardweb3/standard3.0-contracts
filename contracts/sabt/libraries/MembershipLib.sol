pragma solidity ^0.8.10;

import "./TransferHelper.sol";

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
        mapping(uint32 => SubStatus) subscribedUntil;
        /// @dev mapping of member id to subscription status
        mapping(uint32 => SubStatus) subscribedAt;
        /// @dev subscription info
        mapping(uint8 => Subscription) subscriptions;
        /// @dev mapping of meta id to register fee status
        mapping(uint16 => Meta) metas;
        /// @dev address of SABT
        address sabt;
        /// @dev address of foundation
        address foundation;
    }

    struct SubStatus {
        uint64 bh;
        uint8 subId;
    }

    struct Subscription {
        address details;
    }

    struct Meta {
        uint16 metaId;
        address feeToken;
        uint256 regFee;
        uint256 subFee;
        uint32 quota;
        uint64 prSubDur;
    }

    function _setMembership(
        Member storage self,
        uint16 metaId_,
        address feeToken_,
        uint32 regFee_,
        uint32 subFee_,
        uint32 quota_,
        uint64 prSubDur_
    ) internal {
        self.metas[metaId_].metaId = metaId_;
        self.metas[metaId_].feeToken = feeToken_;
        uint8 decimals = TransferHelper.decimals(feeToken_);
        self.metas[metaId_].regFee = regFee_ * 10 ** decimals;
        self.metas[metaId_].subFee = subFee_ * 10 ** decimals;
        self.metas[metaId_].quota = quota_;
        self.metas[metaId_].prSubDur = prSubDur_;
    }

    function _setQuota(
        Member storage self,
        uint16 metaId_,
        uint32 quota_
    ) internal {
        self.metas[metaId_].quota = quota_;
    }

    function _register(Member storage self, uint16 metaId_) internal {
        // Transfer required fund
        TransferHelper.safeTransferFrom(
            msg.sender,
            address(this),
            self.metas[metaId_].feeToken,
            self.metas[metaId_].regFee
        );
        // issue membership from SABT and get id
        ISABT(self.sabt).mint(msg.sender, metaId_);
    }

    /// @dev subscribe: Subscribe to the membership until certain block height
    /// @param uid_ The uid of the ABT to subscribe with
    /// @param untilBh_ The block height to subscribe until
    function _subscribe(
        Member storage self,
        uint32 uid_,
        uint64 untilBh_
    ) internal {
        // check if the member has the ABT with input id
        require(ISABT(self.sabt).balanceOf(msg.sender, uid_) > 0, "not owned");
        uint16 metaId = ISABT(self.sabt).metaId(uid_);
        // if the member already subscribed, refund the fee for the remaining block
        if (self.subscribedUntil[uid_].bh > block.number) {
            // Transfer what has been already paid
            TransferHelper.safeTransfer(
                self.metas[metaId].feeToken,
                self.foundation,
                self.metas[metaId].subFee * (block.number - self.subscribedAt[uid_].bh)
            );
            // Transfer the tokens for future subscription to this contract
            TransferHelper.safeTransferFrom(
                msg.sender,
                address(this),
                self.metas[metaId].feeToken,
                self.metas[metaId].subFee * (untilBh_ - self.subscribedUntil[uid_].bh)
            );
        } else {
            // Transfer what has been already paid
            TransferHelper.safeTransfer(
                self.metas[metaId].feeToken,
                self.foundation,
                self.metas[metaId].subFee *
                    (self.subscribedUntil[uid_].bh -
                        self.subscribedAt[uid_].bh)
            );
            // Transfer the tokens to this contract
            TransferHelper.safeTransferFrom(
                msg.sender,
                address(this),
                self.metas[metaId].feeToken,
                self.metas[metaId].subFee * (untilBh_ - block.number)
            );
        }
        // subscribe for certain block
        self.subscribedAt[uid_].bh = uint64(block.number);
        self.subscribedUntil[uid_].bh = uint64(block.number) + untilBh_;
    }

    /// @dev unsubscribe: Unsubscribe from the membership
    /// @param uid_ The id of the ABT to unsubscribe with
    function _unsubscribe(Member storage self, address sender, uint32 uid_) internal {
        // check if the member has the ABT with input id
        require(ISABT(self.sabt).balanceOf(sender, uid_) == 1, "not owned");
        uint16 metaId = ISABT(self.sabt).metaId(uid_);
        // refund the tokens to the member
        if (self.subscribedUntil[uid_].bh > block.number) {
            // Transfer what has been already paid
            TransferHelper.safeTransfer(
                self.metas[metaId].feeToken,
                sender,
                self.metas[metaId].subFee * (block.number - self.subscribedAt[uid_].bh)
            );
            TransferHelper.safeTransfer(
                self.metas[metaId].feeToken,
                sender,
                self.metas[metaId].subFee * (self.subscribedUntil[uid_].bh - block.number)
            );
        }
        // unsubscribe
        self.subscribedUntil[uid_].bh = 0;
        self.subscribedAt[uid_].bh = 0;
    }

    function _balanceOf(
        Member storage self,
        address owner_,
        uint32 uid_
    ) internal view returns (uint256) {
        return ISABT(self.sabt).balanceOf(owner_, uid_);
    }

    function _isSubscribed(Member storage self, uint32 uid_) internal view returns (bool) {
        return self.subscribedUntil[uid_].bh > block.number;
    }
}
