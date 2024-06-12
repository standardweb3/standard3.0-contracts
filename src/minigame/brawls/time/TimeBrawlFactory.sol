// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/src/access/AccessControl.sol";
import {TimeBrawl, ITimeBrawl} from "./TimeBrawl.sol";
import {CloneFactory} from "../../libraries/CloneFactory.sol";
import {Initializable} from "@openzeppelin/src-upgradeable/proxy/utils/Initializable.sol";
import {ITimeBrawlFactory} from "../../interfaces/ITimeBrawlFactory.sol";

interface IERC20 {
    function symbol() external view returns (string memory);
}

contract TimeBrawlFactory is ITimeBrawlFactory, Initializable {
    // Orderbooks
    address[] public allBrawls;
    /// Address of manager
    address public portal;
    /// version number of impl
    uint32 public version;
    /// address of order impl
    address public impl;

    error InvalidAccess(address sender, address allowed);
    error BrawlAlreadyExists(uint256 id, address brawl);
    error SameBaseQuote(address base, address quote);

    constructor() {
    }

    function createBrawl(
        address base,
        address quote,
        uint256 startPrice_,
        address bet_,
        uint256 endTime_
    ) external override returns (address orderbook) {
        if (msg.sender != portal) {
            revert InvalidAccess(msg.sender, portal);
        }

        uint id = allBrawlsLength() + 1;

        address brawl = _predictAddress(base, quote, id);

        // Check if the address has code
        uint32 size;
        assembly {
            size := extcodesize(brawl)
        }

        // If the address has code and it's a clone of impl, revert.
        if (size > 0 || CloneFactory._isClone(impl, brawl)) {
            revert BrawlAlreadyExists(id, brawl);
        }

        address proxy = CloneFactory._createCloneWithSalt(
            impl,
            _getSalt(base, quote, id)
        );
        ITimeBrawl(proxy).initialize(
            id,
            portal,
            startPrice_,
            bet_,
            endTime_
        );
        allBrawls.push(proxy);
        return (proxy);
    }

    function isClone(address clone) external view returns (bool cloned) {
        cloned = CloneFactory._isClone(impl, clone);
    }

    function getBrawl(address base, address quote, uint256 id) external view returns (address brawl) {
        return _predictAddress(base, quote, id);
    }

    function getBrawlInfo(address base, address quote, uint256 id) external view override returns (ITimeBrawl.Brawl memory brawl) {
        return ITimeBrawl(_predictAddress(base, quote, id)).getBrawl();
    }


    /**
     * @dev Initialize orderbook factory contract with engine address, reinitialize if engine is reset.
     * @param portal_ The address of the engine contract
     */
    function initialize(address portal_) public initializer {
        portal = portal_;
        _createImpl();
    }

    function allBrawlsLength() public view returns (uint256) {
        return allBrawls.length;
    }

    // Set immutable, consistant, one rule for orderbook implementation
    function _createImpl() internal {
        address addr;
        bytes memory bytecode = type(TimeBrawl).creationCode;
        bytes32 salt = keccak256(abi.encodePacked("timebrawl", version));
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        impl = addr;
    }

    function _predictAddress(
        address base,
        address quote,
        uint256 id
    ) internal view returns (address) {
        bytes32 salt = _getSalt(base, quote, id);
        return CloneFactory.predictAddressWithSalt(address(this), impl, salt);
    }

    function _getSalt(
        address base,
        address quote,
        uint256 id
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(base, quote, id));
    }
}
