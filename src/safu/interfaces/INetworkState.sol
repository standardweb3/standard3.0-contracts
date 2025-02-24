// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

interface INetworkState {
    /// View funcs
    /// NFT token address
    function v1() external view returns (address);
    /// Stablecoin address
    function meter() external view returns (address);
    /// UniswapV2Factory address
    function market() external view returns (address);
    /// Address of feeTo
    function feeTo() external view returns (address);
    /// Address of the dividend pool
    function dividend() external view returns (address);
    /// Address of Standard treasury
    function treasury() external view returns (address);
    /// Address of wrapped eth
    function WETH() external view returns (address);
    /// Desired of supply of meter to be minted
    function desiredSupply() external view returns (uint256);
    /// Switch to on/off rebase
    function rebaseActive() external view returns (bool);

    /// Getters
    /// Get Config of CDP
    function getCDPConfig(address collateral) external view returns (uint256, uint256, uint256, uint256);
    function getCDecimal(address collateral) external view returns (uint256);
    function getMCR(address collateral) external view returns (uint256);
    function getLFR(address collateral) external view returns (uint256);
    function getSFR(address collateral) external view returns (uint256);
    function getVault(uint256 vaultId_) external view returns (address);
    function getAssetPrice(address asset) external returns (uint256);
    function getAssetValue(address asset, uint256 amount) external returns (uint256);
    function isValidCDP(address collateral, address debt, uint256 cAmount, uint256 dAmount) external returns (bool);
    function vaultCodeHash() external pure returns (bytes32);
    function createCDP(address collateral_, uint256 cAmount_, uint256 dAmount_) external returns (bool success);

    /// Event
    event VaultCreated(uint256 vaultId, address collateral, address debt, address creator, address vault);
}
