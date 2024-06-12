pragma solidity ^0.8.24;

import "./CloneFactory.sol";
import "../interfaces/IBond.sol";
import "../interfaces/IEngine.sol";
import "@openzeppelin/src/token/ERC20/IERC20.sol";

library NetworkStateLibrary {
    struct CDP {
        uint32 mcr;
        uint32 rfr;
        uint32 lfr;
        uint8 decimals;
    }

    struct State {
        /// Desirable supply of stablecoin
        uint256 supply;
        // Vaults
        uint128 count;
        /// key: Collateral address, value: CDP in a struct
        mapping(address => CDP) cdps;
        /// Address of coupon NFT
        address coupon;
        /// Address of admin
        address gov;
        /// Address of currency
        address currency;
        /// Address of market;
        address market;
        /// Address of Standard Treasury
        address treasury;
        /// Address of liquidator
        address liquidator;
        /// Address of Wrapped eth;
        address weth;
        /// Address of Bond impl contract
        address impl;
    }

    error InvalidAccess(address caller, address gov);
    error BondAlreadyExists(address collateral, address currency, uint128 id);
    error MktPriceIsZero(address base, address quote);
    error ValueOverflow(uint256 price, uint256 amount);
    error InvalidCDP(
        address collateral,
        address debt,
        uint256 cAmount,
        uint256 dAmount
    );
    error SupplyLimitExceeded(uint256 supply, uint256 issued, uint256 issueAmount);

    function _initialize(
        State storage self,
        address coupon_,
        address currency_,
        address market_,
        address weth_
    ) public {
        if (msg.sender != self.gov) revert InvalidAccess(msg.sender, self.gov);
        self.weth = weth_;
        self.market = market_;
        self.currency = currency_;
        self.coupon = coupon_;
    }

    function _setCDP(
        State storage self,
        address collateral,
        uint32 mcr,
        uint32 rfr,
        uint32 lfr
    ) public returns (bool success) {
        if (msg.sender != self.gov) revert InvalidAccess(msg.sender, self.gov);
        if (mcr > 0) {
            self.cdps[collateral].mcr = mcr;
        }
        if (rfr > 0) {
            self.cdps[collateral].rfr = rfr;
        }
        if (lfr > 0) {
            self.cdps[collateral].lfr = lfr;
        }
        return true;
    }

    function _setSupply(
        State storage self,
        uint256 supply
    ) public returns (bool success) {
        if (msg.sender != self.gov) revert InvalidAccess(msg.sender, self.gov);
        self.supply = supply;
        return true;
    }

    function _getCDP(
        State storage self,
        address collateral
    ) public view returns (CDP memory) {
        return self.cdps[collateral];
    }

    function allBondsLength(State storage self) public view returns (uint) {
        return self.count;
    }

    function _createBond(
        State storage self,
        address collateral,
        uint256 cAmount,
        uint256 dAmount
    ) public returns (address bond) {
        // get id
        uint128 id = self.count;
        uint256 issued = IERC20(self.currency).totalSupply();

        // confirm the CDP is valid
        if (!_isValidCDP(self, collateral, self.currency, cAmount, dAmount)) {
            revert InvalidCDP(collateral, self.currency, cAmount, dAmount);
        }

        if (!isValidSupply(self, issued, dAmount)) {
            revert SupplyLimitExceeded(self.supply, issued, dAmount);
        }

        bond = _predictAddress(self, collateral, self.currency, id);

        // Check if the address has code
        uint32 size;
        assembly {
            size := extcodesize(bond)
        }

        // If the address has code and it's a clone of impl, revert.
        if (size > 0 || CloneFactory._isClone(self.impl, bond)) {
            revert BondAlreadyExists(collateral, self.currency, id);
        }

        address proxy = CloneFactory._createCloneWithSalt(
            self.impl,
            _getSalt(collateral, self.currency, id)
        );

        IBond(proxy).initialize(id, collateral, self.currency, self.market);

        self.count += 1;

        return (proxy);
    }

    function _liquidate(
        State storage self,
        address collateral_,
        address debt_,
        uint128 id_
    ) public returns (bool) {
        // TODO: modify liquidator validation
        if (msg.sender != self.liquidator) revert InvalidAccess(msg.sender, self.liquidator);
        address bond = _predictAddress(self, collateral_, debt_, id_);
        IBond(bond).liquidate();
        return true;
    }

    function _borrowMore(
        State storage self,
        uint128 id_,
        address collateral_, 
        uint256 amount_
    ) public view returns (bool) {
        address bond = _predictAddress(self, collateral_, self.currency, id_);
        //IBond(bond).borrowMore();
    }

    function _predictAddress(
        State storage self,
        address collateral_,
        address debt_,
        uint128 id_
    ) public view returns (address) {
        bytes32 salt = _getSalt(collateral_, debt_, id_);
        return
            CloneFactory.predictAddressWithSalt(address(this), self.impl, salt);
    }

    function isValidSupply(
        State storage self,
        uint256 issued_,
        uint256 issueAmount_
    ) public view returns (bool) {
        return
            issued_ + issueAmount_ - IERC20(self.currency).balanceOf(self.liquidator) <=
            self.supply;
    }

    function _isValidCDP(
        State storage self,
        address collateral_,
        address debt_,
        uint256 cAmount_,
        uint256 dAmount_
    ) public view returns (bool) {
        (uint256 collateralValueTimes100, uint256 debtValue) = _calculateValues(
            self,
            collateral_,
            debt_,
            cAmount_,
            dAmount_
        );

        uint mcr = self.cdps[collateral_].mcr;
        uint cDecimals = self.cdps[collateral_].decimals;

        uint256 debtValueAdjusted = debtValue / (10 ** cDecimals);

        // if the debt become obsolete
        return
            debtValueAdjusted == 0
                ? true
                : collateralValueTimes100 / debtValueAdjusted >= mcr;
    }

    function _calculateValues(
        State storage self,
        address collateral_,
        address debt_,
        uint256 cAmount_,
        uint256 dAmount_
    ) public view returns (uint256, uint256) {
        uint256 collateralValue = getAssetValue(self, collateral_, cAmount_);
        uint256 debtValue = getAssetValue(self, debt_, dAmount_);
        uint256 collateralValueTimes100 = collateralValue * 100;
        require(collateralValueTimes100 >= collateralValue); // overflow check
        return (collateralValueTimes100, debtValue);
    }

    function _getAssetPrice(
        State storage self,
        address asset_
    ) public view returns (uint) {
        uint price = IEngine(self.market).mktPrice(asset_, self.currency);
        if (price == 0) {
            revert MktPriceIsZero(asset_, self.currency);
        }
        return price;
    }

    function getAssetValue(
        State storage self,
        address asset_,
        uint256 amount_
    ) public view returns (uint256) {
        uint price = _getAssetPrice(self, asset_);
        uint256 value = price * amount_;
        if (value < amount_) {
            revert ValueOverflow(price, amount_);
        }
        return value;
    }

    function _getSalt(
        address collateral_,
        address debt_,
        uint128 id_
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(collateral_, debt_, id_));
    }
}
