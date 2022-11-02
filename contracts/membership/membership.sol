// SPDX-License-Identifier: Apache-2.0


pragma solidity ^0.8.10;

contract Membership {

    mapping(address => uint256) points;

    function addPoints(address member, uint256 amount) public {
        points[member] += amount;
    }

    // exchange with NFT

    // claim shares with NFT in an era

    // fees
}