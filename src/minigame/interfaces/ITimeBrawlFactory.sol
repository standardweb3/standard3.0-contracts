// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITimeBrawl} from "./ITimeBrawl.sol";

interface ITimeBrawlFactory {
    function createBrawl(address base_, address quote_, uint256 startPrice_, address bet_, uint256 endTime_)
        external
        returns (address brawl);

    function isClone(address clone) external view returns (bool);

    function getBrawl(address base, address quote, uint256 id) external view returns (address brawl);

    function getBrawlInfo(address base, address quote, uint256 id)
        external
        view
        returns (ITimeBrawl.Brawl memory brawl);

    function initialize(address engine_) external;
}
