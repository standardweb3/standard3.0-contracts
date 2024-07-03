// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface ITimeBrawl {
    struct Brawl {  
        address portal;
        uint256 startPrice;
        address bet;
        uint256 total;
        // Time to exit brawl, the one who makes a showdown takes 1% of the total amount
        uint256 endTime;
        uint8 win;
    }

    function initialize(
        uint id, 
        address portal_,
        uint256 startPrice_,
        address bet_,
        uint256 endTime_
    ) external;

    function long(address user, uint256 amount) external;

    function short(address user, uint256 amount) external;

    function flat(address user, uint256 amount) external;

    function exit(uint256 endPrice) external;

    function claim(address user) external;

    function getBrawl() external view returns (Brawl memory brawl);

    function bet() external view returns (address bet);
}
