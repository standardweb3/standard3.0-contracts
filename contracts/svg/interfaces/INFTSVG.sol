pragma solidity ^0.8.24;

interface INFTSVG {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
