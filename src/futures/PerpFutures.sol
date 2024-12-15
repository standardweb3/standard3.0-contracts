// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;
import {IPerpPoolFactory} from "./interfaces/IPerpPoolFactory.sol";
import {IPerpPool, FuturesPool} from "./interfaces/IPerpPool.sol";
import {TransferHelper} from "./libraries/TransferHelper.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface IRevenue {
    function reportMatch(
        address orderbook,
        address give,
        bool isBid,
        address sender,
        address owner,
        uint256 amount
    ) external;

    function isReportable() external view returns (bool isReportable);

    function feeOf(
        address account,
        bool isMaker
    ) external view returns (uint32 feeNum);

    function isSubscribed(
        address account
    ) external view returns (bool isSubscribed);
}

interface IDecimals {
    function decimals() external view returns (uint8 decimals);
}

// Onchain Matching engine for the orders
contract PerpFutures is ReentrancyGuard, AccessControl {
    // Market maker role
    bytes32 private constant MARKET_MAKER_ROLE = keccak256("MARKET_MAKER_ROLE");
    // fee recipient for point storage
    address private feeTo;
    // fee denominator representing 0.001%, 1/1000000 = 0.001%
    uint32 public constant feeDenom = 1000000;
    // Factories
    address public perpPoolFactory;
    // WETH
    address public WETH;
    // default long spread
    uint32 defaultLong;
    // default short spread
    uint32 defaultShort;
    // bool on initialization
    bool init;

    struct OrderData {
        /// Amount after removing fee
        uint256 withoutFee;
        /// Orderbook contract address
        address orderbook;
        /// Head price on bid orderbook, the highest bid price
        uint256 bidHead;
        /// Head price on ask orderbook, the lowest ask price
        uint256 askHead;
        /// Market price on pair
        uint256 lmp;
        /// Spread(volatility) limit on limit/market | long/short for market suspensions(e.g. circuit breaker, tick)
        uint32 spreadLimit;
        /// Make order id
        uint32 makeId;
        /// Whether an order deposit has been cleared
        bool clear;
    }

    struct PositionData {
        /// Position id
        uint32 id;
        /// Position entry price
        uint256 entryPrice;
        /// Position liquidation price
        uint256 liqPrice;
        /// Position deposit
        uint256 deposit;
        /// Position leverage
        uint32 leverage;
        /// Position owner
        address owner;
        /// Position is long
        bool isLong;
    }

    struct DefaultLeverage {
        /// Long spread limit
        uint32 long;
        /// Short spread limit
        uint32 short;
    }

    // Leverage limit setting
    mapping(address => DefaultLeverage) public leverageLimits;

    // Listing Info setting
    mapping(address => uint256) public listingDates;

    event PositionDeposit(address sender, address asset, uint256 fee);

    event PositionCanceled(
        address orderbook,
        uint256 id,
        bool isBid,
        address indexed owner,
        uint256 amount
    );

    event PositionOpened(
        address perpPool,
        uint256 mktPrice,
        PositionData position
    );

    event PositionClosed(
        address perpPool,
        uint256 mktPrice,
        PositionData position,
        uint256 received
    );

    event PositionUpdated(
        address perpPool,
        uint256 mktPrice,
        PositionData position
    );

    event PositionLiquidated(
        address perpPool,
        uint256 mktPrice,
        PositionData position,
        uint256 lost
    );

    event ListingCostSet(address payment, uint256 amount);

    event PoolAdded(
        address orderbook,
        TransferHelper.TokenInfo base,
        TransferHelper.TokenInfo quote,
        TransferHelper.TokenInfo collateral,
        uint256 listingDate
    );

    event PoolUpdated(
        address orderbook,
        address base,
        address quote,
        address collateral,
        uint256 listingDate
    );

    event PerpCreate2(address deployer, bytes bytecode);

    error EntryLongPriceHigherThanMktPrice(uint256 entry, uint256 mktPrice);
    error EntryShortPriceLowerthanMktPrice(uint256 entry, uint256 mktPrice);
    error LowDeposit(
        uint256 deposit,
        uint256 entry,
        uint32 leverage,
        uint256 minDeposit
    );

    error InvalidFeeRate(uint256 feeNum, uint256 feeDenom);
    error InvalidRole(bytes32 role, address sender);
    error InvalidPool(
        address base,
        address quote,
        address collateral,
        address pool
    );
    error PoolNotListedYet(
        address base,
        address quote,
        address collateral,
        uint256 listingDate,
        uint256 timeNow
    );
    error PoolDoesNotExist(
        address base,
        address quote,
        address collateral,
        address pool
    );
    error AmountIsZero();
    error FactoryNotInitialized(address factory);
    error AlreadyInitialized(bool init);

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MARKET_MAKER_ROLE, msg.sender);
    }

    /**
     * @dev Initialize the perpetual futures with perp pool factory and listing requirements.
     * It can be called only once.
     * @param perpPoolFactory_ address of isolated margin perp pool factory
     * @param feeTo_ address to receive fee
     * @param WETH_ address of wrapped ether contract
     *
     * Requirements:
     * - `msg.sender` must be the deployer of the contract.
     */
    function initialize(
        address perpPoolFactory_,
        address feeTo_,
        address WETH_
    ) external {
        if (init) {
            revert AlreadyInitialized(init);
        }
        perpPoolFactory = perpPoolFactory_;
        feeTo = feeTo_;
        WETH = WETH_;
        defaultLong = 200;
        defaultShort = 200;
        // get impl address of orderbook contract to predict address
        address impl = IPerpPoolFactory(perpPoolFactory_).impl();
        // Orderbook factory must be initialized first to locate pairs
        if (impl == address(0)) {
            revert FactoryNotInitialized(perpPoolFactory_);
        }
        bytes memory bytecode = IPerpPoolFactory(perpPoolFactory_)
            .getByteCode();
        init = true;
        emit PerpCreate2(perpPoolFactory, bytecode);
    }

    // admin functions
    function setFeeTo(address feeTo_) external returns (bool success) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        feeTo = feeTo_;
        return true;
    }

    /**
     * @dev Set the listing cost for a token. Each pair costs minimum 2GB of data storage in a month, costing 0.1 ETH.
     * @param payment address of payment token
     * @param amount amount of token
     *
     * Requirements:
     * - `msg.sender` must have the default admin role.
     */
    function setListingCost(
        address payment,
        uint256 amount
    ) external returns (uint256) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        IPerpPoolFactory(perpPoolFactory).setListingCost(payment, amount);
        emit ListingCostSet(payment, amount);
        return amount;
    }

    function setDefaultLeverage(
        uint32 long,
        uint32 short
    ) external returns (bool success) {
        if (!hasRole(MARKET_MAKER_ROLE, _msgSender())) {
            revert InvalidRole(MARKET_MAKER_ROLE, _msgSender());
        }
        defaultLong = long;
        defaultShort = short;
        return true;
    }

    function setLeverage(
        address base,
        address quote,
        address collateral,
        uint32 long,
        uint32 short
    ) external returns (bool success) {
        if (!hasRole(MARKET_MAKER_ROLE, _msgSender())) {
            revert InvalidRole(MARKET_MAKER_ROLE, _msgSender());
        }
        _setLeverage(base, quote, collateral, long, short);
        return true;
    }

    // user functions


    /**
     * @dev Creates an orderbook for a new trading pair and returns its address
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param collateral The address of the collateral asset for the trading pair
     * @param listingDate The listing Date for the trading pair
     * @return book The address of the newly created orderbook
     */
    function addPoolETH(
        address base,
        address quote,
        address collateral,
        uint256 listingDate
    ) external payable returns (address book) {
        IWETH(WETH).deposit{value: msg.value}();
        return addPool(base, quote, collateral, listingDate, WETH);
    }

    /**
     * @dev Creates an orderbook for a new trading pair and returns its address
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param collateral The address of the collateral asset for the trading pair
     * @param listingDate The listing Date for the trading pair
     * @param payment The address of the payment asset for the listing fee
     * @return pool The address of the newly created orderbook
     */
    function addPool(
        address base,
        address quote,
        address collateral,
        uint256 listingDate,
        address payment
    ) public returns (address pool) {
        _listingDeposit(payment, msg.sender);
        // create orderbook for the pair
        pool = IPerpPoolFactory(perpPoolFactory).createPerpPool(
            base,
            quote,
            collateral
        );
        // set long/short spread to default suspension rate in basis point(bps)
        _setLeverage(base, quote, collateral, defaultLong, defaultShort);
        _setListingDate(pool, listingDate);

        TransferHelper.TokenInfo memory baseInfo = TransferHelper.getTokenInfo(
            base
        );
        TransferHelper.TokenInfo memory quoteInfo = TransferHelper.getTokenInfo(
            quote
        );
        TransferHelper.TokenInfo memory collateralInfo = TransferHelper.getTokenInfo(collateral);
        emit PoolAdded(
            pool,
            baseInfo,
            quoteInfo,
            collateralInfo,
            listingDate
        );
        return pool;
    }

    /**
     * @dev Update the market price of a trading pair.`
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param collateral The address of the collateral asset for the trading pair
     * @param listingDate The listing Date for the trading pair
     */
    function updatePool(
        address base,
        address quote,
        address collateral,
        uint256 listingDate
    ) external returns (address pool) {
        // check if the list request is done by
        if (!hasRole(MARKET_MAKER_ROLE, _msgSender())) {
            revert InvalidRole(MARKET_MAKER_ROLE, _msgSender());
        }
        // create orderbook for the pair
        pool = getPool(base, quote, collateral);
        emit PoolUpdated(pool, base, quote, collateral, listingDate);
        return pool;
    }

    /**
     * @dev Cancels an order in an orderbook by the given order ID and order type.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param collateral The address of the collateral asset for the trading pair
     * @param isLong Boolean indicating if the order to cancel is an ask order
     * @param positionId The ID of the order to cancel
     * @return refunded Refunded amount from order
     */
    function closePosition(
        address base,
        address quote,
        address collateral,
        bool isLong,
        uint32 positionId
    ) public nonReentrant returns (uint256) {
        address pool = IPerpPoolFactory(perpPoolFactory).getPool(
            base,
            quote,
            collateral
        );

        if (pool == address(0)) {
            revert InvalidPool(base, quote, collateral, pool);
        }

        try
            IPerpPool(pool).closePosition(isLong, positionId, msg.sender)
        returns (uint256 refunded) {
            emit PositionCanceled(pool, positionId, isLong, msg.sender, refunded);
            return refunded;
        } catch {
            return 0;
        }
    }


    function closePositions(
        address[] memory base,
        address[] memory quote,
        address[] memory collateral,
        bool[] memory isLong,
        uint32[] memory positionIds
    ) external returns (uint256[] memory refunded) {
        refunded = new uint256[](positionIds.length);
        for (uint32 i = 0; i < positionIds.length; i++) {
            refunded[i] = closePosition(base[i], quote[i], collateral[i], isLong[i], positionIds[i]);
        }
        return refunded;
    }    

    /**
     * @dev Returns an order in the ask/bid orderbook for the given trading pair with order id.
     * @param base The address of the base asset for the futures pool.
     * @param quote The address of the quote asset for the futures pool.
     * @param collateral The address of the collateral asset for the futures pool.
     * @param isLong Boolean indicating if the orderbook to retrieve orders from is an ask orderbook.
     * @param positionId The order id to retrieve.
     */
    function getPosition(
        address base,
        address quote,
        address collateral,
        bool isLong,
        uint32 positionId
    ) public view returns (FuturesPool.Position memory) {
        address pool = getPool(base, quote, collateral);
        return IPerpPool(pool).getPosition(isLong, positionId);
    }

    /**
     * @dev Returns the address of the orderbook for the given base and quote asset addresses.
     * @param base The address of the base asset for the futures pool.
     * @param quote The address of the quote asset for the futures pool.
     * @return book The address of the orderbook.
     */
    function getPool(
        address base,
        address quote,
        address collateral
    ) public view returns (address book) {
        return IPerpPoolFactory(perpPoolFactory).getPool(base, quote, collateral);
    }

    function _setListingDate(
        address book,
        uint256 listingDate
    ) internal returns (bool success) {
        listingDates[book] = listingDate;
        return true;
    }

    function _setLeverage(
        address base,
        address quote,
        address collateral,
        uint32 long,
        uint32 short
    ) internal returns (bool success) {
        address pool = getPool(base, quote, collateral);
        leverageLimits[pool] = DefaultLeverage(long, short);
        return true;
    }

    function getLeverage(
        address pool,
        bool isLong
    ) public view returns (uint32 leverageLimit) {
        DefaultLeverage memory leverage;
        leverage = leverageLimits[pool];
        if (isLong) {
            return leverage.long;
        } else {
            return leverage.short;
        }
    }

    function _report(
        address orderbook,
        address give,
        bool isBid,
        uint256 matched,
        address owner
    ) internal {
        if (
            _isContract(feeTo) && IRevenue(feeTo).isReportable() && matched > 0
        ) {
            // report matched amount to accountant with give token on matching order
            IRevenue(feeTo).reportMatch(
                orderbook,
                give,
                isBid,
                msg.sender,
                owner,
                matched
            );
        }
    }

    /**
     * @dev Deposit amount of asset to the contract with the given asset information and subtracts the fee.
     * @param base The address of the base asset.
     * @param quote The address of the quote asset.
     * @param collateral The address of the collateral asset.
     * @param amount The amount of asset to deposit.
     * @param isLong Whether it is an ask order or not.
     * If ask, the quote asset is transferred to the contract.
     * @return withoutFee The amount of asset without the fee.
     * @return pool The address of the orderbook for the given asset pair.
     */
    function _deposit(
        address base,
        address quote,
        address collateral,
        uint256 amount,
        bool isLong
    ) internal returns (uint256 withoutFee, address pool) {
        // check if amount is zero
        if (amount == 0) {
            revert AmountIsZero();
        }
        // get orderbook address from the base and quote asset
        pool = getPool(base, quote, collateral);
        // check infalid pair

        if (pool == address(0)) {
            revert InvalidPool(base, quote, collateral, pool);
        }
        // check if the pair is listed
        if (listingDates[pool] > block.timestamp) {
            revert PoolNotListedYet(
                base,
                quote,
                collateral,
                listingDates[pool],
                block.timestamp
            );
        }

        // check if amount is valid in case of both long and short
        
        // check sender's fee
        
        emit PositionDeposit(msg.sender, isLong ? quote : base, 0);

        return (withoutFee, pool);
    }

    /**
     * @dev Deposit amount of asset to the contract with the given asset information and subtracts the fee.
     * @param payment The address of the payment asset.
     * @param sender The address of the sender.
     */
    function _listingDeposit(address payment, address sender) internal {
        // check if the sender is admin
        if (hasRole(MARKET_MAKER_ROLE, sender)) {
            return;
        }
        uint256 amount = IPerpPoolFactory(perpPoolFactory).getListingCost(
            payment
        );
        // check if amount is zero
        if (amount == 0) {
            revert AmountIsZero();
        }
        if (payment != WETH) {
            TransferHelper.safeTransferFrom(
                payment,
                msg.sender,
                address(this),
                amount
            );
        }
        TransferHelper.safeTransfer(payment, feeTo, amount);
    }

    function _fee(
        uint256 amount,
        address account,
        bool isMaker
    ) internal view returns (uint256 fee) {
        if (_isContract(feeTo) && IRevenue(feeTo).isSubscribed(account)) {
            uint32 feeNum = IRevenue(feeTo).feeOf(account, isMaker);
            return (amount * feeNum) / feeDenom;
        }
        return (amount * 3) / 1000;
    }

    function _isContract(address addr) internal view returns (bool isContract) {
        uint size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}
