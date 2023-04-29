pragma solidity ^0.8.10;

interface IAccountant {
    function isSubscribed(address account) external view returns (bool);
    function subtractMP(address account, uint256 nthMonth, uint256 amount) external;
    function getReward(address account, uint256 nthMonth) external view returns (uint256);
    function getTotalPoints(uint256 nthMonth) external view returns (uint256);
    function getTotalTokens(uint256 nthMonth, address token) external view returns (uint256);
}