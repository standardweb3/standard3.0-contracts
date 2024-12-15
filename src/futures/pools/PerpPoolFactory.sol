// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {PerpPool, IPerpPool} from "./PerpPool.sol";
import {CloneFactory} from "../libraries/CloneFactory.sol";
import {IPerpPoolFactory} from "../interfaces/IPerpPoolFactory.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

interface IERC20 {
    function symbol() external view returns (string memory);
}

contract PerpPoolFactory is IPerpPoolFactory, Initializable {
    // Orderbooks
    address[] public allPools;
    /// Address of engine
    address public override engine;
    /// Address of perp
    address public override perp;
    /// version number of impl
    uint32 public version;
    /// address of order impl
    address public impl;
    /// listing cost of pair, for each fee token.
    mapping(address => uint256) public listingCosts;

    error InvalidAccess(address sender, address allowed);
    error PoolAlreadyExists(address base, address quote, address pair);
    error SameBaseQuote(address base, address quote);

    constructor() {
    }

    function createPerpPool(
        address base_,
        address quote_,
        address collateral_
    ) external override returns (address orderbook) {
        if (msg.sender != engine) {
            revert InvalidAccess(msg.sender, engine);
        }

        if (base_ == quote_) {
            revert SameBaseQuote(base_, quote_);
        }

        address pool = _predictAddress(base_, quote_, collateral_);

        // Check if the address has code
        uint32 size;
        assembly {
            size := extcodesize(pool)
        }

        // If the address has code and it's a clone of impl, revert.
        if (size > 0 || CloneFactory._isClone(impl, pool)) {
            revert PoolAlreadyExists(base_, quote_, pool);
        }

        address proxy = CloneFactory._createCloneWithSalt(
            impl,
            _getSalt(base_, quote_, collateral_)
        );
        IPerpPool(proxy).initialize(allPoolsLength(), base_, quote_, collateral_, engine, perp);
        allPools.push(proxy);
        return (proxy);
    }

    function isClone(address vault) external view returns (bool cloned) {
        cloned = CloneFactory._isClone(impl, vault);
    }

    function getPoolById(uint256 poolId_) external view returns (address) {
        return allPools[poolId_];
    }

    function getPool(
        address base,
        address quote,
        address collateral
    ) external view override returns (address pool) {
        pool = _predictAddress(base, quote, collateral);
        return address(pool).code.length > 0 ? pool : address(0);
    }

    /**
     * @dev Initialize orderbook factory contract with engine address, reinitialize if engine is reset.
     * @param engine_ The address of the engine contract
     * @return address of pair implementation contract
     */
    function initialize(address engine_, address perp_) public initializer returns (address) {
        engine = engine_;
        perp = perp_;
        _createImpl();
        return impl;
    }

    function allPoolsLength() public view returns (uint256) {
        return allPools.length;
    }

    // Set immutable, consistant, one rule for orderbook implementation
    function _createImpl() internal {
        address addr;
        bytes memory bytecode = type(PerpPool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked("perppool", version));
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        impl = addr;
    }

    function _predictAddress(
        address base_,
        address quote_,
        address collateral_
    ) internal view returns (address) {
        bytes32 salt = _getSalt(base_, quote_, collateral_);
        return CloneFactory.predictAddressWithSalt(address(this), impl, salt);
    }

    function _getSalt(
        address base_,
        address quote_,
        address collateral_
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(base_, quote_, collateral_));
    }

    function getByteCode() external view returns (bytes memory bytecode) {
        return CloneFactory.getBytecode(impl);
    }

    function getListingCost(address token) external view returns (uint256) {
        return listingCosts[token];
    }

    //  Set up listing cost for each token, each pair creates 2GB of data in a month, costing 0.1 ETH
    function setListingCost(
        address payment,
        uint256 amount
    ) external returns (uint256) {
        if (msg.sender != engine) {
            revert InvalidAccess(msg.sender, engine);
        }
        listingCosts[payment] = amount;
        return amount;
    }
}
