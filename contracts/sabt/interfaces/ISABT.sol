// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface ISABT {
    function mint(address to_, uint32 id_) external;
    function balanceOf(address owner_, uint256 id_) external view returns (uint256);
    function setRegistered(uint256 id_, bool yesOrNo) external;
}