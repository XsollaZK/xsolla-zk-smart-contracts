// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { IERC721 } from '@openzeppelin-contracts-5.4.0/token/ERC721/IERC721.sol';
import { Ownable } from '@openzeppelin-contracts-5.4.0/access/Ownable.sol';

import { ERC721Modular } from './extensions/ERC721Modular.sol';
import { SVGIconsLib } from '../../libraries/SVGIconsLib.sol';

/// @title ERC721Factory
/// @author Oleg Bedrin <o.bedrin@xsolla.com> - Xsolla Web3
/// @notice A factory contract for deploying ERC721 collections with default or custom configurations.
contract ERC721Factory is Ownable {
    /// @notice Emitted when a new collection is deployed.
    /// @param newCollectionAddress The address of the newly deployed collection.
    event NewCollectionDeployed(address indexed newCollectionAddress);

    /// @notice The default maximum supply for collections.
    uint256 public constant DEFAULT_MAX_SUPPLY = 100_000;

    /// @notice Default fields for SVG icons.
    SVGIconsLib.Field[8] internal DEFAULT_FIELDS = [
        SVGIconsLib.Field('Name: ', 'XZKET', 'none'),
        SVGIconsLib.Field('Description: ', 'Testing token', 'none'),
        SVGIconsLib.Field('', '', 'none'),
        SVGIconsLib.Field('', '', 'none'),
        SVGIconsLib.Field('', '', 'none'),
        SVGIconsLib.Field('', '', 'none'),
        SVGIconsLib.Field('', '', 'none'),
        SVGIconsLib.Field('', '', 'none')
    ];

    /// @notice Default IPFS image URI.
    string public constant IPFS_DEFAULT_IMAGE = "bafkreie7ohywtosou76tasm7j63yigtzxe7d5zqus4zu3j6oltvgtibeom"; // Hello IPFS image.

    /// @notice The constructor sets the initial owner to the deployer.
    constructor() Ownable(_msgSender()) {}

    /// @notice Deploys a new collection with default configurations.
    /// @param _name The name of the collection.
    /// @param _symbol The symbol of the collection.
    function deployDefaultCollection(
        string memory _name,
        string memory _symbol
    ) external {
        ERC721Modular collection = new ERC721Modular(
            _name,
            _symbol,
            DEFAULT_MAX_SUPPLY
        );
        collection.setDefaultFields(DEFAULT_FIELDS);
        collection.setIpfsDefaultImage(IPFS_DEFAULT_IMAGE);
        collection.grantRole(0x0, _msgSender());
        emit NewCollectionDeployed(address(collection)); 
    }

    /// @notice Deploys a new collection with custom configurations.
    /// @param _defaultFields The default fields for SVG icons.
    /// @param _ipfsDefaultImage The default IPFS image URI.
    /// @param _name The name of the collection.
    /// @param _symbol The symbol of the collection.
    /// @param _maxSupply The maximum supply of the collection.
    function deployCollection(
        SVGIconsLib.Field[8] memory _defaultFields,
        string memory _ipfsDefaultImage,
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply
    ) external {
        ERC721Modular collection = new ERC721Modular(
            _name,
            _symbol,
            _maxSupply
        );
        collection.setDefaultFields(_defaultFields);
        collection.setIpfsDefaultImage(_ipfsDefaultImage);
        collection.grantRole(0x0, _msgSender());
        emit NewCollectionDeployed(address(collection)); 
    }
}