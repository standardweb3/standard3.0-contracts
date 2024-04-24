// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {MembershipLib} from "./libraries/MembershipLib.sol";
import {PointAccountantLib} from "./libraries/PointAccountantLib.sol";
import {IWETH} from "./interfaces/IWETH.sol";

/// @author Hyungsuk Kang <hskang9@gmail.com>
/// @title Standard Membership registration and subscription
contract PointFarm is AccessControl {
    using MembershipLib for MembershipLib.Member;
    using PointAccountantLib for PointAccountantLib.State;

    bytes32 public constant PROMOTER_ROLE = keccak256("PROMOTER_ROLE");

    MembershipLib.Member private _membership;
    PointAccountantLib.State private _accountant;

    error InvalidMeta(uint8 metaId_, address sender);
    error InvalidRole(bytes32 role, address sender);
    error InvalidAccess(address sender, address engine);

    event MemberRegistered(uint32 uid, uint8 metaId, address account);
    event MemberSubscribed(uint256 at, uint256 until, address with);
    event MetaSet(uint32 uid, uint8 metaId);
    event QuotaSet(uint8 metaId, uint32 quota);
    event PointReported(address account, uint256 amount);
    event PenaltyReported(address account, uint256 amount);
    event PenaltyRemoved(address account, uint256 amount);
    event MultiplierSet(
        address base,
        address quote,
        address pair,
        bool isBid,
        uint32 x
    );
    event EventCreated(uint32 eventId, uint256 startDate, uint256 endDate);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function initialize(
        address pass_,
        address foundation_,
        address weth_,
        address matchingEngine_,
        address point_,
        address stablecoin_
    ) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        _membership.pass = pass_;
        _membership.foundation = foundation_;
        _membership.weth = weth_;
        _accountant.matchingEngine = matchingEngine_;
        _accountant.point = point_;
        _accountant.stablecoin = stablecoin_;
    }

    /// @dev setFees: Set fees for registration and subscription and token address
    /// @param feeToken_ The address of the token to pay the fee
    /// @param regFee_ The registration fee per block in one token
    /// @param subFee_ The subscription fee per block in one token
    /// @param metaId_ The meta id of the token to pay the fee
    /// @param quotas_ The number of tokens to be issued for registration
    function setMembership(
        uint8 metaId_,
        address feeToken_,
        uint256 regFee_,
        uint256 subFee_,
        uint32 quotas_
    ) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        if (metaId_ == 0) {
            revert InvalidMeta(metaId_, msg.sender);
        }
        _membership._setMembership(
            metaId_,
            feeToken_,
            regFee_,
            subFee_,
            quotas_
        );
    }

    function setEvent(uint256 endDate) external {
        _accountant._setEvent(endDate);
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
        emit QuotaSet(metaId_, quota_);
    }

    function setMeta(uint32 uid_, uint8 metaId_) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        _membership._setMeta(uid_, metaId_);
        emit MetaSet(uid_, metaId_);
    }

    function getMetaSupply(uint8 metaId_) external view returns (uint256 supply) {
        return _membership._getMetaSupply(metaId_);
    }

    function setSTND(address stnd) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        _membership._setSTND(stnd);
    }

    function setFees(
        uint8 metaId_,
        address feeToken_,
        uint256 regFee_,
        uint256 subFee_
    ) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        _membership._setFees(metaId_, feeToken_, regFee_, subFee_);
    }

    /// @dev register: Register as a member
    function register(
        uint8 metaId_,
        address feeToken_
    ) external returns (uint32 uid) {
        // check if metaId is valid, meta only supports 1~11
        if (metaId_ == 0 || _membership.metas[metaId_].metaId != metaId_) {
            revert InvalidMeta(metaId_, msg.sender);
        }
        // check if early adoptor, foundation, beta account is only used by admin
        if (
            (metaId_ == 9 || metaId_ == 10 || metaId_ == 11) &&
            !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)
        ) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        uid = _membership._register(metaId_, feeToken_, false);
        emit MemberRegistered(uid, metaId_, msg.sender);
        return uid;
    }

    function registerETH(uint8 metaId_) external payable returns (uint32 uid) {
        require(msg.value > 0, "Membership: zero value ETH");
        IWETH(_membership.weth).deposit{value: msg.value}();
        uid = _membership._register(metaId_, _membership.weth, false);
        emit MemberRegistered(uid, metaId_, msg.sender);
        return uid;
    }

    /**
     * @dev subscribe: Subscribe to the membership until certain block height
     * @param uid_ The uid of the ABT to subscribe with
     * @param blocks_ The number of blocks to remain subscribed
     * @param feeToken_ The address of the token to pay the fee
     */
    function subscribe(
        uint32 uid_,
        address feeToken_,
        uint64 blocks_
    ) external returns (uint256 at, uint256 until, address with) {
        (at, until, with) = _membership._subscribe(uid_, feeToken_, blocks_);
        emit MemberSubscribed(at, until, with);
        return (at, until, with);
    }

    function subscribeETH(uint32 uid_, uint64 blocks_) external payable returns (uint256 at, uint256 until, address with) {
        require(msg.value > 0, "Membership: zero value");
        IWETH(_membership.weth).deposit{value: msg.value}();
        (at, until, with) = _membership._subscribe(uid_, _membership.weth, blocks_);
        emit MemberSubscribed(at, until, with);
        return (at, until, with);
    }

    function offerTrial(
        uint32 uid_,
        address holder_,
        uint256 blocks_
    ) external {
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

    function balanceOf(
        address who,
        uint32 uid_
    ) external view returns (uint256) {
        return _membership._balanceOf(who, uid_);
    }

    function getSubSTND(uint32 uid_) external view returns (uint64) {
        return _membership._getSubSTND(uid_);
    }

    function getSubStatus(uint32 uid_) external view returns (MembershipLib.SubStatus memory status) {
        return _membership._getSubStatus(uid_);
    }

    function getMeta(
        uint8 metaId_
    ) external view returns (MembershipLib.Meta memory) {
        return _membership.metas[metaId_];
    }

    function getLvl(uint32 uid_) external view returns (uint8 lvl) {
        return _membership._getLvl(uid_);
    }

    function isSubscribed(uint32 uid_) external view returns (bool) {
        return _membership._isSubscribed(uid_);
    }

    function isReportable() external view returns (bool) {
        return _accountant._checkEventOn();
    }

    function feeOf(
        uint32 uid,
        bool isMaker
    ) external view returns (uint32 feeNum) {
        if(_membership._isSubscribed(uid)) {
            return _membership._getFeeRate(uid, isMaker);
        } else {
            return 10000;
        }
    }

    /**
     * report bonus from promotion contract. point amount is calculated by the contract.
     * @param account account to mint point to
     * @param amount amount of point to mint
     */
    function reportBonus(
        address account,
        uint256 amount
    ) external returns (bool) {
        // check if the sender is a promoter
        if (!hasRole(PROMOTER_ROLE, msg.sender)) {
            revert InvalidRole(PROMOTER_ROLE, msg.sender);
        }
        _accountant._reportBonus(account, amount);
        emit PointReported(account, amount);
        return true;
    }

    /**
     * report penalty from promotion contract. point amount is calculated by the contract.
     * @param account account to fine point to
     * @param amount amount of point to fine
     */
    function reportPenalty(
        address account,
        uint256 amount
    ) external returns (bool) {
        // check if the sender is a promoter
        if (!hasRole(PROMOTER_ROLE, msg.sender)) {
            revert InvalidRole(PROMOTER_ROLE, msg.sender);
        }
        _accountant._reportPenalty(account, amount);
        emit PenaltyReported(account, amount);
        return true;
    }

    /**
     * Officially report trading point on matching engine.
     * @param uid user id from membership. currently redundant for now. input 0 then report is not applied.
     * @param base base token address
     * @param quote quote token address
     * @param isBid order type: if true, buy. if false, sell.
     * @param account account to mint point to
     * @param amount amount to mint
     */
    function report(
        uint32 uid,
        address base,
        address quote,
        bool isBid,
        address account,
        uint256 amount
    ) external returns (bool) {
        if (msg.sender != _accountant.matchingEngine) {
            revert InvalidAccess(msg.sender, _accountant.matchingEngine);
        }
        uint256 point = _accountant._report(
            uid,
            base,
            quote,
            isBid,
            account,
            amount
        );
        if (point > 0) {
            emit PointReported(account, point);
        }
        return true;
    }

    /**
     * Officially report trading penalty on matching engine.
     * @param uid user id from membership. currently redundant for now. input 0 then report is not applied.
     * @param base base token address
     * @param quote quote token address
     * @param isBid order type: if true, buy. if false, sell.
     * @param account account to mint point to
     * @param amount amount to mint
     */
    function reportCancel(
        uint32 uid,
        address base,
        address quote,
        bool isBid,
        address account,
        uint256 amount
    ) external returns (bool) {
        if (msg.sender != _accountant.matchingEngine) {
            revert InvalidAccess(msg.sender, _accountant.matchingEngine);
        }
        uint256 penalty = _accountant._reportCancel(
            uid,
            base,
            quote,
            isBid,
            account,
            amount
        );
        if (penalty > 0) {
            emit PenaltyReported(account, penalty);
        }
        return true;
    }

    /**
     * Set multiplier for getting points on a certain pair
     * @param base address of base token address
     * @param quote address of quote token address
     * @param isBid order type. if true, buy. if false, sell.
     * @param x amount of x to multiply (e.g. 100x)
     */
    function setMultiplier(
        address base,
        address quote,
        bool isBid,
        uint32 x
    ) external returns (bool) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        address pair = _accountant._setMultiplier(base, quote, isBid, x);
        emit MultiplierSet(base, quote, pair, isBid, x);
        return true;
    }

    /**
     * Create event on the 
     * @param startDate starting date for 
     * @param endDate end date for 
     */
    function createEvent(
        uint256 startDate,
        uint256 endDate
    ) external returns (uint32 eventId) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        eventId = _accountant._createEvent(startDate, endDate);
        emit EventCreated(eventId, startDate, endDate);
        return eventId;
    }

    function removePenalty(uint256 amount) external {
        _accountant._removePenalty(msg.sender, amount);
        emit PenaltyRemoved(msg.sender, amount);
    }

    function currentEvent() external view returns (uint32 eventId) {
        return _accountant.currentEvent;
    }
}
