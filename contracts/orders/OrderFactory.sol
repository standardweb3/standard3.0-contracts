// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Order.sol";
import "../libraries/CloneFactory.sol";
import "../interfaces/IOrderFactory.sol";
import "../interfaces/IEngine.sol";

contract OrderFactory is AccessControl, IOrderFactory {
    // Vaults
    address[] public allOrders;
    /// Address of Wrapped Ether
    address public override WETH;
    /// version number of impl
    uint32 public version;
    /// address of order impl
    address public impl;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _createImpl();
    }

    /// Vault can issue stablecoin, it just manages the position
    function createOrder(
        uint256 pairId_,
        address owner_,
        address orderbook_,
        address WETH_,
        bool isAsk_,
        uint256 price_,
        address deposit_,
        uint256 depositAmount_
    ) external override returns (address vault, uint256 id) {
      // check if sender is the orderbook and the orderbook is registered in engine
        uint256 bookId = IOrderbook(msg.sender).id();
        address engine = IOrderbook(msg.sender).engine();
        require(IEngine(engine).getOrderbook(bookId) == msg.sender, "OrderFactory: IA");
        uint256 gIndex = allOrdersLength();
        address proxy = CloneFactory._createClone(impl);
        IOrder(proxy).initialize(
            pairId_,
            owner_,
            orderbook_,
            WETH_,
            isAsk_,
            price_,
            deposit_,
            depositAmount_
        );
        allOrders.push(proxy);
        return (proxy, gIndex);
    }

    // Set immutable, consistent, one rule for vault implementation
    function _createImpl() internal {
        address addr;
        bytes memory bytecode = type(Order).creationCode;
        bytes32 salt = keccak256(abi.encodePacked("order", version));
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        impl = addr;
    }

    function isClone(address vault) external view returns (bool cloned) {
        cloned = CloneFactory._isClone(impl, vault);
    }

    function initialize(address weth_) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "IA"); // Invalid Access
        WETH = weth_;
    }

    function getOrder(uint256 vaultId_)
        external
        view
        override
        returns (address)
    {
        return allOrders[vaultId_];
    }

    function allOrdersLength() public view returns (uint256) {
        return allOrders.length;
    }
}
