pragma solidity ^0.8.10;

interface IAccountant {
    function convert(
        address base,
        address quote,
        uint256 amount,
        bool isAsk
    ) external view returns (uint256 converted);

    function decimals() external view returns (uint8);
}

/// @author Hyungsuk Kang <hskang9@gmail.com>
/// @title Standard Membership Accountant to report membership points
library TimeAccountantLib {
    struct Storage {
        /// @dev ft: Financial timestamp that started financing the DAO. Time can be manipulated by miners, but it is only 15 seconds.
        uint256 ft;
        /// @dev pointOf: The mapping of the month to the mapping of the member UID to the point, each accountant can account 4,294,967,295 eras, each era is 28 days
        mapping(uint32 => mapping(uint64 => uint64)) pointOf;
        mapping(uint32 => uint64) totalPointsOn;
        mapping(bytes32 => uint64) totalRewardsOn;
        address membership;
        address engine;
        address stablecoin;
    }

    function _setTotalReward(Storage storage self, address token, uint32 era, uint64 value, bool isAdd) internal {
        bytes32 key = keccak256(abi.encodePacked(token, era));
        isAdd ? self.totalRewardsOn[key] += value : self.totalRewardsOn[key] -= value;
    }

    function _getTotalTokens(Storage storage self, address token, uint32 era) internal view returns (uint64) {
        bytes32 key = keccak256(abi.encodePacked(token, era));
        return self.totalRewardsOn[key];
    }

    /**  @dev reportAdd: Report the membership point of the member
     * @param uid The member UID
     * @param token The token address
     * @param amount The amount of the membership point
     * @param isAdd The flag to add or subtract the point
     */
    function _report(
        Storage storage self,
        uint32 uid,
        address token,
        uint256 amount,
        bool isAdd
    ) internal {
        // check if the asset has pair in the orderbook dex between stablecoin
        uint256 converted = IAccountant(self.engine).convert(
            token,
            self.stablecoin,
            amount,
            false
        );
        if (converted == 0) {
            // if price is zero, return as the asset cannot be accounted
            return;
        } else {
            // if it is, get USD value then calculate the point by 5 decimals
            uint32 nthEra = uint32((block.timestamp - self.ft) / 28 days);
            uint64 point = uint64(
                (converted * 1e5) / IAccountant(token).decimals()
            );
            isAdd ? self.pointOf[nthEra][uid] += point : self.pointOf[nthEra][
                uid
            ] -= point;
            isAdd ? self.totalPointsOn[nthEra] += point : self.totalPointsOn[
                nthEra
            ] -= point;
            _setTotalReward(self, token, nthEra, point, isAdd);
        }
    }

    function _totalPoints(
        Storage storage self,
        uint32 nthEra
    ) internal view returns (uint64) {
        return self.totalPointsOn[nthEra];
    }

    function _totalRewards(
        Storage storage self,
        uint32 nthEra,
        address token
    ) internal view returns (uint64) {
        return _getTotalTokens(self, token, nthEra);
    }

    function _getMP(
        Storage storage self,
        uint32 uid,
        uint32 nthEra
    ) internal view returns (uint64) {
        return self.pointOf[nthEra][uid];
    }
}
