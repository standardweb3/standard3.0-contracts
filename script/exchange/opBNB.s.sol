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
            weth_address
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
            0
        );
        matchingEngine.limitBuy(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10000000e18,
            false,
            1,
            1
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
    address constant deployer_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant foundation_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant weth = 0x2C1b868d6596a18e32E61B901E4060C872647b6C;
    address constant feeToken = 0x0622C0b5F53FF7252A5F90b4031a9adaa67a2d02;
    address constant stablecoin = 0x11a681c574F8e1d72DDCEEe0855032A77dfF8355;
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
            weth
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
        0x0622C0b5F53FF7252A5F90b4031a9adaa67a2d02;
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
        0x8a22e83Aaf7E90eEab385C4d97cbD5F6a58d5DF7;
    address constant membership_address =
        0xd5EC00dbaDF8d9369e5b330645478aAFA298A73D;
    address constant sabt_address = 0x240aA2c15fBf6F65882A847462b04d5DA51A37Df;
    address constant feeToken_address =
        0x0622C0b5F53FF7252A5F90b4031a9adaa67a2d02;
    address constant stablecoin_address =
        0x11a681c574F8e1d72DDCEEe0855032A77dfF8355;
    address constant block_accountant_address =
        0xb31e69f571c3B4219710931e86a9BC8b8378fb1E;
    address constant treasury_address =
        0x86b3Bd0C9896b97f6aCfBA87E6CEe0033FF708F8;
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
        0x8a22e83Aaf7E90eEab385C4d97cbD5F6a58d5DF7;
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
            0
        );
        matchingEngine.limitBuy(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10000000e18,
            false,
            1,
            1
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
            0
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
