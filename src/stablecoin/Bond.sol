// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "./interfaces/IERC20Minimal.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IBond.sol";
import "./interfaces/INetworkState.sol";
import "./interfaces/IERC721Minimal.sol";
import "./interfaces/ICoupon.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IMatchingEngine.sol";
import "./interfaces/ISAFU.sol";

contract Bond {
    /// Address of the state
    address public state;
    /// Address of debt;
    address public debt;
    /// Address of vault ownership registry
    address public coupon;
    /// Address of a collateral
    address public collateral;
    /// Bond global identifier
    uint128 public id;
    /// Borrowed amount
    uint256 public borrow;
    /// Created block timestamp
    uint256 public createdAt;

    constructor() public {
        state = msg.sender;
        createdAt = block.timestamp;
    }

    error NotBondOwner(address caller, address owner);
    error InvalidAccess(address caller, address gov);

    modifier onlyBondOwner() {
        address owner = IERC721Minimal(coupon).ownerOf(id);
        if (owner != msg.sender) {
            revert NotBondOwner(msg.sender, owner);
        }
        _;
    }

    modifier onlyState() {
        if (state != msg.sender) {
            revert InvalidAccess(msg.sender, state);
        }
        _;
    }

    // called once by the factory at time of deployment
    function initialize(uint128 vaultId_, address collateral_, address debt_, address coupon_, uint256 amount_)
        external
        onlyState
    {
        id = vaultId_;
        collateral = collateral_;
        debt = debt_;
        coupon = coupon_;
        borrow = amount_;
    }

    /// liquidate
    function liquidate() external {
        require(
            !INetworkState(state).isValidCDP(
                collateral,
                debt,
                IERC20Minimal(collateral).balanceOf(address(this)),
                IERC20Minimal(debt).balanceOf(address(this))
            ),
            "Vault: Position is still safe"
        );
        // check the pair if it exists
        address market = INetworkState(state).market();
        address pair = IMatchingEngine(market).getPair(collateral, debt);
        require(pair != address(0), "Vault: Liquidating pair not supported");
        uint256 balance = IERC20Minimal(collateral).balanceOf(address(this));
        uint256 lfr = INetworkState(state).getLFR(collateral);
        uint256 liquidationFee = (lfr * balance) / 100;
        uint256 left = _sendFee(collateral, balance, liquidationFee);
        // Distribute collaterals
        IMatchingEngine(market).marketSell(collateral, debt, left, true, 10, address(this));
        // burn vault nft
        _burnV1FromVault();
        //emit Liquidated(address(this), collateral, balance);
        // self destruct the contract, send remaining balance if collateral is native currency
        selfdestruct(payable(msg.sender));
    }

    /// Deposit collateral
    function depositCollateral(uint256 amount_) external onlyBondOwner {
        TransferHelper.safeTransferFrom(collateral, msg.sender, address(this), amount_);
    }

    /// Withdraw collateral
    function withdrawCollateral(uint256 amount_) external onlyBondOwner {
        require(IERC20Minimal(collateral).balanceOf(address(this)) >= amount_, "Vault: Not enough collateral");
        if (borrow != 0) {
            require(
                INetworkState(state).isValidCDP(
                    collateral, debt, IERC20Minimal(collateral).balanceOf(address(this)) - amount_, borrow
                ),
                "Vault: below MCR"
            );
        }
        TransferHelper.safeTransfer(collateral, msg.sender, amount_);
    }

    /// Payback debt
    function payDebt(uint256 amount_) external onlyBondOwner {
        // calculate debt with interest
        uint256 fee = _calculateFee();
        require(amount_ != 0, "Vault: amount is zero");
        // send M1 to the vault
        TransferHelper.safeTransferFrom(debt, msg.sender, address(this), amount_);
        uint256 left = _sendFee(debt, amount_, fee);
        _burnM1FromVault(left);
        borrow -= left;
        //emit PayBack(vaultId, borrow, fee);
    }

    /// Close CDP
    function redeemBond(uint256 amount_) external onlyBondOwner {
        // calculate debt with interest
        uint256 fee = _calculateFee();
        require(fee + borrow == amount_, "Vault: not enough balance to payback");
        // send M1 to the vault
        TransferHelper.safeTransferFrom(debt, msg.sender, address(this), amount_);
        // send fee to the pool
        uint256 left = _sendFee(debt, amount_, fee);
        // burn M1 debt with interest
        _burnM1FromVault(left);
        // burn vault nft
        _burnV1FromVault();
        //emit CloseVault(address(this), amount_, fee);
        // self destruct the contract, send remaining balance if collateral is native currency
        selfdestruct(payable(msg.sender));
    }

    /// get amount left to borrow
    function getMargin(uint256 mcr) external view returns (uint256 available) {
        return ((IERC20Minimal(collateral).balanceOf(address(this)) / mcr) * 100000) - borrow;
    }

    /// burn vault v1
    function _burnV1FromVault() internal {
        ICoupon(coupon).burnFromVault(id);
    }

    /// burn vault M1
    function _burnM1FromVault(uint256 amount_) internal {
        ISAFU(debt).burnFrom(msg.sender, amount_);
    }

    function _calculateFee() internal returns (uint256) {
        uint256 assetValue = INetworkState(state).getAssetValue(debt, borrow);
        uint256 sfr = INetworkState(state).getSFR(collateral);
        /// (sfr * assetValue/100) * (duration in months)
        uint256 sfrTimesV = sfr * assetValue;
        // get duration in months
        uint256 duration = (block.timestamp - createdAt) / 60 / 60 / 24 / 30;
        require(sfrTimesV >= assetValue); // overflow check
        return (sfrTimesV / 100) * duration;
    }

    function getDebt() external returns (uint256) {
        return _calculateFee() + borrow;
    }

    function _sendFee(address asset_, uint256 amount_, uint256 fee_) internal returns (uint256 left) {
        address dividend = INetworkState(state).dividend();
        address feeTo = INetworkState(state).feeTo();
        address treasury = INetworkState(state).treasury();
        bool feeOn = feeTo != address(0);
        bool treasuryOn = treasury != address(0);
        bool dividendOn = dividend != address(0);
        // send fee to the pool
        if (feeOn) {
            if (dividendOn) {
                uint256 half = fee_ / 2;
                TransferHelper.safeTransfer(asset_, dividend, half);
                TransferHelper.safeTransfer(asset_, feeTo, half);
            } else if (dividendOn && treasuryOn) {
                uint256 third = fee_ / 3;
                TransferHelper.safeTransfer(asset_, dividend, third);
                TransferHelper.safeTransfer(asset_, feeTo, third);
                TransferHelper.safeTransfer(asset_, treasury, third);
            } else {
                TransferHelper.safeTransfer(asset_, feeTo, fee_);
            }
        }
        return amount_ - fee_;
    }
}
