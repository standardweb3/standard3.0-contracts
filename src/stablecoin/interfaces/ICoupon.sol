pragma solidity ^0.8.0;

interface ICoupon {
    function mint(address to, uint256 tokenId_) external;
    function burn(uint256 tokenId_) external;
    function burnFromVault(uint256 vaultId_) external;
    function exists(uint256 tokenId_) external view returns (bool);
}
