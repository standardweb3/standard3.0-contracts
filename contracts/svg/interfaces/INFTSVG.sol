

pragma solidity ^0.8.10;

interface INFTSVG {
   function tokenURI(uint256 tokenId) external view returns (string memory);
}