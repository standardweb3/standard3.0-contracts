// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @author Hyungsuk Kang <hskang9@github.com>
/// @title Metadata contract for SABT
contract Metadata is AccessControl {
    function uri(uint256 id_) public view virtual returns (string memory) {
        return "https://arts.standard.tech/";
    }
}
