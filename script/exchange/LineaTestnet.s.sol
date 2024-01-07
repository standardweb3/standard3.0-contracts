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
import {MatchingEngine} from "../../contracts/safex/MatchingEngine.sol";
import {OrderbookFactory} from "../../contracts/safex/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../contracts/safex/orderbooks/Orderbook.sol";
import {Multicall3} from "../Multicall3.sol";
import {TokenDispenser} from "../../contracts/safex/airdrops/TokenDispenser.sol";
import {ExchangeOrderbook} from "../../contracts/safex/libraries/ExchangeOrderbook.sol";

contract Deployer is Script {
    function _setDeployer() internal {
        uint256 deployerPrivateKey = vm.envUint("LINEA_TESTNET_DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);
    }
}

contract DeployMulticall3 is Deployer {
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

contract DeployTestnetAssets is Deployer {
    function run() external {
        _setDeployer();
        MockToken feeToken = new MockToken("Standard", "STND");
        MockToken stablecoin = new MockToken("Stablecoin", "STBC");
        vm.stopBroadcast();
    }
}

contract DeploySAFEXMainnetContracts is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    /// Second per block to finalize
    uint32 constant spb = 12;
    address constant deployer_address = 0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant foundation_address = 0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant weth = 0x2C1b868d6596a18e32E61B901E4060C872647b6C;

    Treasury public treasury;
    
    function run() external {
        _setDeployer();
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngine matchingEngine = new MatchingEngine();
        treasury = new Treasury();
        matchingEngine.initialize(
            address(orderbookFactory), address(treasury), address(weth)
        );
        orderbookFactory.initialize(address(matchingEngine));
        vm.stopBroadcast();
    }
}


contract DeploySABTMainnetContracts is Deployer {
    Treasury constant treasury = Treasury(0x228A9284c35e3E75820485cb5bA755a84Ac45874);
    uint32 constant spb = 12;
    address constant weth = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f; // weth on mainnet
    address constant feeToken = 0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant stablecoin = 0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7;
    address constant matchingEngine = 0xd2dCc9966bdEDf4130003a6224A8C9c7b15AC6A1;
    address constant foundation_address = 0x34CCCa03631830cD8296c172bf3c31e126814ce9;

    function run() external {
        Membership membership = new Membership();
        SABT sabt = new SABT();
        membership.initialize(address(sabt), foundation_address, weth);
        sabt.initialize(address(membership));
        // Setup accountant and treasury
        BlockAccountant accountant = new BlockAccountant();
        accountant.initialize(address(membership), address(matchingEngine), address(stablecoin), spb);
        treasury.set(address(membership), address(accountant), address(sabt));
        // Wire up matching engine with them
        accountant.grantRole(
            accountant.REPORTER_ROLE(),
            address(treasury)
        );
        treasury.grantRole(treasury.REPORTER_ROLE(), address(matchingEngine));
    }
}

contract DeployAll is Deployer {
    // Change address constants on deploying to other networks or private keys
    address constant deployer_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant trader1_address =
        0x6408fb579e106fC59f964eC33FE123738A2D0Da3;
    address constant trader2_address =
        0xf5aE3B9dF4e6972a229E7915D55F9FBE5900fE95;
    address constant foundation_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant weth_address = 0x2C1b868d6596a18e32E61B901E4060C872647b6C;
    // seconds per block
    uint32 spb = 12;
    Treasury public treasury;

    function run() external {
        _setDeployer();

        // DeployAssets
        MockToken feeToken = new MockToken("Standard", "STND");
        MockToken stablecoin = new MockToken("Stablecoin", "STBC");

        // DeployContracts
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngine matchingEngine = new MatchingEngine();
        Membership membership = new Membership();
        SABT sabt = new SABT();
        membership.initialize(address(sabt), foundation_address, weth_address);
        sabt.initialize(address(membership));
        // Setup accountant and treasury
        BlockAccountant accountant = new BlockAccountant();
        accountant.initialize(
            address(membership),
            address(matchingEngine),
            address(stablecoin),
            spb
        );
        treasury = new Treasury();
        treasury.set(address(membership), address(accountant), address(sabt));
        matchingEngine.initialize(
            address(orderbookFactory),
            address(treasury),
            address(weth_address)
        );
        orderbookFactory.initialize(address(matchingEngine));
        // Wire up matching engine with them
        accountant.grantRole(
            accountant.REPORTER_ROLE(),
            address(treasury)
        );
        treasury.grantRole(treasury.REPORTER_ROLE(), address(matchingEngine));

        // DistributeAssets
        // Mint fee Token to the deployer, trader1, trader2
        feeToken.mint(deployer_address, 1000000000000000000000000e18);
        feeToken.mint(trader1_address, 100000e18);
        feeToken.mint(trader2_address, 100000e18);

        // Mint stablecoin to the deployer, trader1, trader2
        stablecoin.mint(deployer_address, 1000000000000000000000000000e18);
        stablecoin.mint(trader1_address, 100000e18);
        stablecoin.mint(trader2_address, 100000e18);

        // SetupSABTInitialParameters
        // set Fee in membership contract
        membership.setMembership(1, address(feeToken), 1000, 1000, 10000);

        // Get membership
        feeToken.approve(address(membership), 1e30);
        membership.register(1, address(feeToken));
        membership.subscribe(1, 1000000, address(feeToken));

        // SetupSAFEXInitialParameters
        // Setup pair between stablecoin and feeToken with price
        feeToken.approve(address(matchingEngine), 100000e18);
        matchingEngine.addPair(address(feeToken), address(stablecoin));

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        feeToken.approve(address(matchingEngine), 100000e18);
        stablecoin.approve(address(matchingEngine), 100000000e18);
        // add limit orders
        matchingEngine.limitSell(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10000e18,
            true,
            1,
            0,
            msg.sender
        );
        matchingEngine.limitBuy(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10000000e18,
            false,
            1,
            1,
            msg.sender
        );

        // DeployTokenDispenser
        TokenDispenser dispenser = new TokenDispenser();

        uint256 deposit_amount = 1e40;
        uint256 airdrop_amount = 100000e18;

        // AddAirdrop
        feeToken.mint(deployer_address, deposit_amount);
        feeToken.transfer(address(dispenser), deposit_amount);
        dispenser.setTokenAmount(address(feeToken), airdrop_amount);

        stablecoin.mint(deployer_address, deposit_amount);
        stablecoin.transfer(address(dispenser), deposit_amount);
        dispenser.setTokenAmount(address(stablecoin), airdrop_amount);

        vm.stopBroadcast();
    }
}


contract DeployTestnetContracts is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    /// Second per block to finalize
    uint32 constant spb = 12;
    address constant deployer_address = 0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant foundation_address = 0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant weth = 0x2C1b868d6596a18e32E61B901E4060C872647b6C;
    address constant feeToken = 0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant stablecoin = 0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7;
    Treasury public treasury;

    function run() external {
        _setDeployer();
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngine matchingEngine = new MatchingEngine();
        Membership membership = new Membership();
        SABT sabt = new SABT();
        membership.initialize(address(sabt), foundation_address, weth);
        sabt.initialize(address(membership));
        // Setup accountant and treasury
        BlockAccountant accountant = new BlockAccountant();
        accountant.initialize(address(membership), address(matchingEngine), address(stablecoin), spb);
        treasury = new Treasury();
        treasury.set(address(membership), address(accountant), address(sabt));
        matchingEngine.initialize(
            address(orderbookFactory), address(treasury), address(weth)
        );
        orderbookFactory.initialize(address(matchingEngine));
        // Wire up matching engine with them
        accountant.grantRole(
            accountant.REPORTER_ROLE(),
            address(treasury)
        );
        treasury.grantRole(treasury.REPORTER_ROLE(), address(matchingEngine));
        vm.stopBroadcast();
    }
}

