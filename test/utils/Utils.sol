pragma solidity >=0.8.17;

import {Test} from "forge-std/Test.sol";

contract Utils is Test {
    bytes32 internal nextUser = keccak256(abi.encodePacked("user address"));

    function getNextUserAddress() external returns (address payable) {
        address payable user = payable(address(uint160(uint256(nextUser))));
        nextUser = keccak256(abi.encodePacked(nextUser));
        return user;
    }

    // create users with 100 ETH balance each
    function createUsers(uint256 userNum) external returns (address payable[] memory) {
        address payable[] memory users = new address payable[](userNum);
        for (uint256 i = 0; i < userNum; i++) {
            address payable user = this.getNextUserAddress();
            vm.deal(user, 100 ether);
            users[i] = user;
        }

        return users;
    }

    function addUsers(uint256 userNum, address payable[] memory users) external returns (address payable[] memory) {
        uint256 len = users.length;
        uint256 newLen = len + userNum;
        address payable[] memory newUsers = new address payable[](newLen);
        for (uint256 i = 0; i < len; i++) {
            newUsers[i] = users[i];
        }
        for (uint256 i = len; i < newLen; i++) {
            address payable user = this.getNextUserAddress();
            vm.deal(user, 100 ether);
            newUsers[i] = user;
        }
        return newUsers;
    }

    // move block.number forward by a given number of blocks
    function mineBlocks(uint256 numBlocks) external {
        uint256 targetBlock = block.number + numBlocks;
        vm.roll(targetBlock);
    }
}
