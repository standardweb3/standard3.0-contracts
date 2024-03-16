// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockBTC} from "../../contracts/mock/MockBTC.sol";
import {SABT} from "../../contracts/sabt/SABT.sol";
import {BlockAccountant} from "../../contracts/sabt/BlockAccountant.sol";
import {Membership} from "../../contracts/sabt/Membership.sol";
import {Treasury} from "../../contracts/sabt/Treasury.sol";
import {MockToken} from "../../contracts/mock/MockToken.sol";
//import {MatchingEngine} from "../../contracts/exchange/MatchingEngine.sol";
import {MatchingEngineMode} from "../../contracts/exchange/MatchingEngineMode.sol";
import {OrderbookFactory} from "../../contracts/exchange/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../contracts/exchange/orderbooks/Orderbook.sol";
import {Multicall3} from "../Multicall3.sol";
import {TokenDispenser} from "../../contracts/exchange/airdrops/TokenDispenser.sol";
import {ExchangeOrderbook} from "../../contracts/exchange/libraries/ExchangeOrderbook.sol";

interface IWETHMinimal {
    function WETH() external view returns (address);

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

contract Deployer is Script {
    function _setDeployer() internal {
        uint256 deployerPrivateKey = vm.envUint("LINEA_TESTNET_DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);
    }
}

contract DeployMulticall3 is Deployer {
    address multicall3 = 0x2CC505C4bc86B28503B5b8C450407D32e5E20A9f;
    function run() external {
        _setDeployer();
        new Multicall3();
        vm.stopBroadcast();
    }
}

contract DeployWETH is Deployer {
    function run() external {
        _setDeployer();
        vm.stopBroadcast();
    }
}

contract limitBuyatZeroPrice is Deployer {
    MatchingEngineMode matchingEngine;
    function run() external {
        _setDeployer();
        matchingEngine = MatchingEngineMode(payable(0x8D44C188E64045b64879fc7FD9fa80d81AbF9942));

        matchingEngine.limitBuy(0x4200000000000000000000000000000000000006, 0xf0F161fDA2712DB8b566946122a5af183995e2eD, 294800000002, 1000000000, false, 10, 0, 0x34CCCa03631830cD8296c172bf3c31e126814ce9);
        
    }
}

/**
 *Submitted for verification at Etherscan.io on 2018-10-22
*/


interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address to, uint256 value) external returns (bool);
}


contract Disperse {
    function disperseEther(address[] memory recipients, uint256[] memory values) external payable {
        for (uint256 i = 0; i < recipients.length; i++)
            payable(recipients[i]).transfer(values[i]);
        uint256 balance = address(this).balance;
        if (balance > 0)
            payable(msg.sender).transfer(balance);
    }

    function disperseToken(IERC20 token, address[] memory recipients, uint256[] memory values) external {
        uint256 total = 0;
        uint256 i;
        for (i = 0; i < recipients.length; i++)
            total += values[i];
        require(token.transferFrom(msg.sender, address(this), total));
        for (i = 0; i < recipients.length; i++)
            require(token.transfer(recipients[i], values[i]));
    }

    function disperseTokenSimple(IERC20 token, address[] memory recipients, uint256[] memory values) external {
        for (uint256 i = 0; i < recipients.length; i++)
            require(token.transferFrom(msg.sender, recipients[i], values[i]));
    }
}

contract DeployDisperse is Deployer {
    Disperse public disperse;
    function run() external {
        _setDeployer();
        disperse = new Disperse();
    }
}

contract BulkTokenSend is Deployer {
    Disperse public disperse;
    address disperse_address = 0x1B1e8dF857C7273a6195F58A842dC07Faf4Ee829;
    address token_address = 0xf0F161fDA2712DB8b566946122a5af183995e2eD;
    uint256 sum = 10 * 100 * 1e6;
    uint256[] values;

    address[] public addresses;

    function run() external {
        _setDeployer();
        IERC20 token = IERC20(token_address);
        addresses.push(0x83C401803fFF08E491964E9457Ffe43ff8f5c602);
        addresses.push(0x0e4e01FBEf1a828cA854623853DD6A80324cE012);
        addresses.push(0xdAc7a91516112703448B5d1fbC8B679fcE838E8A);
        addresses.push(0xe9255f2918F07Af51549Cb79d3FC80A313245711);
        addresses.push(0x88398Dac284753fc651CD475b42aa507413F4Fd2);
        addresses.push(0x33067aE72E88798be1F1ce04931E4bAfE9253edA);
        addresses.push(0xa4ed0039c932Cca988bF50d69eD76B4a51c8e149);
        addresses.push(0xC98e0Ac9925742b755f50Bb30868A5261DCb5FCC);
        addresses.push(0xcb98e7B24ec94bb606F0bee79355786545532A6f);
        addresses.push(0x4c0E052B255fFD9325aC869db3c4C718622b6c35);

        for (uint256 i = 0; i < addresses.length; i++) {
            values.push(100 * (1e6));
        }
        IERC20(token_address).approve(disperse_address, sum);
        disperse = Disperse(disperse_address);
        disperse.disperseToken(token, addresses, values);
    }
}

