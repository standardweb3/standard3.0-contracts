pragma solidity ^0.8.24;

import "../libraries/FuturesPool.sol";
interface IPerpPoolFactory {
    struct Pool {
        uint256 id;
        address base;
        address quote;
        address collateral;
        address engine;
        address perp;
    }

    function engine() external view returns (address);

    function perp() external view returns (address);

    function impl() external view returns (address);

    function createPerpPool(
        address base_,
        address quote_,
        address collateral_
    ) external returns (address orderbook);

    function setListingCost(
        address payment,
        uint256 amount
    ) external returns (uint256);

    function isClone(address vault) external view returns (bool cloned);

    function getPool(address base, address quote, address collateral) external view returns (address book);

    function getByteCode() external view returns (bytes memory bytecode);

    function getListingCost(address payment) external view returns (uint256 amount);

}