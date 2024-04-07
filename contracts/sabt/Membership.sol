// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {MembershipLib} from "./libraries/MembershipLib.sol";
import {IWETH} from "./interfaces/IWETH.sol";

/// @author Hyungsuk Kang <hskang9@gmail.com>
/// @title Standard Membership registration and subscription
contract Membership is AccessControl {
    using MembershipLib for MembershipLib.Member;

    bytes32 public constant PROMOTER_ROLE = keccak256("PROMOTER_ROLE");

    MembershipLib.Member private _membership;

    error InvalidMeta(uint8 metaId_, address sender);
    error InvalidRole(bytes32 role, address sender);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function initialize(address sabt_, address foundation_, address weth_) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        _membership.sabt = sabt_;
        _membership.foundation = foundation_;
        _membership.weth = weth_;
    }

    /// @dev setFees: Set fees for registration and subscription and token address
    /// @param feeToken_ The address of the token to pay the fee
    /// @param regFee_ The registration fee per block in one token
    /// @param subFee_ The subscription fee per block in one token
    /// @param metaId_ The meta id of the token to pay the fee
    /// @param quotas_ The number of tokens to be issued for registration
    function setMembership(uint8 metaId_, address feeToken_, uint32 regFee_, uint32 subFee_, uint32 quotas_) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        if (metaId_ == 0) {
            revert InvalidMeta(metaId_, msg.sender);
        }
        _membership._setMembership(metaId_, feeToken_, regFee_, subFee_, quotas_);
    }

    function collectFee(address token) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        uint256 amount = _membership._revenueOf(token);
        _membership._sendFunds(token, _membership.foundation, amount);
    }

    function setFoundation(address foundation_) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        _membership.foundation = foundation_;
    }

    function setQuota(uint8 metaId_, uint32 quota_) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        _membership._setQuota(metaId_, quota_);
    }

    function setMeta(uint32 uid_, uint8 metaId_) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        _membership._setMeta(uid_, metaId_);
    }

    function setSTND(address stnd) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        _membership._setSTND(stnd);
    }

    function setFees(uint8 metaId_, address feeToken_, uint256 regFee_, uint256 subFee_) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        _membership._setFees(metaId_, feeToken_, regFee_, subFee_);
    }

    /// @dev register: Register as a member
    function register(uint8 metaId_, address feeToken_) external returns (uint32 uid) {
        // if the sender is default admin, make admin membership
        if (hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            return _membership._register(metaId_, feeToken_, true);
        } 
        // check if metaId is valid, meta only supports 1~11
        if (metaId_ == 0 || _membership.metas[metaId_].metaId != metaId_) {
            revert InvalidMeta(metaId_, msg.sender);
        }
        // check if early adoptor, foundation, beta account is only used by admin
        if ((metaId_ == 9 || metaId_ == 10 || metaId_ == 11) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        return _membership._register(metaId_, feeToken_, false);
    }

    function registerETH(uint8 metaId_) external payable returns (uint32 uid) {
        require(msg.value > 0, "Membership: zero value ETH");
        // if the sender is default admin, make admin membership
        if (hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            _membership._register(metaId_, _membership.weth, true);
        }
        IWETH(_membership.weth).deposit{value: msg.value}();
        return _membership._register(metaId_, _membership.weth, false);
    }

    /**
     * @dev subscribe: Subscribe to the membership until certain block height
     * @param uid_ The uid of the ABT to subscribe with
     * @param blocks_ The number of blocks to remain subscribed
     * @param feeToken_ The address of the token to pay the fee
     */
    function subscribe(uint32 uid_, uint64 blocks_, address feeToken_) external {
        _membership._subscribe(uid_, blocks_, feeToken_);
    }

    function subscribeETH(uint32 uid_, uint64 blocks_) external payable {
        require(msg.value > 0, "Membership: zero value");
        IWETH(_membership.weth).deposit{value: msg.value}();
        _membership._subscribe(uid_, blocks_, _membership.weth);
    }

    function offerTrial(uint32 uid_, address holder_, uint256 blocks_) external {
        if (!hasRole(PROMOTER_ROLE, msg.sender)) {
            revert InvalidRole(PROMOTER_ROLE, msg.sender);
        }
        _membership._offerTrial(uid_, holder_, blocks_);
    }

    /// @dev unsubscribe: Unsubscribe from the membership
    /// @param uid_ The id of the ABT to unsubscribe with
    function unsubscribe(uint32 uid_) external {
        _membership._unsubscribe(uid_);
    }

    function balanceOf(address who, uint32 uid_) external view returns (uint256) {
        return _membership._balanceOf(who, uid_);
    }

    function getSubSTND(uint32 uid_) external view returns (uint64) {
        return _membership._getSubSTND(uid_);
    }

    function getMeta(uint8 metaId_) external view returns (MembershipLib.Meta memory) {
        return _membership.metas[metaId_];
    }

    function getLvl(uint32 uid_) external view returns (uint8 lvl) {
        return _membership._getLvl(uid_);
    }

    function isSubscribed(uint32 uid_) external view returns (bool) {
        return _membership._isSubscribed(uid_);
    }

    function isReportable(address sender, uint32 uid_) external view returns (bool) {
        return _membership._balanceOf(sender, uid_) > 0 && _membership._isSubscribed(uid_);
    }

    function feeOf(uint32 uid, bool isMaker) external view returns (uint32 feeNum) {
        return _membership._getFeeRate(uid, isMaker);
    }   

    
    // redundant functions until membership is updated. do not touch the code yet.
    function report(uint32 uid, address token, uint256 amount, bool isAdd) external pure returns (bool) {
        return true;
    }

    function refundFee(address to, address token, uint256 amount) external pure returns (bool) {
        return true;
    }

}
