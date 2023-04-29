pragma solidity ^0.8.10;

import "./libraries/BlockAccountantLib.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @author Hyungsuk Kang <hskang9@gmail.com>
/// @title Standard Membership Accountant to report membership points
contract BlockAccountant is AccessControl {
    using BlockAccountantLib for BlockAccountantLib.Storage;
    bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE");

    BlockAccountantLib.Storage private _accountant;

    constructor(
        address membership,
        address engine,
        address stablecoin,
        uint32 bfs_
    ) {
        _accountant.membership = membership;
        _accountant.engine = engine;
        _accountant.stablecoin = stablecoin;
        _accountant.fb = block.number;
        _accountant.bfs = bfs_;
        _accountant.era = uint32(28 days / bfs_);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }



    function setEngine(address engine) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "IA");
        _accountant.engine = engine;
    }

    function setMembership(address membership) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "IA");
        _accountant.membership = membership;
    }

    function setTreasury(address treasury) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "IA");
        _accountant.treasury = treasury;
    }

    function setReferenceCurrency(address stablecoin) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "IA");
        _accountant.stablecoin = stablecoin;
    }

    function setBFS(uint32 bfs_) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "IA");
        _accountant.bfs = bfs_;
        _accountant.era = uint32(28 days / bfs_);
    }

    // TODO: migrate point from one era to other uid for multiple membership holders
    /// @dev migrate: Migrate the membership point from one era to other uid
    /// @param fromUid_ The uid to migrate from
    /// @param toUid_ The uid to migrate to
    /// @param nthEra_ The era to migrate
    /// @param amount_ The amount of the point to migrate
    function migrate(
        uint32 fromUid_,
        uint32 toUid_,
        uint32 nthEra_,
        uint256 amount_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _accountant._migrate(msg.sender, fromUid_, toUid_, nthEra_, amount_);
    }

    /**  @dev report: Report the membership point of the member
     * @param uid The member uid
     * @param token The token address
     * @param amount The amount of the membership point
     * @param isAdd The flag to add or subtract the point
     */
    function report(
        uint32 uid,
        address token,
        uint256 amount,
        bool isAdd
    ) external {
        require(hasRole(REPORTER_ROLE, msg.sender), "IA");
        if (_accountant._isSubscribed(uid)) {
            _accountant._report(uid, token, amount, isAdd);
        }
    }

    function subtractMP(uint32 uid, uint32 nthEra, uint64 point) external {
        require(msg.sender == _accountant.treasury, "IA");
        _accountant._subtractMP(uid, nthEra, point);
    }

    function getTotalPoints(uint32 nthEra) external view returns (uint256) {
        return _accountant._totalPoints(nthEra);
    }

    function fb() external view returns (uint256) {
        return _accountant.fb;
    }

    function getTotalTokens(
        uint32 nthEra,
        address token
    ) external view returns (uint256) {
        return _accountant._totalTokens(token, nthEra);
    }

    function pointOf(
        uint32 uid,
        uint32 nthEra
    ) external view returns (uint256) {
        return _accountant._getMP(uid, nthEra);
    }

    function getBfs() external view returns (uint256) {
        return _accountant.bfs;
    }
}