contract DeployExchangeMainnetContracts is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    /// Second per block to finalize
    uint32 constant spb = 12;
    address constant deployer_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant foundation_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant weth = 0x4200000000000000000000000000000000000006;
    Treasury public treasury;

    function run() external {
        _setDeployer();
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngineMode matchingEngine = new MatchingEngineMode();
        treasury = Treasury(0xBDf1c8C3fFd6f6C8E4AC13dAA3436Eb239D3e203);
        matchingEngine.initialize(
            address(orderbookFactory),
            address(treasury),
            address(weth)
        );
        orderbookFactory.initialize(address(matchingEngine));
        vm.stopBroadcast();
    }
}

pragma solidity 0.8.17;

/// @notice Implementation of CIP-001 https://github.com/Canto-Improvement-Proposals/CIPs/blob/main/CIP-001.md
/// @dev Every contract is responsible to register itself in the constructor by calling `register(address)`.
///      If contract is using proxy pattern, it's possible to register retroactively, however past fees will be lost.
///      Recipient withdraws fees by calling `withdraw(uint256,address,uint256)`.
interface IFeeSharing  {
   
    /// @notice Mints ownership NFT that allows the owner to collect fees earned by the smart contract.
    ///         `msg.sender` is assumed to be a smart contract that earns fees. Only smart contract itself
    ///         can register a fee receipient.
    /// @param _recipient recipient of the ownership NFT
    /// @return tokenId of the ownership NFT that collects fees
    function register(address _recipient) external returns (uint256 tokenId);

    /// @notice Assigns smart contract to existing NFT. That NFT will collect fees generated by the smart contract.
    ///         Callable only by smart contract itself.
    /// @param _tokenId tokenId which will collect fees
    /// @return tokenId of the ownership NFT that collects fees
    function assign(uint256 _tokenId) external returns (uint256);

    function isRegistered(address _smartContract) external view returns (bool);

    function getTokenId(address _smartContract) external view returns (uint256);


}


contract RegisterSFS is Deployer {
    address constant sfs = 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020;
    
    function run() external {
        IFeeSharing(sfs).isRegistered(0x34CCCa03631830cD8296c172bf3c31e126814ce9);
        IFeeSharing(sfs).register(0x34CCCa03631830cD8296c172bf3c31e126814ce9);
    }
}


contract DeploySABTMainnetContracts is Deployer {
    Treasury constant treasury =
        Treasury(0xBDf1c8C3fFd6f6C8E4AC13dAA3436Eb239D3e203);
    uint32 constant spb = 2;
    address constant weth = 0x4200000000000000000000000000000000000006; // weth on mainnet
    address constant stablecoin = 0xf0F161fDA2712DB8b566946122a5af183995e2eD; // usdc on mainnet
    address constant matchingEngine =
        0xe063Be26AAeb50db3866A7534551aA789bC368b7;
    address constant orderbookFactory =
        0x7a2e3a7A1bf8FaCCAd68115DC509DB5a5af4e7e4;
    address constant foundation_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;

    function run() external {
        _setDeployer();
        Membership membership = new Membership();
        SABT sabt = new SABT();
        membership.initialize(address(sabt), foundation_address, weth);
        sabt.initialize(address(membership));
        // Setup accountant and treasury
        BlockAccountant accountant = new BlockAccountant();
        accountant.initialize(
            address(membership),
            address(matchingEngine),
            address(stablecoin),
            spb
        );
        treasury.set(address(membership), address(accountant), address(sabt));
        treasury.setSettlement(1);
        
        // Wire up matching engine with them
        accountant.grantRole(accountant.REPORTER_ROLE(), address(treasury));
        treasury.grantRole(treasury.REPORTER_ROLE(), address(matchingEngine));
        accountant.setTreasury(address(treasury));
        membership.setMembership(10, weth, 0, 0, 1);
        membership.register(10, weth);
        treasury.settle(weth, 0, 1);
        IWETHMinimal(weth).withdraw(1491500765197174836);
        treasury.exchange(weth, 0, 1, 2500);
        IWETHMinimal(weth).withdraw(994333843464783220);
    }
}

