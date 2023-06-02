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

    error InvalidRole(bytes32 role, address sender);

    function setEngine(address engine) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        _accountant.engine = engine;
    }

    function setMembership(address membership) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        _accountant.membership = membership;
    }

    function setTreasury(address treasury) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        _accountant.treasury = treasury;
    }

    function setReferenceCurrency(address stablecoin) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        _accountant.stablecoin = stablecoin;
    }

    function setBFS(uint32 bfs_) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
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

    /**  @dev report: Report the membership point of the member to update
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
        if (!hasRole(REPORTER_ROLE, _msgSender())) {
            revert InvalidRole(REPORTER_ROLE, _msgSender());
        }
        if (_accountant._isSubscribed(uid)) {
            _accountant._report(uid, token, amount, isAdd);
        }
    }

    error NotTreasury(address sender, address treasury);

    function subtractMP(uint32 uid, uint32 nthEra, uint64 point) external {
        if(msg.sender != _accountant.treasury) {
            revert NotTreasury(msg.sender, _accountant.treasury);
        }
        _accountant._subtractMP(uid, nthEra, point);
    }

    function getTotalPoints(uint32 nthEra) external view returns (uint256) {
        return _accountant._totalPoints(nthEra);
    }

    function fb() external view returns (uint256) {
        return _accountant.fb;
    }

    function getCurrentEra() external view returns (uint32) {
        return _accountant._getEra();
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
