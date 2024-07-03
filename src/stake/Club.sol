import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Club is ERC4626 {
    address payable public vaultOwner;
    uint256 entryFeeBasisPoints;

    constructor(IERC20 _asset) ERC4626(_asset) ERC20("Standard Club", "cSTNDXP") {
        vaultOwner = payable(msg.sender);
    }
}