// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Initializable} from "../../../security/Initializable.sol";
import {TransferHelper} from "../../libraries/TransferHelper.sol";
import {ITimeBrawl} from "../../interfaces/ITimeBrawl.sol";

contract TimeBrawl is Initializable, ITimeBrawl {

    uint256 id;
    address portal;
    uint256 startPrice;
    address public bet;
    uint256 total;
    // Time to exit brawl, the one who makes a showdown takes 1% of the total amount
    uint256 endTime;
    uint8 win;

    struct Pool {
        uint256 total;
        // percentage in 2 decimals (0.00%)
        mapping(address => uint32) percentage;
    }

    // 0: long, 1: short, 2: flat
    mapping(uint8 => Pool) contributions;

    function initialize(
        uint256 id_,
        address portal_,
        uint256 startPrice_,
        address bet_,
        uint256 endTime_
    ) external initializer {
        id = id_;
        portal = portal_;
        startPrice = startPrice_;
        bet = bet_;
        endTime = endTime_;
    }

    error InvalidAccess(address sender, address portal);
    error NotEndedYet(uint256 timeNow, uint256 endTime);
    error NoWinnersYet(uint8 win, uint256 timeNow, uint256 endTime);

    modifier onlyPortal() {
        if (msg.sender != portal) {
            revert InvalidAccess(msg.sender, portal);
        }
        _;
    }

    function _addAmountToPool(
        uint8 choice,
        address user,
        uint256 amount
    ) internal {
        Pool storage pool = contributions[choice];
        uint256 prevAmount = (pool.percentage[user] * pool.total) / 10000;
        pool.percentage[user] = uint32(
            ((prevAmount + amount) * 10000) / (pool.total + amount)
        );
        pool.total += amount;
    }

    function long(address user, uint256 amount) external onlyPortal {
        // accept bet token first
        _addAmountToPool(1, user, amount);
    }

    function short(address user, uint256 amount) external onlyPortal {
        _addAmountToPool(2, user, amount);
    }

    function flat(address user, uint256 amount) external onlyPortal {
        _addAmountToPool(3, user, amount);
    }

    function exit(uint256 endPrice) external onlyPortal {
        // check if the endtime is smaller than block.timestamp
        if (block.timestamp < endTime) {
            revert NotEndedYet(block.timestamp, endTime);
        }
        // long wins
        if (endPrice > startPrice) {
            // move short total to long
            contributions[1].total += contributions[1].total;
            // move flat total to long
            contributions[1].total += contributions[2].total;
            // delete all other pools except long
            delete contributions[2];
            delete contributions[3];
            win = 1;
        }
        // short wins
        else if (endPrice < startPrice) {
            // move long total to short
            contributions[2].total += contributions[1].total;
            // move flat total to short
            contributions[2].total += contributions[3].total;
            // delete all other pools except long
            delete contributions[1];
            delete contributions[3];
            win = 2;
        }
        // flat wins
        else {
            // move long total to flat
            contributions[3].total += contributions[1].total;
            // move short total to flat
            contributions[3].total += contributions[2].total;
            // delete all other pools except long
            delete contributions[1];
            delete contributions[2];
            win = 3;
        }
    }

    function claim(address user) external {
        if (win == 0) {
            revert NoWinnersYet(win, block.timestamp, endTime);
        }
        uint256 prize = (contributions[win].percentage[user] *
            contributions[win].total) / 10000;
        TransferHelper.safeTransfer(bet, user, prize);
    }

    function getBrawl() external view returns (ITimeBrawl.Brawl memory brawl) {
        return Brawl(
            portal,
            startPrice,
            bet,
            total,
            endTime,
            win
        );
    }
}
