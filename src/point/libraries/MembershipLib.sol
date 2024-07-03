// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {TransferHelper} from "./TransferHelper.sol";

interface IPass {
    function mint(address to_, uint8 metaId_) external returns (uint32);

    function balanceOf(
        address owner_,
        uint256 uid_
    ) external view returns (uint256);

    function metaId(uint256 uid_) external view returns (uint8);

    function setMeta(uint256 uid_, uint8 meta_) external;

    function getLvl(uint256 uid_) external view returns (uint8);

    function getMetaSupply(uint8 metaId_) external view returns (uint256);

    function exterminate(uint256 uid_) external returns (bool);
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
        mapping(uint256 => SubStatus) subscriptions;
        /// @dev mapping of subscribed STND of member id
        mapping(uint256 => uint64) subSTND;
        /// @dev mapping of meta id to register fee status
        mapping(uint8 => Meta) metas;
        /// @dev mapping of meta id to register fee status
        mapping(uint8 => mapping(address => Fees)) fees;
        /// @dev default UID to participate in point program
        mapping(address => uint256) defaultUIDs;
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
    error MembershipNotOwned(uint256 uid, address owner);
    error FeeNotConfigured(address feeToken, uint256 fee);
    error NoMultiTokenAccounting(address subscribedWith, address feeToken_);
    error NotUIDOwner(address user, uint256 uid);

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

    function _setQuota(
        Member storage self,
        uint8 metaId_,
        uint32 quota_
    ) internal {
        self.metas[metaId_].quota = quota_;
    }

    function _setMeta(
        Member storage self,
        uint256 uid_,
        uint8 metaId_
    ) internal {
        IPass(self.pass).setMeta(uid_, metaId_);
    }

    function _setSTND(Member storage self, address stnd) internal {
        self.stnd = stnd;
    }

    function _setFees(
        Member storage self,
        uint8 metaId_,
        address feeToken_,
        uint256 regFee_,
        uint256 subFee_
    ) internal {
        self.fees[metaId_][feeToken_].regFee = regFee_;
        self.fees[metaId_][feeToken_].subFee = subFee_;
    }

    function _register(
        Member storage self,
        uint8 metaId_,
        address feeToken_,
        bool isDev
    ) internal returns (uint256 uid) {
        if (!isDev) {
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
        }
        // issue membership from pass and get id
        uid = IPass(self.pass).mint(msg.sender, metaId_);
        // set default UID if minted first time
        if(self.defaultUIDs[msg.sender] == 0) {
            self.defaultUIDs[msg.sender] = uid;
        }
        return uid;
    }

    function _setDefaultUID(Member storage self, uint256 uid_) external returns (bool) {
        // check if user owns the uid
        if  (IPass(self.pass).balanceOf(msg.sender, uid_) != 1) {
            revert NotUIDOwner(msg.sender, uid_);
        }
        self.defaultUIDs[msg.sender] = uid_;
        return true;
    }

    function _exterminate(Member storage self, uint256 uid_, address owner_) external returns (uint32) {
        if(self.defaultUIDs[owner_] == uid_) {
            self.defaultUIDs[owner_] = 0;
        }
        IPass(self.pass).exterminate(uid_);
    }