contract DistributeTestnetAssets is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant deployer_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant trader1_address =
        0x6408fb579e106fC59f964eC33FE123738A2D0Da3;
    address constant trader2_address =
        0xf5aE3B9dF4e6972a229E7915D55F9FBE5900fE95;
    address constant feeToken_address =
        0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant stablecoin_address =
        0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7;

    MockToken public feeToken = MockToken(feeToken_address);
    MockToken public stablecoin = MockToken(stablecoin_address);

    function run() external {
        _setDeployer();
        // Mint fee Token to the deployer, trader1, trader2
        feeToken.mint(deployer_address, 1000000000000000000000000e18);
        feeToken.mint(trader1_address, 100000e18);
        feeToken.mint(trader2_address, 100000e18);

        // Mint stablecoin to the deployer, trader1, trader2
        stablecoin.mint(deployer_address, 1000000000000000000000000000e18);
        stablecoin.mint(trader1_address, 100000e18);
        stablecoin.mint(trader2_address, 100000e18);

        vm.stopBroadcast();
    }
}

contract SetupSABTInitialParameters is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address =
        0x1779583579564b34232021590E6d19cAd0277973;
    address constant membership_address =
        0xc46344c6d449CD510f8080cD361e12624c1D91DF;
    address constant sabt_address = 0x4062731e9330301ca5C4DEFEcF7C20A81acF2d43;
    address constant feeToken_address =
        0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant stablecoin_address =
        0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7;
    address constant block_accountant_address =
        0xc9033EFD4CD42fC6Fdd22dFdCbbf391099BD6d22;
    address constant treasury_address =
        0xd47F27E3312B946c9C38Ca08bB1e9dF2Fac04724;
    address constant deployer_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;

    Membership public membership = Membership(membership_address);
    SABT public sabt = SABT(sabt_address);
    MockToken public stablecoin = MockToken(stablecoin_address);
    MockToken public feeToken = MockToken(feeToken_address);
    BlockAccountant public accountant =
        BlockAccountant(block_accountant_address);
    Treasury public treasury = Treasury(treasury_address);

    function run() external {
        _setDeployer();
        // set Fee in membership contract
        membership.setMembership(1, feeToken_address, 1000, 1000, 10000);

        // Get membership
        feeToken.approve(membership_address, 1e30);
        membership.register(1, feeToken_address);
        membership.subscribe(1, 1000000, feeToken_address);

        vm.stopBroadcast();
    }
}

