// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OrderbookHook} from "./OrderbookHook.sol";

import {BaseHook} from "periphery-next/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract OrderbookStub is OrderbookHook {
    constructor(
        IPoolManager _poolManager,
        OrderbookHook addressToEtch
    ) OrderbookHook(_poolManager, "") {}

    // make this a no-op in testing
    function validateHookAddress(BaseHook _this) internal pure override {}
}