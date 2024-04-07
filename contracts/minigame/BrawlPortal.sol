pragma solidity ^0.8.17;

import {ITimeBrawl, ITimeBrawlFactory} from "./interfaces/ITimeBrawlFactory.sol";
import {TransferHelper} from "./libraries/TransferHelper.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IEngine {
    function mktPrice(address base, address quote) external returns (uint256);
}

contract BrawlPortal is AccessControl, Initializable {
    address public engine;
    uint32 brawlId;
    address public factory;
    address private feeTo;

    error InvalidRole(bytes32 role, address sender);
    error NotBet(uint256 id, address submitted, address bet);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        feeTo = msg.sender;
    }

    function setFeeTo(address feeTo_) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        feeTo = feeTo_;
    }

    function initialize(
        address engine_,
        address factory_
    ) external initializer {
        engine = engine_;
        factory = factory_;
    }

    function create(
        address base,
        address quote,
        address bet,
        uint256 duration
    ) external returns (address brawl) {
        uint256 startPrice = IEngine(engine).mktPrice(base, quote);
        return
            ITimeBrawlFactory(factory).createBrawl(
                base,
                quote,
                startPrice,
                bet,
                block.timestamp + duration
            );
    }

    function long(
        address base,
        address quote,
        uint256 id,
        address bet,
        uint256 amount
    ) external {
        (address brawl, uint256 withoutFee) = _deposit(
            base,
            quote,
            id,
            bet,
            amount
        );
        TransferHelper.safeTransfer(bet, brawl, withoutFee);
        ITimeBrawl(brawl).long(msg.sender, amount);
    }

    function short(
        address base,
        address quote,
        uint32 id,
        address bet,
        uint256 amount
    ) external {
        (address brawl, uint256 withoutFee) = _deposit(
            base,
            quote,
            id,
            bet,
            amount
        );
        TransferHelper.safeTransfer(bet, brawl, withoutFee);
        ITimeBrawl(brawl).short(msg.sender, amount);
    }

    function flat(
        address base,
        address quote,
        uint256 id,
        address bet,
        uint256 amount
    ) external {
        (address brawl, uint256 withoutFee) = _deposit(
            base,
            quote,
            id,
            bet,
            amount
        );
        TransferHelper.safeTransfer(bet, brawl, withoutFee);
        ITimeBrawl(brawl).flat(msg.sender, amount);
    }

    function exit(address base, address quote, uint256 id) external {
        address brawl = getBrawl(base, quote, id);
        uint256 endPrice = IEngine(engine).mktPrice(base, quote);
        ITimeBrawl(brawl).exit(endPrice);
    }

    function claim(address base, address quote, uint256 id) external {
        address brawl = getBrawl(base, quote, id);
        ITimeBrawl(brawl).claim(msg.sender);
    }

    function getBrawl(
        address base,
        address quote,
        uint256 id
    ) public view returns (address brawl) {
        return ITimeBrawlFactory(factory).getBrawl(base, quote, id);
    }

    function getBrawlInfo(
        address base,
        address quote,
        uint256 id
    ) external view returns (ITimeBrawl.Brawl memory brawl) {
        return ITimeBrawlFactory(factory).getBrawlInfo(base, quote, id);
    }

    function _deposit(
        address base,
        address quote,
        uint256 id,
        address bet,
        uint256 amount
    ) internal returns (address brawl, uint256 withoutFee) {
        brawl = getBrawl(base, quote, id);
        // check if brawl's bet is the sent bet
        address accepted = ITimeBrawl(brawl).bet();
        if (accepted != bet) {
            revert NotBet(id, bet, accepted);
        }
        TransferHelper.safeTransferFrom(bet, msg.sender, address(this), amount);
        TransferHelper.safeTransfer(bet, feeTo, amount / 100);

        return (brawl, (amount * 99) / 100);
    }
}
