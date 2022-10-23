// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../interfaces/IWETH.sol";
import "../interfaces/IOrderbook.sol";
import "../interfaces/IERC20.sol";
import "../libraries/Initializable.sol";
import "../interfaces/IOrder.sol";

error DepositIsNotWETH();

// Escrow account for orders
contract Order is Initializable, IOrder {
    // Owner of the order
    address public owner;
    // Address of the orderbook
    address public orderbook;
    // Address of wrapped ETH
    address public WETH;

    // Order details
    uint256 public pairId;
    // Order type: true = buy, false = sell
    bool public isAsk;
    // Price in 8 decimal(i.e. conversion ratio), Price is always set to <Bid>/<ASK>, <Base>/<Quote>
    uint256 public price;
    // Address of the deposit asset
    address public deposit;
    // Initial deposit from the owner for the order
    uint256 public depositAmount;
    // Amount of deposit that has been filled with the order
    uint256 public filled;

    modifier onlyOrderBook() {
        require(
            msg.sender == orderbook,
            "Only order book can call this function"
        );
        _;
    }

    function initialize(
        uint256 pairId_,
        address owner_,
        address orderbook_,
        address WETH_,
        bool isAsk_,
        uint256 price_,
        address deposit_,
        uint256 depositAmount_
    ) public initializer {
        pairId = pairId_;
        owner = owner_;
        orderbook = orderbook_;
        WETH = WETH_;
        isAsk = isAsk_;
        price = price_;
        deposit = deposit_;
        depositAmount = depositAmount_;
    }

    function _absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a > b) ? (a - b) : (b - a);
    }

    // Get pair info
    // unlock deposit when order router has enough asset to trade with the deposit
    function execute(address sender, uint256 amount) public onlyOrderBook {
        // get pair info and decimals for each asset
        (
            string memory _pairName,
            uint256 _mktPrice,
            address base,
            address quote
        ) = IOrderbook(orderbook).pairInfo();
        // if the order is ask order on the base/quote pair
        if (isAsk) {
            // owner is buyer, and sender is seller. if buyer is asking for base asset with quote asset in deposit
            // then the converted amount is <base>/<quote> == (baseAmount * 10^qDecimal) / (quoteAmount * 10^bDecimal)
            // verify whether the claim is correct with converted value from the ratio with error allowance of 0.01%
            require(
                verifyRatio(
                    base,
                    deposit,
                    IERC20(base).balanceOf(address(this)),
                    amount
                ),
                "Price is not correct"
            );
            // send deposit as quote asset to seller
            IERC20(deposit).transfer(sender, amount);
            // send claimed amount of base asset to buyer
            IERC20(base).transfer(owner, amount);
        }
        // if the order is bid order on the base/quote pair
        else {
            // owner is seller, and sender is buyer. buyer is asking for quote asset with base asset in deposit
            // then the converted amount is <base>/<quote> == depositAmount / claimAmount => claimAmount == depositAmount / price
            // verify whether the claim is correct with converted value from the ratio with error allowance of 0.01%
            require(
                verifyRatio(
                    deposit,
                    quote,
                    amount,
                    IERC20(quote).balanceOf(address(this))
                ),
                "Price is not correct"
            );
            // send deposit as base asset to buyer
            IERC20(deposit).transfer(owner, amount);
            // send claimed amount of quote asset to seller
            IERC20(quote).transfer(sender, amount);
        }
        if (depositAmount < amount) {
            selfdestruct(payable(sender));
        } else {
            // update deposit amount
            depositAmount = depositAmount - amount;
            // update filled amount
            filled = filled + amount;
        }
    }

    // claimAmount: amount of base asset to claim on ask order, amount of quote asset to claim on bid order
    function verifyRatio(
        address base,
        address quote,
        uint256 baseAmount,
        uint256 quoteAmount
    ) public view returns (bool success) {
        // get pair info and decimals for each asset
        uint256 bDecimal = IERC20(base).decimals();
        uint256 qDecimal = IERC20(quote).decimals();
        uint256 claimedPrice = ((baseAmount * (10**qDecimal)) * 1e8) /
            (quoteAmount * (10**bDecimal));
        // verify whether the claim is correct with converted value from the ratio with error allowance of 0.01%
        return _absDiff(price, claimedPrice) >= price / 1e6;
    }

    function cancelNative() public onlyOrderBook {
        if (deposit != WETH) {
            revert DepositIsNotWETH();
        }
        // send remaining deposit to owner
        uint256 remaining = depositAmount - filled;
        IWETH(WETH).withdraw(remaining);
        payable(owner).transfer(remaining);
    }
}
