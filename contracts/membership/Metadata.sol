import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @author Hyungsuk Kang <hskang9@github.com>
/// @title Metadata contract for SABT
contract Metadata is AccessControl {
    function uri(uint256 id_) public view virtual returns (string memory) {
        return "https://arts.standard.tech/";
    }
}
