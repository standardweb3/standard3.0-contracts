pragma solidity ^0.8.10;

import "./libraries/TreasuryLib.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @author Hyungsuk Kang <hskang9@github.com>
/// @title Standard Membership Treasury to exchange membership points with rewards
contract Treasury is AccessControl {
    using TreasuryLib for TreasuryLib.Storage;
    bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE");

    TreasuryLib.Storage private _treasury;

    constructor(address accountant_, address sabt_) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _treasury.accountant = accountant_;
        _treasury.sabt = sabt_;
    }
    
    /// @dev For subscribers, exchange point to reward
    function exchange(
        address token,
        uint32 nthEra,
        uint32 uid,
        uint64 point
    ) external {
       _treasury._exchange(token, nthEra, uid, point);
    }

    /// @dev for investors, claim the reward with allocated revenue percentage
    function claim(address token, uint32 nthEra, uint32 uid) external {
        _treasury._claim(token, nthEra, uid);
    }

    /// @dev for dev, settle the revenue with allocated revenue percentage
    function settle(address token, uint32 nthEra, uint32  uid) external {
        _treasury._settle(token, nthEra, uid);
    }

    function setClaim(uint32 uid, uint32 num) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "IA");
        _treasury._setClaim(uid, num);
    }

    function setSettlement(uint32 uid) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "IA");
        _treasury._setSettlement(uid);
    }

    function refundFee(address to, address token, uint256 amount) external {
        require(hasRole(REPORTER_ROLE, msg.sender), "IA:notRprtr");
        TransferHelper.safeTransfer(token, to, amount);
    }

    function getReward(
        address token,
        uint32  nthEra,
        uint256 point) external view returns (uint256) {
        return _treasury._getReward(token, nthEra, point);
    }

    function getClaim(
        address token,
        uint32 uid,
        uint32 nthEra
    ) external view returns (uint256) {
        return _treasury._getClaim(token, uid, nthEra);
    }

     function getSettlement(
        address token,
        uint32 nthEra
    ) external view returns (uint256) {
        return _treasury._getSettlement(token, nthEra);
    }
}
