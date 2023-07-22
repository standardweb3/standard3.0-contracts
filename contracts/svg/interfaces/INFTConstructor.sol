pragma solidity ^0.8.17;

import "../libraries/NFTSVG.sol";

interface INFTConstructor {
    function generateParams(uint256 tokenId_)
        external
        view
        returns (
            NFTSVG.ChainParams memory cParam,
            NFTSVG.BlParams memory blParam,
            NFTSVG.HealthParams memory hParam,
            NFTSVG.CltParams memory cltParam
        );
}
