pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./libraries/MembershipLib.sol";

/// @author Hyungsuk Kang <hskang9@gmail.com>
/// @title Standard Membership registration and subscription
contract Membership is AccessControl {
     using MembershipLib for MembershipLib.Member;

    MembershipLib.Member private _membership;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
   
    function initialize(
        address sabt_,
        address foundation_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _membership.sabt = sabt_;
        _membership.foundation = foundation_;
    }

    /// @dev setFees: Set fees for registration and subscription and token address
    /// @param feeToken_ The address of the token to pay the fee
    /// @param regFee_ The registration fee per block in one token
    /// @param subFee_ The subscription fee per block in one token
    /// @param metaId_ The meta id of the token to pay the fee
    /// @param quotas_ The number of tokens to be issued for registration
    /// @param prSubDur_ The duration of the subscription in registration for promotion
    function setMembership(
        uint16 metaId_,
        address feeToken_,
        uint32 regFee_,
        uint32 subFee_,
        uint32 quotas_,
        uint64 prSubDur_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _membership._setMembership(metaId_, feeToken_, regFee_, subFee_, quotas_, prSubDur_);
    }

    function setFoundation(address foundation_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _membership.foundation = foundation_;
    }

    function setQuota(uint16 metaId_, uint32 quota_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _membership._setQuota(metaId_, quota_);
    }

    /// @dev register: Register as a member
    function register(uint16 metaId_) external {
        // check if metaId is valid
        require(_membership.metas[metaId_].metaId == metaId_, "IM");
        _membership._register(metaId_);
        /*
        if (_membership.metas[metaId_].prSubDur > 0) {
            _membership._subscribe(msg.sender, metaId_, _membership.metas[metaId_].prSubDur);
        } 
        */
    }
    
    /// @dev subscribe: Subscribe to the membership until certain block height
    /// @param uid_ The uid of the ABT to subscribe with
    /// @param untilBh_ The block height to subscribe until
    function subscribe(uint32 uid_, uint64 untilBh_) external {
        _membership._subscribe(uid_, untilBh_);
    }

    /// @dev unsubscribe: Unsubscribe from the membership
    /// @param uid_ The id of the ABT to unsubscribe with
    function unsubscribe(uint32 uid_) external {
        _membership._unsubscribe(msg.sender, uid_);
    }

    function balanceOf(address who, uint32 uid_) external view returns (uint256) {
        return _membership._bidOrdersalanceOf(who, uid_);
    }

    function getMeta(uint16 metaId_) external view returns (MembershipLib.Meta memory) {
        return _membership.metas[metaId_];
    }

    function isSubscribed(uint32 uid_) external view returns (bool) {
        return _membership._isSubscribed(uid_);
    }

    function isReportable(address sender, uint32 uid_) external view returns (bool) {
        return _membership._bidOrdersalanceOf(sender, uid_) > 0 && _membership._isSubscribed(uid_);
    }
}
