pragma solidity ^0.8.24;
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {NetworkStateLibrary} from "./libraries/NetworkStateLibrary.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {TransferHelper} from "./libraries/TransferHelper.sol";
import {IERC721Minimal} from "./interfaces/IERC721Minimal.sol";
import {IBond} from "./interfaces/IBond.sol";
import {IERC20Minimal} from "./interfaces/IERC20Minimal.sol";

contract NetworkState is Initializable {
    using NetworkStateLibrary for NetworkStateLibrary.State;
    using NetworkStateLibrary for NetworkStateLibrary.CDP;

    NetworkStateLibrary.State private state;

    // CDP set events
    event CDPSet(
        address indexed collateral,
        uint32 mcr,
        uint32 rfr,
        uint32 lfr
    );

    // Bond state events
    event BondCreated(
        uint128 indexed id,
        address indexed collateral,
        uint256 cAmount,
        uint256 dAmount
    );

    event BondRedeemed(uint128 indexed id, uint256 indexed dAmount);

    event BondLiquidated(
        uint128 indexed id,
        address indexed collateral,
        uint256 cAmount,
        uint256 dAmount
    );

    // Bond CDP state events
    event DepositCollateral(uint128 id, uint256 amount);
    event WithdrawCollateral(uint128 id, uint256 amount);
    event BorrowMore(uint128 id, uint256 amount);
    event PayBackDebt(uint128 id, uint256 amount);

    // Bond errors
    error NotBondOwner(address caller, address owner);
    error InvalidAccess(address caller, address gov);

    function initialize(
        address coupon_,
        address currency_,
        address market_,
        address weth_
    ) external initializer {
        state._initialize(coupon_, currency_, market_, weth_);
    }

    function setCDP(
        address collateral_,
        uint32 mcr_,
        uint32 rfr_,
        uint32 lfr_
    ) external {
        state._setCDP(collateral_, mcr_, rfr_, lfr_);
    }

    function getCDP(
        address collateral_
    ) external view returns (NetworkStateLibrary.CDP memory cdp) {
        return state._getCDP(collateral_);
    }

    function borrow(
        address collateral_,
        uint cAmount_,
        uint dAmount_,
        uint128 id_
    ) external returns (address bond) {
        if (id_ == 0) {
            // create bond
            bond = state._createBond(collateral_, cAmount_, dAmount_);
            IERC20Minimal(state.currency).mint(msg.sender, dAmount_);
        } else {
            // borrow more from existing bond
            bond = state._predictAddress(collateral_, state.currency, id_);
            // TODO: get margin from bond and check if it exceeeds the amount
        }
    }

    function createBondETH(
        uint dAmount_
    ) public payable returns (address bond) {
        IWETH(state.weth).deposit{value: msg.value}();
        return state._createBond(state.weth, msg.value, dAmount_);
    }

    function isValidCDP(
        address collateral_,
        address debt_,
        uint256 cAmount_,
        uint256 dAmount_
    ) external view returns (bool) {
        return state._isValidCDP(collateral_, debt_, cAmount_, dAmount_);
    }

    function _takeFee(uint256 amount) internal {
        // state._takeFee();
    }

    modifier onlyBondOwner(uint256 id) {
        address owner = IERC721Minimal(state.coupon).ownerOf(id);
        if (owner != msg.sender) {
            revert NotBondOwner(msg.sender, owner);
        }
        _;
    }

    function depositCollateral(
        uint128 id,
        address collateral,
        uint256 amount
    ) public onlyBondOwner(id) returns (bool success) {
        address bond = state._predictAddress(collateral, state.currency, id);
        TransferHelper.safeTransferFrom(
            collateral,
            msg.sender,
            address(this),
            amount
        );
        TransferHelper.safeTransfer(collateral, bond, amount);
        //return state._depositCollateral(id, amount);
    }

    function depositCollateralETH(
        uint128 id,
        address collateral,
        uint256 amount
    ) external payable onlyBondOwner(id) returns (bool success) {
        address bond = state._predictAddress(collateral, state.currency, id);
        IWETH(state.weth).deposit{value: msg.value}();
        TransferHelper.safeTransfer(collateral, bond, amount);
    }

    function withdrawCollateral(
        uint128 id,
        address collateral,
        uint256 amount
    ) external onlyBondOwner(id) returns (bool success) {
        address bond = state._predictAddress(collateral, state.currency, id);
        IBond(bond).withdrawCollateral(amount);
        TransferHelper.safeTransfer(collateral, msg.sender, amount);
    }

    function borrowMore(
        uint128 id,
        address collateral,
        uint256 amount
    ) external onlyBondOwner(id) returns (bool success) {
        address bond = state._predictAddress(collateral, state.currency, id);
        return state._borrowMore(id, collateral, amount);
    }

    function payBackDebt(
        uint128 id,
        address collateral,
        uint256 amount
    ) external onlyBondOwner(id) returns (bool success) {
        address bond = state._predictAddress(collateral, state.currency, id);
        //return state._payBackDebt(bond, id, amount);
    }

    function liquidate(
        address collateral_,
        address debt_,
        uint128 id
    ) external onlyBondOwner(id) returns (bool success) {
        address bond = state._predictAddress(collateral_, state.currency, id);
        //return state._liquidate(collateral_, debt_, id);
    }

    function market() external view returns (address) {
        return state.market;
    }
}