contract TakeOutFees is Deployer {
    Treasury constant treasury =
        Treasury(0xBDf1c8C3fFd6f6C8E4AC13dAA3436Eb239D3e203);
    address token_address = 0xd988097fb8612cc24eeC14542bC03424c656005f;
    function run() external {
        _setDeployer();
        treasury.settle(token_address, 0, 1);
        treasury.exchange(token_address, 0, 1, 2500);
    }
}


contract DeployTokenDispenser is Deployer {
    function run() external {
        _setDeployer();
        TokenDispenser dispenser = new TokenDispenser();
        vm.stopBroadcast();
    }
}

contract AddAirdrop is Deployer {
    address constant airdrop_token_address =
        0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant dispenser_address =
        0xA8800c10F7276E2cfe025aAc849b812A2eC601fF;
    address constant deployer_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    MockToken public airdropToken = MockToken(airdrop_token_address);
    TokenDispenser public dispenser = TokenDispenser(dispenser_address);
    uint256 public deposit_amount = 1e40;
    uint256 public airdrop_amount = 100000e18;

    function run() external {
        _setDeployer();
        airdropToken.mint(deployer_address, deposit_amount);
        airdropToken.transfer(dispenser_address, deposit_amount);
        dispenser.setTokenAmount(airdrop_token_address, airdrop_amount);
        vm.stopBroadcast();
    }
}

contract TestAddPair is Deployer {
    address constant matching_engine_address =
        0x99e87D3f46079CeeE33859Fb6055A912090c9683;
    address constant base_address = 0xA219439258ca9da29E9Cc4cE5596924745e12B93;
    address constant quote_address = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;

    function run() external {
        _setDeployer();

        MatchingEngineMode matchingEngine = MatchingEngineMode(
            payable(matching_engine_address)
        );
        matchingEngine.addPair(address(base_address), address(quote_address));
    }
}

contract CancelOrder is Deployer {
    address constant matching_engine_address = 0xE02351341EE61f24BdddB9b03e8b30B145Ab1c60;
    address constant base = 0x4200000000000000000000000000000000000006;
    address constant quote = 0xf0F161fDA2712DB8b566946122a5af183995e2eD;

    function run() external {
        _setDeployer();

        MatchingEngineMode matchingEngine = MatchingEngineMode(payable(matching_engine_address));
        matchingEngine.cancelOrder(
            base,
            quote,
            true,
            5,
            0
        );
    }
}

contract TestOrderbookSell is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address =
        0x66a8b38D8B573Dbb6beBe163324b2DC0070d3430;
    address constant base_address = 0xA219439258ca9da29E9Cc4cE5596924745e12B93;
    address constant quote_address = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    MatchingEngineMode public matchingEngine =
        MatchingEngineMode(payable(matching_engine_address));
    MockToken public base = MockToken(base_address);
    MockToken public quote = MockToken(quote_address);
    Orderbook public book;

    function run() external {
        _setDeployer();

        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        base.approve(address(matchingEngine), 1e18);
        quote.approve(address(matchingEngine), 1e18);

        matchingEngine.mktPrice(address(base), address(quote));
        // add limit orders
        matchingEngine.limitSell(
            address(base),
            address(quote),
            50600,
            100000,
            true,
            1,
            0,
            msg.sender
        );
        //matchingEngine.getOrders(address(base), address(quote), true, 0, 0);
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(base),
            address(quote),
            false,
            20
        );
        console.log("Bid prices: ");
        for (uint256 i = 0; i < 3; i++) {
            console.log(askPrices[i]);
        }
        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log("bidHead: ", bidHead);
        console.log("askHead: ", askHead);
        vm.stopBroadcast();
    }
}

contract TestOrderbookBuy is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address =
        0xa2F02d36206EDD2EAE9Fd5FBaBd90CdFCE939614;
    address constant quote_address = 0xB79DD08EA68A908A97220C76d19A6aA9cBDE4376;
    address constant base_address = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;

    MatchingEngineMode public matchingEngine =
        MatchingEngineMode(payable(matching_engine_address));
    MockToken public base = MockToken(base_address);
    MockToken public quote = MockToken(quote_address);
    Orderbook public book;

    function run() external {
        _setDeployer();

        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        base.approve(address(matchingEngine), 100000e18);
        quote.approve(address(matchingEngine), 100000000e18);

        matchingEngine.mktPrice(address(base), address(quote));
        // add limit orders
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            2234e8,
            100000,
            true,
            1,
            0,
            msg.sender
        );
        //matchingEngine.getOrders(address(base), address(quote), true, 0, 0);
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(base),
            address(quote),
            false,
            20
        );
        console.log("Bid prices: ");
        for (uint256 i = 0; i < 3; i++) {
            console.log(askPrices[i]);
        }
        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log("bidHead: ", bidHead);
        console.log("askHead: ", askHead);
        vm.stopBroadcast();
    }
}

