// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { ERC721 } from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import { ERC721Enumerable } from '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import { ERC721URIStorage } from '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import { AccessControl } from '@openzeppelin/contracts/access/AccessControl.sol';

import { SVGIconsLib } from '../../../libraries/SVGIconsLib.sol';
import { IEIP721Mintable } from '../../../../interfaces/stable/IEIP721Mintable.sol';

/// @title BaseERC721
/// @author Oleg Bedrin <o.bedrin@xsolla.com> - Xsolla Web3
/// @notice ERC721Modular is a base contract for ERC721 tokens with SVG icons and IPFS support.
/// @custom:include-in-addresses-report false
contract ERC721Modular is ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl, IEIP721Mintable {
    /// @notice Role identifier for addresses that can mint tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Indicates whether SVG icons are utilized.
    bool public utilizeSvg;

    /// @notice Default IPFS image URI.
    string public ipfsDefaultImage;

    /// @notice Default fields for SVG icons.
    SVGIconsLib.Field[8] public defaultFields;

    /// @notice Base URI for token metadata.
    string public baseURI;
 
    /// @notice Tracks the next token ID to be minted.
    uint256 public nextTokenId;

    /// @notice Maximum supply of tokens.
    uint256 public immutable maxSupply;

    /// @notice Controls whether minting is enabled or disabled.
    bool public mintingEnabled;

    /// @dev Error thrown when max supply is reached.
    error MaxSupplyReached();

    /// @dev Error thrown when minting is disabled.
    error MintingDisabled();

    /// @notice Initializes the contract with the given parameters.
    /// @param _name Name of the token.
    /// @param _symbol Symbol of the token.
    /// @param _maxSupply Maximum supply of tokens.
    constructor(string memory _name, string memory _symbol, uint256 _maxSupply) ERC721(_name, _symbol) {
        maxSupply = _maxSupply;
        address sender = _msgSender();
        _grantRole(DEFAULT_ADMIN_ROLE, sender);
        _grantRole(MINTER_ROLE, sender);
    }

    /// @notice Sets the token URI for a specific token ID.
    /// @param tokenId ID of the token.
    /// @param _tokenURI URI to set for the token.
    function setTokenUri(uint256 tokenId, string memory _tokenURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTokenURI(tokenId, _tokenURI);
    }

    /// @notice Sets the base URI for token metadata.
    /// @param __baseURI Base URI to set.
    function setBaseUri(string memory __baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = __baseURI;
    }

    /// @notice Sets the default IPFS image URI.
    /// @param _ipfsDefaultImage IPFS URI to set.
    function setIpfsDefaultImage(string memory _ipfsDefaultImage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ipfsDefaultImage = _ipfsDefaultImage;
    }

    /// @notice Sets the default fields for SVG icons.
    /// @param _defaultFields Array of default fields to set.
    function setDefaultFields(SVGIconsLib.Field[8] memory _defaultFields) external onlyRole(DEFAULT_ADMIN_ROLE) {
        defaultFields = _defaultFields;
    }

    /// @notice Toggles the utilization of SVG icons.
    function toggleSvg() external onlyRole(DEFAULT_ADMIN_ROLE) {
        utilizeSvg = !utilizeSvg;
    }

    /// @notice Toggles the minting enabled/disabled state.
    function toggleMinting() external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintingEnabled = !mintingEnabled;
    }

    /// @notice Mints a new token to the specified address.
    /// @param to Address to mint the token to.
    /// @dev Reverts if the total supply exceeds the maximum supply.
    function mint(address to) external payable override onlyRole(MINTER_ROLE) {
        if (!mintingEnabled) {
            revert MintingDisabled();
        }
        _safeMint(to, ++nextTokenId);
        if (totalSupply() > maxSupply) {
            revert MaxSupplyReached();
        }
    }

    /// @notice Mints a new token to the TX sender.
    /// @dev Reverts if the total supply exceeds the maximum supply.
    function mint() external {
        if (!mintingEnabled) {
            revert MintingDisabled();
        }
        address sender = _msgSender();
        _safeMint(sender, ++nextTokenId);
        if (totalSupply() > maxSupply) {
            revert MaxSupplyReached();
        }
    }

    /// @inheritdoc ERC721URIStorage
    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        if (utilizeSvg) {
            _requireMinted(tokenId);
            return
                SVGIconsLib.getIcon(
                    name(),
                    'https://xsolla.com',
                    'Xsolla ZK default NFT',
                    string(abi.encodePacked(tokenId)),
                    defaultFields
                );
        } else {
            return ERC721URIStorage.tokenURI(tokenId);
        }
    }

    /// @inheritdoc ERC721Enumerable
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl) returns (bool) {
        return 
            ERC721.supportsInterface(interfaceId) ||
            ERC721Enumerable.supportsInterface(interfaceId) ||
            ERC721URIStorage.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId) ||
            super.supportsInterface(interfaceId);
    }

    /// @inheritdoc ERC721
    function _baseURI() internal view virtual override returns (string memory) {
        if (bytes(baseURI).length > 0) {
            return baseURI;
        } else {
            return string(abi.encodePacked('ipfs://', ipfsDefaultImage));
        }
    }

    /// @inheritdoc ERC721URIStorage
    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    /// @inheritdoc ERC721Enumerable
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }
}