    /// @dev subscribe: Subscribe to the membership until certain block height
    /// @param uid_ The uid of the ABT to subscribe with
    /// @param feeToken_ address of the token contract to pay as fee
    /// @param blocks_ The number of blocks to subscribe
    function _subscribe(
        Member storage self,
        uint256 uid_,
        address feeToken_,
        uint64 blocks_
    ) internal returns (uint256 at, uint256 until, address with) {
        // check if the member has the ABT with input id
        if (IPass(self.pass).balanceOf(msg.sender, uid_) == 0) {
            revert MembershipNotOwned(uid_, msg.sender);
        }
        uint256 bh = block.number;
        uint8 metaId = IPass(self.pass).metaId(uid_);
        SubStatus memory sub = self.subscriptions[uid_];
        Fees memory fees = self.fees[metaId][feeToken_];
        // check if fee is not set
        if (fees.subFee == 0) {
            revert FeeNotConfigured(feeToken_, fees.subFee);
        }
        // check if previous subscription was done with the same token
        if (sub.with != address(0) && sub.with != feeToken_) {
            // if not, Ask user to unsubscribed with the previous token subscription
            revert NoMultiTokenAccounting(sub.with, feeToken_);
        }
        // Transfer what has been already paid
        TransferHelper.safeTransfer(
            feeToken_,
            self.foundation,
            sub.until > bh
                ? fees.subFee * uint256(bh - sub.at)
                : fees.subFee * uint256(sub.until - sub.at)
        );

        // Transfer the tokens to this contract for new subscription
        TransferHelper.safeTransferFrom(
            feeToken_,
            msg.sender,
            address(this),
            fees.subFee * uint256(blocks_)
        );

        // subscribe for certain block
        self.subscriptions[uid_].at = bh;
        self.subscriptions[uid_].until = sub.until > bh
            ? bh + (sub.until - bh) + blocks_
            : bh + blocks_;
        self.subscriptions[uid_].with = feeToken_;
        // if feeToken is STND, add it to the subSTND;
        if (feeToken_ == self.stnd) {
            uint8 decimals = TransferHelper.decimals(self.stnd);
            self.subSTND[uid_] += uint64(
                (fees.subFee * blocks_) / 10 ** decimals
            );
        }
        return (
            self.subscriptions[uid_].at,
            self.subscriptions[uid_].until,
            self.subscriptions[uid_].with
        );
    }

    /// @dev unsubscribe: Unsubscribe from the membership
    /// @param uid_ The id of the ABT to unsubscribe with
    function _unsubscribe(Member storage self, uint256 uid_) internal {
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
        if (sub.with == self.stnd) {
            self.subSTND[uid_] -= uint64(
                (fees.subFee * (sub.until - bh - sub.bonus)) / 1e18
            );
        }
    }

    /// @dev offerBonus: Offer trial blocks to the subscription by promoters
    function _offerTrial(
        Member storage self,
        uint256 uid_,
        address holder_,
        uint256 blocks_
    ) internal {
        // check if the member has the ABT with input id
        if (IPass(self.pass).balanceOf(holder_, uid_) == 0) {
            revert MembershipNotOwned(uid_, holder_);
        }
        // Add the bonus blocks to the subscription
        self.subscriptions[uid_].until += blocks_;
        // Mark added bonus blocks in the subscription
        self.subscriptions[uid_].bonus += blocks_;
    }

    function getFees(
        Member storage self,
        uint8 metaId_,
        address feeToken
    ) internal view returns (MembershipLib.Fees memory fee) {
        return self.fees[metaId_][feeToken];
    }

    function _balanceOf(
        Member storage self,
        address owner_,
        uint256 uid_
    ) internal view returns (uint256) {
        return IPass(self.pass).balanceOf(owner_, uid_);
    }

    function _isSubscribed(
        Member storage self,
        address account
    ) internal view returns (bool) {
        uint256 uid = self.defaultUIDs[account];
        if(uid == 0) {
            return false;
        }
        return self.subscriptions[uid].until > block.number;
    }

    function _getSubSTND(
        Member storage self,
        uint256 uid_
    ) internal view returns (uint64) {
        return self.subSTND[uid_];
    }

    function _getSubStatus(
        Member storage self,
        uint256 uid_
    ) internal view returns (SubStatus memory status) {
        return self.subscriptions[uid_];
    }

    function _getMetaSupply(
        Member storage self,
        uint8 metaId_
    ) internal view returns (uint256 supply) {
        return IPass(self.pass).getMetaSupply(metaId_);
    }

    function _getLvl(
        Member storage self,
        uint256 uid_
    ) internal view returns (uint8) {
        return IPass(self.pass).metaId(uid_);
    }