contract TestGetPrices is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address =
        0x99e87D3f46079CeeE33859Fb6055A912090c9683;
    address constant feeToken_address =
        0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant stablecoin_address =
        0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7;
    MatchingEngineMode public matchingEngine =
        MatchingEngineMode(payable(matching_engine_address));
    MockToken public feeToken = MockToken(feeToken_address);
    MockToken public stablecoin = MockToken(stablecoin_address);

    function run() external {
        _setDeployer();

        uint256[] memory bidPrices = matchingEngine.getPrices(
            address(feeToken),
            address(stablecoin),
            true,
            20
        );
        console.log("Ask prices: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(bidPrices[i]);
        }
        //matchingEngine.getOrders(address(base), address(quote), true, 0, 0);
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(feeToken),
            address(stablecoin),
            false,
            20
        );
        console.log("Bid prices: ");
        for (uint256 i = 0; i < 3; i++) {
            console.log(askPrices[i]);
        }

        vm.stopBroadcast();
    }
}

contract ShowOrderbook is Deployer {
    address constant matching_engine_address =
        0x2CC505C4bc86B28503B5b8C450407D32e5E20A9f;
    address constant base_address = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;
    address constant quote_address = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    MatchingEngineMode public matchingEngine =
        MatchingEngineMode(payable(matching_engine_address));

    function _orderbookIsEmpty(address b_addr, address q_addr, uint256 price, bool isBid) internal view returns (bool) {
        address orderbook = matchingEngine.getPair(b_addr, q_addr);
        console.log("Orderbook", orderbook);
        return Orderbook(payable(orderbook)).isEmpty(isBid, price);
    }

    function _showOrderbook(
        MatchingEngineMode matchingEngine,
        address base,
        address quote
    ) internal view {
        (uint256 bidHead, uint256 askHead) = matchingEngine.heads(base, quote);
        console.log("Bid Head: ", bidHead);
        console.log("Ask Head: ", askHead);
        console.log("is empty: ", _orderbookIsEmpty(base, quote, askHead, false));
        uint256[] memory bidPrices = matchingEngine.getPrices(
            address(base),
            address(quote),
            true,
            20
        );
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(base),
            address(quote),
            false,
            20
        );
        console.log("Ask prices: ");
        for (uint256 i = 0; i < 6; i++) {
            console.log(askPrices[i]);
            console.log("Ask Orders: ");
            uint32[] memory askOrderIds = matchingEngine.getOrderIds(
                address(base),
                address(quote),
                false,
                askPrices[i],
                10
            );
            ExchangeOrderbook.Order[] memory askOrders = matchingEngine
                .getOrders(
                    address(base),
                    address(quote),
                    false,
                    askPrices[i],
                    10
                );
            for (uint256 j = 0; j < 10; j++) {
                console.log(askOrderIds[j], askOrders[j].owner, askOrders[j].depositAmount);
            }
        }

        console.log("Bid prices: ");
        for (uint256 i = 0; i < 6; i++) {
            console.log(bidPrices[i]);
            console.log("Bid Orders: ");
            uint32[] memory bidOrderIds = matchingEngine.getOrderIds(
                address(base),
                address(quote),
                false,
                bidPrices[i],
                10
            );
            ExchangeOrderbook.Order[] memory bidOrders = matchingEngine
                .getOrders(
                    address(base),
                    address(quote),
                    true,
                    bidPrices[i],
                    10
                );
            for (uint256 j = 0; j < 10; j++) {
                console.log(bidOrderIds[j], bidOrders[j].owner, bidOrders[j].depositAmount);
            }
        }
    }

    function run() external {
        _setDeployer();
        _showOrderbook(
            MatchingEngineMode(payable(0x66a8b38D8B573Dbb6beBe163324b2DC0070d3430)),
            0xA219439258ca9da29E9Cc4cE5596924745e12B93,
            0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f
        );
        vm.stopBroadcast();
    }
}