contract SetupSAFEXInitialParameters is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address =
        0x1779583579564b34232021590E6d19cAd0277973;
    address constant feeToken_address =
        0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant stablecoin_address =
        0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7;
    MatchingEngine public matchingEngine =
        MatchingEngine(payable(matching_engine_address));
    MockToken public feeToken = MockToken(feeToken_address);
    MockToken public stablecoin = MockToken(stablecoin_address);

    function run() external {
        _setDeployer();
        // Setup pair between stablecoin and feeToken with price
        feeToken.approve(address(matchingEngine), 100000e18);
        matchingEngine.addPair(address(feeToken), address(stablecoin));

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        feeToken.approve(address(matchingEngine), 100000e18);
        stablecoin.approve(address(matchingEngine), 100000000e18);
        // add limit orders
        matchingEngine.limitSell(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10000e18,
            true,
            1,
            0,
            msg.sender
        );
        matchingEngine.limitBuy(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10000000e18,
            false,
            1,
            1,
            msg.sender
        );
        vm.stopBroadcast();
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

contract TestOrderbookSell is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address =
        0xa7431faC42c7D5ff6C5EE297B9D65960B9970f12;
    address constant feeToken_address =
        0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant stablecoin_address =
        0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7;
    MatchingEngine public matchingEngine =
        MatchingEngine(payable(matching_engine_address));
    MockToken public feeToken = MockToken(feeToken_address);
    MockToken public stablecoin = MockToken(stablecoin_address);
    Orderbook public book;

    function run() external {
        _setDeployer();

        book = Orderbook(
            payable(matchingEngine.getBookByPair(address(feeToken), address(stablecoin)))
        );

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        feeToken.approve(address(matchingEngine), 100000e18);
        stablecoin.approve(address(matchingEngine), 100000000e18);
        // add limit orders
        matchingEngine.limitSell(
            address(feeToken),
            address(stablecoin),
            100002e6,
            10000e18,
            true,
            1,
            0,
            msg.sender
        );
        //matchingEngine.getOrders(address(token1), address(token2), true, 0, 0);
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
        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log("bidHead: ", bidHead);
        console.log("askHead: ", askHead);
        vm.stopBroadcast();
    }
}

contract TestGetPrices is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address =
        0xa7431faC42c7D5ff6C5EE297B9D65960B9970f12;
    address constant feeToken_address =
        0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant stablecoin_address =
        0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7;
    MatchingEngine public matchingEngine =
        MatchingEngine(payable(matching_engine_address));
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
        //matchingEngine.getOrders(address(token1), address(token2), true, 0, 0);
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
        0x6Dd6A2D269b2e971272e3a29fc204Fe35B20E827;
    address constant base_address = 0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant quote_address = 0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7;
    MatchingEngine public matchingEngine =
        MatchingEngine(payable(matching_engine_address));

    function _orderbookIsEmpty(address b_addr, address q_addr, uint256 price, bool isBid) internal view returns (bool) {
        address orderbook = matchingEngine.getBookByPair(b_addr, q_addr);
        console.log("Orderbook", orderbook);
        return Orderbook(payable(orderbook)).isEmpty(isBid, price);
    }

    function _showOrderbook(
        MatchingEngine matchingEngine,
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
            ExchangeOrderbook.Order[] memory askOrders = matchingEngine
                .getOrders(
                    address(base),
                    address(quote),
                    false,
                    askPrices[i],
                    10
                );
            for (uint256 j = 0; j < 10; j++) {
                console.log(askOrders[j].owner, askOrders[j].depositAmount);
            }
        }

        console.log("Bid prices: ");
        for (uint256 i = 0; i < 6; i++) {
            console.log(bidPrices[i]);
            console.log("Bid Orders: ");
            ExchangeOrderbook.Order[] memory bidOrders = matchingEngine
                .getOrders(
                    address(base),
                    address(quote),
                    true,
                    bidPrices[i],
                    10
                );
            for (uint256 j = 0; j < 10; j++) {
                console.log(bidOrders[j].owner, bidOrders[j].depositAmount);
            }
        }
    }

    function run() external {
        _setDeployer();
        _showOrderbook(
            MatchingEngine(payable(0x6Dd6A2D269b2e971272e3a29fc204Fe35B20E827)),
            0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7,
            0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815
        );
        vm.stopBroadcast();
    }
}
