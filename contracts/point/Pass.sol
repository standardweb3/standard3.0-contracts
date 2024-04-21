// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC1155, ERC1155, IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl, IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @author Hyungsuk Kang <hskang9@github.com>
/// @title Standard Account Bound Token
contract Pass is ERC1155, AccessControl, Initializable {
    using Strings for uint256;

    address public pointFarm;
    address public metadata;
    string baseURI;

    uint32 public index;

    mapping(uint32 => uint8) public metaIds;

    error InvalidAccess(address pointFarm_, address sender);
    error MembershipFull(uint32 uid_);
    error InvalidRole(bytes32 role, address sender);

    constructor() ERC1155("https://app.standardweb3.com/api/pass") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        index = 1;
    }

    function initialize(address pointFarm_) external initializer {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        pointFarm = pointFarm_;
        baseURI = "https://app.standardweb3.com/api/pass";
    }

    function setURI(string memory uri_) public {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }
        baseURI = uri_;
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        uint256 meta = metaIds[uint32(tokenId)];
        return string(abi.encodePacked(baseURI, "/", meta.toString()));
    }

    /// @dev mint: Mint a new pass for customized pointFarm
    /// @param to_ The address to mint the token to
    /// @param metaId_ The id of the token to mint
    function mint(address to_, uint8 metaId_) public returns (uint32) {
        if (msg.sender != pointFarm) {
            revert InvalidAccess(pointFarm, msg.sender);
        }
        if (index >= 4294967295 /* 2**32 -1 */ ) {
            revert MembershipFull(index);
        }
        metaIds[index] = metaId_;
        _mint(to_, index, 1, abi.encode(metaId_));
        index++;
        return index - 1;
    }

    /// @dev metaId: Return the metaId of the membership token
    /// @param uid_ The uid of the token to get the metaId of
    function metaId(uint32 uid_) external view returns (uint8) {
        return metaIds[uid_];
    }

    function setMetaId(uint32 uid_, uint8 metaId_) public {
        if (msg.sender != pointFarm) {
            revert InvalidAccess(pointFarm, msg.sender);
        }
        metaIds[uid_] = metaId_;
    }

    function transfer(address _to, uint256 _id) public {
        super.safeTransferFrom(msg.sender, _to, _id, 1, "");
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override (AccessControl, ERC1155)
        returns (bool)
    {
        return interfaceId == type(IERC1155).interfaceId || interfaceId == type(IERC1155MetadataURI).interfaceId
            || interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }
}
