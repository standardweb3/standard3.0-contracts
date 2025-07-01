// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import {IProtocol} from "./interfaces/IProtocol.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Incentive is IProtocol, AccessControl {
    address public membership;

    // fee numerator mappings: key: membership level, value: fee numerator
    mapping(uint32 => uint32) public feeNumerators;

    // terminal name mappings: key: terminal address, value: terminal name
    mapping(address => string) public terminalNames;

    function feeOf(address base, address quote, address account, bool isMaker) external view returns (uint32 feeNum) {
        // TODO: check if the account is terminal
        // TODO: get membership level from membership contract
        // TODO: get fee numerator from feeNumerators
        return 0;
    }

    function isSubscribed(address account) external view returns (bool) {
        // TODO: check membership from membership contract
        return false;
    }

    function terminalName(address terminal) external view returns (string memory name) {
        return terminalNames[terminal];
    }

    function accountFee(address account, bool isMaker) external view returns (uint256 feeNum) {
        // TODO: get membership level from membership contract
        // TODO: get fee numerator from feeNumerators
        return 0;
    }
}
