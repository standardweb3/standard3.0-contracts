
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol"; 

contract Sekai is ERC20Burnable {
    constructor() ERC20("SEKAI", "SEKAI") {
        _mint(msg.sender, 561_300_000_000 * 1e18);
    }
}