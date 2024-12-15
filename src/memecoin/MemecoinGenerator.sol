/// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TransferHelper} from "../exchange/libraries/TransferHelper.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IMatchingEngine} from "../exchange/interfaces/IMatchingEngine.sol";

contract Memecoin is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, totalSupply);
    }
}

contract MemecoinGenerator is AccessControl {
    uint256 private fee;
    address private feeTo;
    address public matchingEngine;
    address public WETH;
    address public stablecoin;

    function setFeeTo(address _feeTo) public {
        feeTo = _feeTo;
    }

    function setFee(uint256 _fee) public {
        fee = _fee;
    }

    function createMemecoin(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public returns (Memecoin) {
        Memecoin memecoin = new Memecoin(name, symbol, initialSupply);
        return memecoin;
    }

    function launch(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public payable {
        require(feeTo != address(0), "FeeTo address not set");
        require(fee > 0, "Fee not set");
        require(msg.value >= fee, "Insufficient fee");

        Memecoin memecoin = createMemecoin(name, symbol, initialSupply);
        payable(feeTo).transfer(fee);

        uint256 ETHBidAmount = msg.value - fee;

        uint256 ETHBidStablecoinAmount = IMatchingEngine(matchingEngine).convert(WETH, stablecoin, ETHBidAmount, false);


        // calculate initial price in USDT
        uint256 initialMarketcap = 69420 * TransferHelper.decimals(stablecoin);

        if (ETHBidStablecoinAmount >= initialMarketcap) {
            // transfer all supply to msg.sender except fee amount
            memecoin.transfer(msg.sender, initialSupply);
            // set price to 0.01 to start with
        } else {
            // add pair to Standard
            IMatchingEngine(matchingEngine).addPair(address(memecoin), WETH, 1, 0, address(memecoin));
        }

        // add pair to Standard
        IMatchingEngine(matchingEngine).addPair(address(memecoin), WETH, 1,0, address(memecoin));
    }
}