    function _revenueOf(
        Member storage self,
        address token
    ) internal view returns (uint256) {
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

    function _getPointX(
        Member storage self,
        uint256 uid
    ) internal view returns (uint32 feeNum) {
        if(uid == 0) {
            return 10000;
        }
        uint8 level = _getLvl(self, uid);
        // get subscribed STND tokens
        uint64 subSTND = _getSubSTND(self, uid);
        // Perform different aclevelons based on the level
        if (level == 0) {
            if (subSTND >= 10000) {
                // 1x
                return 10000;
            } else {
                // 1x
                return 10000;
            }
        } else if (level == 1) {
            if (subSTND >= 25000) {
                // 1.2x / 1x
                return 12000;
            } else {
                // 1.1x / 1x
                return 11000;
            }
        } else if (level == 2) {
            if (subSTND >= 100000) {
                // 1.5x / 1x
                return 15000;
            } else {
                // 1.25x / 1x
                return 12500;
            }
        } else if (level == 3) {
            if (subSTND >= 250000) {
                // 1.75x / 1x
                return 17500;
            } else {
                // 1.5x / 1x
                return 15000;
            }
        } else if (level == 4) {
            if (subSTND >= 500000) {
                // 2.25x / 1x
                return 22500;
            } else {
                // 2x / 1x
                return 20000;
            }
        } else if (level == 5) {
            if (subSTND >= 750000) {
                // 2.75x / 1x
                return 27500;
            } else {
                // 2.5x / 1x
                return 25000;
            }
        } else if (level == 6) {
            if (subSTND >= 1000000) {
                // 3.25x / 1x
                return 32500;
            } else {
                // 3x / 1x
                return 30000;
            }
        } else if (level == 7) {
            if (subSTND >= 1250000) {
                // 3.75x / 1x
                return 37500;
            } else {
                // 3.5x / 1x
                return 35000;
            }
        } else if (level >= 8) {
            if (subSTND >= 1500000) {
                // 4.25x / 1x
                return 42500;
            } else {
                // 4x / 1x
                return 40000;
            }
        } 
    }

    function _getFeeRate(
        Member storage self,
        address account,
        bool isMaker
    ) internal view returns (uint32 feeNum) {
        uint256 uid = self.defaultUIDs[account];
        uint8 level = _getLvl(self, uid);
        // get subscribed STND tokens
        uint64 subSTND = _getSubSTND(self, uid);
        // Perform different aclevelons based on the level
        if (level == 0) {
            if (subSTND >= 10000) {
                // 0.275% / 0.275%
                return 2750;
            } else {
                // 0.3% / 0.3%
                return 3000;
            }
        } else if (level == 1) {
            if (subSTND >= 25000) {
                // 0.225 / 0.25%
                return isMaker ? 2250 : 2500;
            } else {
                // 0.275 / 0.3%
                return isMaker ? 2750 : 3000;
            }
        } else if (level == 2) {
            if (subSTND >= 100000) {
                // 0.2% / 0.225%
                return isMaker ? 2000 : 2250;
            } else {
                // 0.250% / 0.3%
                return isMaker ? 2500 : 3000;
            }
        } else if (level == 3) {
            if (subSTND >= 250000) {
                // 0.175% / 0.2%
                return isMaker ? 1750 : 2000;
            } else {
                // 0.225% / 0.3%
                return isMaker ? 2250 : 3000;
            }
        } else if (level == 4) {
            if (subSTND >= 500000) {
                // 0.15% / 0.175%
                return isMaker ? 1500 : 1750;
            } else {
                // 0.2% / 0.25%
                return isMaker ? 2000 : 2500;
            }
        } else if (level == 5) {
            if (subSTND >= 750000) {
                // 0.125% / 0.15%
                return isMaker ? 1250 : 1500;
            } else {
                // 0.175% / 0.225%
                return isMaker ? 1750 : 2250;
            }
        } else if (level == 6) {
            if (subSTND >= 1000000) {
                // 0.1% / 0.125%
                return isMaker ? 1000 : 1250;
            } else {
                // 0.15% / 0.2%
                return isMaker ? 1500 : 2000;
            }
        } else if (level == 7) {
            if (subSTND >= 1250000) {
                // 0.075% / 0.1%
                return isMaker ? 750 : 1000;
            } else {
                // 0.125% / 0.175%
                return isMaker ? 1250 : 1750;
            }
        } else if (level >= 8) {
            if (subSTND >= 1500000) {
                // 0.050% / 0.075%
                return isMaker ? 500 : 750;
            } else {
                // 0.1% / 0.15%
                return isMaker ? 1000 : 1500;
            }
        } else if (level >= 11) {
            // when beta account is used, fee rate is zero
            return 0;
        }
    }
}
