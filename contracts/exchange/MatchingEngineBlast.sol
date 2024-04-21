// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;
import {MatchingEngine} from "./MatchingEngine.sol";

enum YieldMode {
    AUTOMATIC,
    VOID,
    CLAIMABLE
}

enum GasMode {
    VOID,
    CLAIMABLE 
}

interface IERC20Rebasing {
  // changes the yield mode of the caller and update the balance
  // to reflect the configuration
  function configure(YieldMode) external returns (uint256);
  // "claimable" yield mode accounts can call this this claim their yield
  // to another address
  function claim(address recipient, uint256 amount) external returns (uint256);
  // read the claimable amount for an account
  function getClaimableAmount(address account) external view returns (uint256);
}

interface IBlast{
    // configure
    function configureContract(address contractAddress, YieldMode _yield, GasMode gasMode, address governor) external;
    function configure(YieldMode _yield, GasMode gasMode, address governor) external;

    // base configuration options
    function configureClaimableYield() external;
    function configureClaimableYieldOnBehalf(address contractAddress) external;
    function configureAutomaticYield() external;
    function configureAutomaticYieldOnBehalf(address contractAddress) external;
    function configureVoidYield() external;
    function configureVoidYieldOnBehalf(address contractAddress) external;
    function configureClaimableGas() external;
    function configureClaimableGasOnBehalf(address contractAddress) external;
    function configureVoidGas() external;
    function configureVoidGasOnBehalf(address contractAddress) external;
    function configureGovernor(address _governor) external;
    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external;

    // claim yield
    function claimYield(address contractAddress, address recipientOfYield, uint256 amount) external returns (uint256);
    function claimAllYield(address contractAddress, address recipientOfYield) external returns (uint256);

    // claim gas
    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint256);
    function claimGasAtMinClaimRate(address contractAddress, address recipientOfGas, uint256 minClaimRateBips) external returns (uint256);
    function claimMaxGas(address contractAddress, address recipientOfGas) external returns (uint256);
    function claimGas(address contractAddress, address recipientOfGas, uint256 gasToClaim, uint256 gasSecondsToConsume) external returns (uint256);

    // read functions
    function readClaimableYield(address contractAddress) external view returns (uint256);
    function readYieldConfiguration(address contractAddress) external view returns (uint8);
    function readGasParams(address contractAddress) external view returns (uint256 etherSeconds, uint256 etherBalance, uint256 lastUpdated, GasMode);
}

interface IBlastPoints {
	function configurePointsOperator(address operator) external;
}

interface IRevenue {
    function report(
        uint32 uid,
        address token,
        uint256 amount,
        bool isAdd
    ) external;

    function isReportable(
        address token,
        uint32 uid
    ) external view returns (bool);

    function refundFee(address to, address token, uint256 amount) external;

    function feeOf(uint32 uid, bool isMaker) external returns (uint32 feeNum);
}

interface IDecimals {
    function decimals() external view returns (uint8 decimals);
}

// Onchain Matching engine for the orders
contract MatchingEngineBlast is MatchingEngine {
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    // NOTE: these addresses differ on the Blast mainnet and testnet; the lines below are the mainnet addresses
    IERC20Rebasing public constant USDB = IERC20Rebasing(0x4300000000000000000000000000000000000003);
    IERC20Rebasing public constant WETHBLAST = IERC20Rebasing(0x4300000000000000000000000000000000000004);
    error InvalidAccess(address sender, address owner);

   
  
    constructor() {
        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800).configurePointsOperator(0x34CCCa03631830cD8296c172bf3c31e126814ce9);
        BLAST.configureClaimableGas(); 
        USDB.configure(YieldMode.AUTOMATIC); //configure claimable yield for USDB
        WETHBLAST.configure(YieldMode.AUTOMATIC); //configure claimable yield for WETH
        //IBlast(0x4300000000000000000000000000000000000002).configureVoidYield();
    }

    function configureVoidYield() external {
        if (msg.sender != 0x34CCCa03631830cD8296c172bf3c31e126814ce9)  {
            revert InvalidAccess(msg.sender, 0x34CCCa03631830cD8296c172bf3c31e126814ce9);
        }
        IBlast(0x4300000000000000000000000000000000000002).configureVoidYield();
    }

    function configureAutomaticYield() external {
        if (msg.sender != 0x34CCCa03631830cD8296c172bf3c31e126814ce9)   {
            revert InvalidAccess(msg.sender, 0x34CCCa03631830cD8296c172bf3c31e126814ce9);
        }
        IBlast(0x4300000000000000000000000000000000000002).configureAutomaticYield();
    }

    function configureClaimableYield() external  {
        if (msg.sender != 0x34CCCa03631830cD8296c172bf3c31e126814ce9) {
            revert InvalidAccess(msg.sender, 0x34CCCa03631830cD8296c172bf3c31e126814ce9);
        }
        IBlast(0x4300000000000000000000000000000000000002).configureClaimableYield();
    }

    function claimMyContractsGas() external {
        if (msg.sender != 0x34CCCa03631830cD8296c172bf3c31e126814ce9) {
            revert InvalidAccess(msg.sender, 0x34CCCa03631830cD8296c172bf3c31e126814ce9);
        }
        BLAST.claimAllGas(address(this), msg.sender);
    }
}
