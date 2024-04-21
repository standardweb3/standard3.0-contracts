// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {TransferHelper} from "./libraries/TransferHelper.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IERC20 {
    function balanceOf(address account) external returns (uint256 balance);
    function totalSupply() external returns (uint256);
    function burn(address account, uint256 amount) external returns (uint256 burned);
    function hasRole(bytes32 role, address account) external returns (bool);
}

contract PrizePool is Initializable {

    address point;
    address prize;

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    event PrizeReady(address pool, address prize, uint256 amount, address point, uint256 totalPoint, uint256 timestamp);
    error PrizeDoesNotExist(address prize, uint256 amount);
    error PoolIsNotBurner(bytes32 role, address pool);

    function initialize(address prize_, address point_) external initializer  {
        uint256 totalPrize = IERC20(prize_).balanceOf(address(this));
        if (totalPrize == 0) {
            revert PrizeDoesNotExist(prize_, totalPrize);
        }
        if (!IERC20(point_).hasRole(BURNER_ROLE, address(this))) {
            revert PoolIsNotBurner(BURNER_ROLE, address(this));
        }
        prize = prize_;
        point = point_;
        uint256 totalPoint = IERC20(point).totalSupply();
        emit PrizeReady(address(this), prize_, totalPrize, point_, totalPoint, block.timestamp);
    }
    
    function claim(uint256 amount) external {
        uint256 totalPrize = IERC20(prize).balanceOf(address(this));
        TransferHelper.safeTransfer(prize, msg.sender, totalPrize * amount / IERC20(point).totalSupply());
        IERC20(point).burn(msg.sender, amount);
    }
}