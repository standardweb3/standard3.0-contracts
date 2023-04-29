pragma solidity ^0.8.10;

import "./libraries/TimeAccountantLib.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @author Hyungsuk Kang <hskang9@gmail.com>
/// @title Standard Membership Accountant to report membership points
contract TimeAccountant is AccessControl {
    using TimeAccountantLib for TimeAccountantLib.Storage;

    TimeAccountantLib.Storage private _accountant;

    constructor(
        address membership,
        address engine,
        address stablecoin
    ) {
        _accountant.membership = membership;
        _accountant.engine = engine;
        _accountant.stablecoin = stablecoin;
        _accountant.ft = block.timestamp;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setEngine(address engine) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "IA");
        _accountant.engine = engine;
    }
    
    function setMembership(address membership) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "IA");
        _accountant.membership = membership;
    }

    function setReferenceCurrency(address stablecoin) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "IA");
        _accountant.stablecoin = stablecoin;
    }

    /**  @dev report: Report the membership point of the member
     * @param uid The member uid
     * @param token The token address
     * @param amount The amount of the membership point
     * @param isAdd The flag to add or subtract the point
     */
    function report(uint32 uid, address token, uint256 amount, bool isAdd) public {
        _accountant._report(uid, token, amount, isAdd);
    }

    function getTotalPoints(uint32 nthEra) public view returns (uint256) {
        return _accountant._totalPoints(nthEra);
    }

    function getTotalTokens(
        uint32 nthEra,
        address token
    ) public view returns (uint256) {
        return _accountant._totalRewards(nthEra, token);
    }

    function getMP(
        uint32 uid,
        uint32 nthEra
    ) external view returns (uint256) {
        return _accountant._getMP(uid, nthEra);
    }
}
