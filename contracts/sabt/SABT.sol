pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IMetadata.sol";

/// @author Hyungsuk Kang <hskang9@github.com>
/// @title Standard Account Bound Token
contract SABT is ERC1155, AccessControl {
    address public membership;
    address public metadata;

    uint32 public index;

    mapping(uint32 => uint16) public metaIds;

    constructor() ERC1155("https://arts.standard.tech/") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        index = 1;
    }

    function initialize(
        address membership_,
        address metadata_
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        membership = membership_;
        metadata = metadata_;
    }

    /// @dev meta: Return the metadata of the token meta id
    function meta(
        uint16 metaId_
    ) external view returns (string memory) {
        return IMetadata(metadata).meta(metaId_);
    }

    /// @dev mint: Mint a new SABT for customized membership
    /// @param to_ The address to mint the token to
    /// @param metaId_ The id of the token to mint
    function mint(address to_, uint16 metaId_) public returns (uint32) {
        require(msg.sender == membership, "NM");
        require(index < 2**32, "Membership: index overflow");
        metaIds[index] = metaId_;
        _mint(to_, index, 1, abi.encode(metaId_));
        index++;
        return index - 1;
    }

    /// @dev metaId: Return the metaId of the membership token
    /// @param uid_ The uid of the token to get the metaId of
    function metaId(uint32 uid_) external view returns (uint16) {
        return metaIds[uid_];
    }

    function setMetaId(uint32 uid_, uint16 metaId_) public {
        require(msg.sender == membership, "NM");
        metaIds[uid_] = metaId_;
    }

   function transfer(
        address _to,
        uint256 _id
    ) public {
        super.safeTransferFrom(msg.sender, _to, _id, 1, "");
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl, ERC1155) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            interfaceId == type(IAccessControl).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
