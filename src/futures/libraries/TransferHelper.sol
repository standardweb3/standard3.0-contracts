// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import {ILSP7DigitalAsset} from "@lukso/lsp7-contracts/contracts/ILSP7DigitalAsset.sol";

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    struct TokenInfo {
        address token;
        uint8 decimals;
        string name;
        string symbol;
        uint256 totalSupply;
    }

    function safeApprove(address token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes("approve(address,uint256)")));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "AF"
        );
    }

    function safeTransfer(address token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes("transfer(address,uint256)")));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TF"
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TFF"
        );
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "ETF");
    }

    function name(address token) internal view returns (string memory) {
        // bytes4(keccak256(bytes("name()")));
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(0x06fdde03)
        );
        require(success, "NF");
        return abi.decode(data, (string));
    }

    function symbol(address token) internal view returns (string memory) {
        // bytes4(keccak256(bytes("symbol()")));
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(0x95d89b41)
        );
        require(success, "SF");
        return abi.decode(data, (string));
    }

    function totalSupply(address token) internal view returns (uint256) {
        // bytes4(keccak256(bytes("totalSupply()")));
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(0x18160ddd)
        );
        require(success, "TSF");
        return abi.decode(data, (uint256));
    }

    function decimals(address token) internal view returns (uint8) {
        // bytes4(keccak256(bytes("decimals()")));
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(0x313ce567)
        );
        require(success, "DF");
        return abi.decode(data, (uint8));
    }

    function getTokenInfo(
        address token
    ) internal view returns (TokenInfo memory tokenInfo) {
        tokenInfo.token = token;
        tokenInfo.name = name(token);
        tokenInfo.symbol = symbol(token);
        tokenInfo.totalSupply = totalSupply(token);
        tokenInfo.decimals = decimals(token);
        return tokenInfo;
    }

    function lsp7Transfer(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes("transfer(address,address,uint256,bool,bytes)")));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                ILSP7DigitalAsset.transfer.selector,
                from,
                to,
                value,
                true,
                ""
            )
        );

        // Suggest using this function for abi-encoding
        // (bool success, bytes memory data) = token.call(abi.encodeCall(ILSP7DigitalAsset.transfer, from, to, value, true, ""));
        require(success && (data.length == 0), "AF");
    }
}
