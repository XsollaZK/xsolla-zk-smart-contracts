// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { ERC721Enumerable, ERC721 } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import { ERC721Royalty } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import { ERC721URIStorage } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { IEIP721Mintable } from "../../../interfaces/stable/IEIP721Mintable.sol";

/// @title ERC721 NFT Collection with Royalty Management
/// @author Oleg Bedrin <o.bedrin@xsolla.com> - Xsolla Web3, Gleb Zverev <g.zverev@xsolla.com> 
/// @notice A comprehensive ERC721 implementation with
/// royalty management, access control, and flexible minting
/// @dev This contract combines multiple OpenZeppelin extensions:
///      - ERC721Enumerable: For token enumeration and supply tracking
///      - ERC721Royalty: For EIP-2981 royalty standard support
///      - ERC721URIStorage: For individual token URI management
///      - AccessControl: For role-based permissions
///      - Pausable: For emergency pause functionality
/// @dev Features include:
///      - Configurable token pricing and sale states
///      - Role-based minting permissions
///      - Batch operations for efficiency
///      - Individual and collection-wide metadata support
///      - Per-token royalty configuration
///      DON'T FORGET TO TURN ON THE SALES STATE BEFORE MINTING!
contract ERC721RoyaltyManaged is
    ERC721Enumerable,
    ERC721Royalty,
    ERC721URIStorage,
    AccessControl,
    Pausable,
    IEIP721Mintable
{
    /// @notice Information about the NFT collection for external queries
    /// @dev Used by frontend applications to display collection details
    struct CollectionInfo {
        string name; /// @dev The collection name from ERC721
        string symbol; /// @dev The collection symbol from ERC721
        uint256 totalSupply; /// @dev Current number of minted tokens
        uint256 maxSupply; /// @dev Maximum tokens that can be minted (0 =
            /// unlimited)
        uint256 tokenPrice; /// @dev Price per token in wei
        uint256 maxPerTransaction; /// @dev Maximum tokens per transaction (0 =
            /// unlimited)
        bool saleIsActive; /// @dev Whether public minting is currently enabled
        bool paused; /// @dev Whether the contract is paused
    }

    /// @notice Optimized storage configuration for collection parameters
    /// @dev Packed into a single storage slot for gas efficiency (32 bytes
    /// total) Fields are ordered by size to minimize storage usage
    struct CollectionConfig {
        uint96 tokenPrice; /// @dev Price per token in wei (supports up to ~79
            /// billion ETH)
        uint96 royaltyFactorBps; /// @dev Royalty percentage in basis points
            /// (10000 = 100%)
        uint32 maxSupply; /// @dev Maximum supply (supports up to ~4.3 billion
            /// tokens)
        uint16 maxPerTransaction; /// @dev Max tokens per transaction (supports
            /// up to 65,535)
        bool saleIsActive; /// @dev Whether public sale is active
            // 1 byte remaining in the 32-byte slot
    }

    /// @notice Role identifier for administrative functions
    /// @dev Grants access to configuration changes, pausing, and fund
    /// withdrawal
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /// @notice Role identifier for token minting privileges
    /// @dev Allows bypassing sale state and payment requirements
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role identifier for URI management functions
    /// @dev Controls base URI and individual token URI modifications
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");

    /// @notice Gas-optimized storage for collection configuration
    /// @dev All configuration parameters packed into a single storage slot
    CollectionConfig public config;

    /// @notice Base URI for token metadata when individual URIs are not set
    /// @dev Fallback URI used by tokenURI() function
    string private _baseTokenURI;

    /// @notice Thrown when attempting to mint while sale is inactive
    error SaleNotActive();

    /// @notice Thrown when insufficient payment is provided for minting
    /// @param required The total cost required for the transaction
    /// @param provided The amount of wei sent with the transaction
    error InsufficientPayment(uint256 required, uint256 provided);

    /// @notice Thrown when minting would exceed the maximum supply
    /// @param requested Number of tokens requested to mint
    /// @param available Number of tokens still available to mint
    error MaxSupplyExceeded(uint256 requested, uint256 available);

    /// @notice Thrown when requesting more tokens per transaction than allowed
    /// @param requested Number of tokens requested in the transaction
    /// @param max Maximum tokens allowed per transaction
    error MaxPerTransactionExceeded(uint256 requested, uint256 max);

    /// @notice Thrown when attempting to mint zero tokens
    error InvalidAmount();

    /// @notice Thrown when setting royalty above the maximum allowed
    /// @param provided The royalty factor that was attempted to be set
    /// @param max The maximum allowed royalty factor
    error RoyaltyTooHigh(uint96 provided, uint96 max);

    /// @notice Thrown when array parameters have mismatched lengths
    /// @param amounts Length of the amounts array
    /// @param recipients Length of the recipients array
    error ArrayLengthMismatch(uint256 amounts, uint256 recipients);

    /// @notice Emitted when the sale state changes
    /// @param isActive The new sale state
    event SaleStateChanged(bool isActive);

    /// @notice Emitted when the token price is updated
    /// @param oldPrice The previous token price in wei
    /// @param newPrice The new token price in wei
    event TokenPriceChanged(uint256 oldPrice, uint256 newPrice);

    /// @notice Emitted when the maximum tokens per transaction limit changes
    /// @param oldMax The previous maximum tokens per transaction
    /// @param newMax The new maximum tokens per transaction
    event MaxPerTransactionChanged(uint256 oldMax, uint256 newMax);

    /// @notice Emitted when the base URI for metadata is updated
    /// @param oldURI The previous base URI
    /// @param newURI The new base URI
    event BaseURIChanged(string oldURI, string newURI);

    /// @notice Emitted when the default royalty factor changes
    /// @param oldRoyalty The previous royalty factor in basis points
    /// @param newRoyalty The new royalty factor in basis points
    event RoyaltyChanged(uint96 oldRoyalty, uint96 newRoyalty);

    /// @notice Emitted when tokens are successfully minted
    /// @param recipient The address that received the minted tokens
    /// @param amount The number of tokens minted
    /// @param firstTokenId The ID of the first token in the minted batch
    event TokensMinted(address indexed recipient, uint256 amount, uint256 firstTokenId);

    /// @notice Initialize the NFT collection with configuration parameters
    /// @param name The name of the ERC721 collection
    /// @param symbol The symbol of the ERC721 collection
    /// @param _maxSupply Maximum number of tokens that can be minted (0 for
    /// unlimited) @param _tokenPrice Price per token in wei for public minting
    /// @param _maxPerTransaction Maximum tokens allowed per transaction (0 for
    /// unlimited) @param _royaltyFactor Default royalty percentage in basis
    /// points (10000 = 100%)
    /// @param __baseURI Base URI for token metadata when individual URIs are
    /// not set @dev The deployer receives all admin roles and becomes the
    /// default royalty recipient
    constructor(
        uint32 _maxSupply,
        uint96 _tokenPrice,
        uint16 _maxPerTransaction,
        uint96 _royaltyFactor,
        string memory name,
        string memory symbol,
        string memory __baseURI
    ) ERC721(name, symbol) {
        config = CollectionConfig({
            tokenPrice: _tokenPrice,
            royaltyFactorBps: _royaltyFactor,
            maxSupply: _maxSupply,
            maxPerTransaction: _maxPerTransaction,
            saleIsActive: false
        });
        _baseTokenURI = __baseURI;

        address sender = _msgSender();

        // Set default royalty
        _setDefaultRoyalty(sender, _royaltyFactor);

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, sender);
        _grantRole(MINTER_ROLE, sender);
        _grantRole(URI_SETTER_ROLE, sender);
    }

    /// @notice Set the metadata URI for a specific token
    /// @param tokenId The ID of the token to set the URI for
    /// @param _tokenURI The new URI for the token's metadata
    /// @dev Requires URI_SETTER_ROLE. Individual token URIs override the base
    /// URI
    function setTokenURI(uint256 tokenId, string calldata _tokenURI) external onlyRole(URI_SETTER_ROLE) {
        _setTokenURI(tokenId, _tokenURI);
    }

    /// @notice Set metadata URIs for multiple tokens in a single transaction
    /// @param tokenIds Array of token IDs to set URIs for
    /// @param _tokenURIs Array of corresponding URIs for each token
    /// @dev Requires URI_SETTER_ROLE. Arrays must have matching lengths
    function batchSetTokenURIs(uint256[] calldata tokenIds, string[] calldata _tokenURIs)
        external
        onlyRole(URI_SETTER_ROLE)
    {
        uint256 length = tokenIds.length;
        if (length != _tokenURIs.length) {
            revert ArrayLengthMismatch(length, _tokenURIs.length);
        }

        for (uint256 i; i < length;) {
            _setTokenURI(tokenIds[i], _tokenURIs[i]);
            // UNCHECKED SECTION 3: Loop increment (same safety as above)
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Enable or disable public token sales
    /// @param _saleIsActive True to enable sales, false to disable
    /// @dev Requires DEFAULT_ADMIN_ROLE. When disabled, only MINTER_ROLE can
    /// mint
    function setSaleState(bool _saleIsActive) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config.saleIsActive = _saleIsActive;
        emit SaleStateChanged(_saleIsActive);
    }

    /// @notice Update the price for minting tokens
    /// @param _tokenPrice New price per token in wei
    /// @dev Requires DEFAULT_ADMIN_ROLE. Affects future minting transactions
    function setTokenPrice(uint96 _tokenPrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldPrice = config.tokenPrice;
        config.tokenPrice = _tokenPrice;
        emit TokenPriceChanged(oldPrice, _tokenPrice);
    }

    /// @notice Update the maximum tokens allowed per transaction
    /// @param _maxPerTransaction New maximum tokens per transaction (0 for
    /// unlimited) @dev Requires DEFAULT_ADMIN_ROLE. Affects future public
    /// minting
    function setMaxPerTransaction(uint16 _maxPerTransaction) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldMax = config.maxPerTransaction;
        config.maxPerTransaction = _maxPerTransaction;
        emit MaxPerTransactionChanged(oldMax, _maxPerTransaction);
    }

    /// @notice Update the base URI for token metadata
    /// @param baseURI New base URI string
    /// @dev Requires URI_SETTER_ROLE. Used when individual token URIs are not
    /// set
    function setBaseURI(string calldata baseURI) external onlyRole(URI_SETTER_ROLE) {
        string memory oldURI = _baseTokenURI;
        _baseTokenURI = baseURI;
        emit BaseURIChanged(oldURI, baseURI);
    }

    /// @notice Update the default royalty percentage for the collection
    /// @param _royaltyFactor New royalty percentage in basis points (10000 =
    /// 100%) @dev Requires DEFAULT_ADMIN_ROLE. Must not exceed the maximum
    /// allowed royalty
    /// @dev Sets the caller as the royalty recipient
    function setRoyaltyFactor(uint96 _royaltyFactor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint96 maxBps = _feeDenominator();
        if (_royaltyFactor > maxBps) {
            revert RoyaltyTooHigh(_royaltyFactor, maxBps);
        }
        uint96 oldRoyalty = config.royaltyFactorBps;
        config.royaltyFactorBps = _royaltyFactor;
        // Get the current admin role holder for royalty recipient
        _setDefaultRoyalty(_msgSender(), _royaltyFactor);
        emit RoyaltyChanged(oldRoyalty, _royaltyFactor);
    }

    /// @notice Pause all token transfers and minting
    /// @dev Requires DEFAULT_ADMIN_ROLE. Emergency function to halt contract
    /// operations
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Resume all token transfers and minting
    /// @dev Requires DEFAULT_ADMIN_ROLE. Reverses the pause operation
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Withdraw the contract's ETH balance to the caller
    /// @dev Requires DEFAULT_ADMIN_ROLE. Transfers all contract funds to the
    /// caller
    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        Address.sendValue(payable(_msgSender()), address(this).balance);
    }

    /// @notice Mint a single token to the specified recipient
    /// @param recipient Address to receive the minted token
    /// @dev Convenience function that calls mint(1, recipient)
    /// @dev Requires payment and active sale state
    function mint(address recipient) external payable override {
        mint(1, recipient);
    }

    /// @notice Mint multiple tokens to the specified recipient
    /// @param amount Number of tokens to mint
    /// @param recipient Address to receive the minted tokens
    /// @dev Requires sufficient payment, active sale, and respects transaction
    /// limits @dev Contract must not be paused
    function mint(uint256 amount, address recipient) public payable whenNotPaused {
        CollectionConfig memory cfg = config; // Load to memory once

        if (!cfg.saleIsActive) revert SaleNotActive();
        if (amount == 0) revert InvalidAmount();

        _validateMint(amount, msg.value, cfg);
        _performMint(amount, recipient);
    }

    /// @notice Mint by minter role (bypasses sale state and payment)
    /// @param amount Number of tokens to mint
    /// @param recipient Address to receive the minted tokens
    /// @dev Requires MINTER_ROLE and contract must not be paused
    function mintByRole(uint256 amount, address recipient) external onlyRole(MINTER_ROLE) whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        _validateSupply(amount);
        _performMint(amount, recipient);
    }

    /// @notice Mint different amounts of tokens to multiple recipients
    /// @param amounts Array of token amounts to mint for each recipient
    /// @param recipients Array of addresses to receive the tokens
    /// @dev Requires MINTER_ROLE. Arrays must have matching lengths
    /// @dev Validates total supply constraints across all mints
    function batchMint(uint256[] calldata amounts, address[] calldata recipients)
        external
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        uint256 length = amounts.length;
        if (length != recipients.length) {
            revert ArrayLengthMismatch(length, recipients.length);
        }

        uint256 totalAmount;
        for (uint256 i; i < length;) {
            if (amounts[i] == 0) revert InvalidAmount();
            totalAmount += amounts[i];
            // UNCHECKED SECTION 1: Loop increment
            // Safe because: i starts at 0 and increments by 1 each iteration
            // Bounds: i < length, so maximum value is (length - 1)
            // Since length is from .length property, it cannot exceed
            // type(uint256).max Therefore i + 1 cannot overflow
            unchecked {
                ++i;
            }
        }

        _validateSupply(totalAmount);

        for (uint256 i; i < length;) {
            _performMint(amounts[i], recipients[i]);
            // UNCHECKED SECTION 2: Loop increment (same safety as above)
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Get the metadata URI for a specific token
    /// @param tokenId The ID of the token to query
    /// @return The complete URI for the token's metadata
    /// @dev Returns individual token URI if set, otherwise constructs from base
    /// URI
    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        return ERC721URIStorage.tokenURI(tokenId);
    }

    /// @notice Get comprehensive information about the collection
    /// @return CollectionInfo struct containing all relevant collection data
    /// @dev Useful for frontend applications to display collection status
    function getCollectionInfo() external view returns (CollectionInfo memory) {
        CollectionConfig memory cfg = config;
        return CollectionInfo({
            name: name(),
            symbol: symbol(),
            totalSupply: totalSupply(),
            maxSupply: cfg.maxSupply,
            tokenPrice: cfg.tokenPrice,
            maxPerTransaction: cfg.maxPerTransaction,
            saleIsActive: cfg.saleIsActive,
            paused: paused()
        });
    }

    /// @notice Get the maximum number of tokens that can be minted
    /// @return The maximum supply (0 means unlimited)
    function maxSupply() external view returns (uint256) {
        return config.maxSupply;
    }

    /// @notice Get the current price per token in wei
    /// @return The token price for public minting
    function tokenPrice() external view returns (uint256) {
        return config.tokenPrice;
    }

    /// @notice Get the maximum tokens allowed per transaction
    /// @return The per-transaction limit (0 means unlimited)
    function maxPerTransaction() external view returns (uint256) {
        return config.maxPerTransaction;
    }

    /// @notice Check if public token sales are currently active
    /// @return True if public minting is enabled
    function saleIsActive() external view returns (bool) {
        return config.saleIsActive;
    }

    /// @notice Get the current royalty percentage in basis points
    /// @return The royalty factor (10000 = 100%)
    function royaltyFactorBps() external view returns (uint96) {
        return config.royaltyFactorBps;
    }

    /// @dev Validate mint parameters
    function _validateMint(uint256 amount, uint256 payment, CollectionConfig memory cfg) internal view {
        if (cfg.maxPerTransaction > 0 && amount > cfg.maxPerTransaction) {
            revert MaxPerTransactionExceeded(amount, cfg.maxPerTransaction);
        }

        _validateSupply(amount);

        uint256 totalCost = uint256(cfg.tokenPrice) * amount;
        if (payment < totalCost) {
            revert InsufficientPayment(totalCost, payment);
        }
    }

    /// @dev Validate supply constraints
    function _validateSupply(uint256 amount) internal view {
        uint256 maxSupply_ = config.maxSupply;
        if (maxSupply_ > 0 && totalSupply() + amount > maxSupply_) {
            revert MaxSupplyExceeded(amount, maxSupply_ - totalSupply());
        }
    }

    /// @dev Perform the actual minting
    function _performMint(uint256 amount, address recipient) internal {
        uint256 firstTokenId = totalSupply();

        for (uint256 i; i < amount;) {
            uint256 tokenId = firstTokenId + i;
            _safeMint(recipient, tokenId);
            // Set individual token royalty to the recipient
            _setTokenRoyalty(tokenId, recipient, config.royaltyFactorBps);
            unchecked {
                ++i;
            }
        }

        emit TokensMinted(recipient, amount, firstTokenId);
    }

    /// @inheritdoc ERC721Enumerable
    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return ERC721Enumerable._update(to, tokenId, auth);
    }

    /// @inheritdoc ERC721Enumerable
    function _increaseBalance(address account, uint128 value) internal virtual override(ERC721, ERC721Enumerable) {
        ERC721Enumerable._increaseBalance(account, value);
    }

    /// @notice Override _baseURI to return the stored base URI
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice Interface support
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, ERC721Royalty, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return ERC721Enumerable.supportsInterface(interfaceId) || ERC721Royalty.supportsInterface(interfaceId)
            || ERC721URIStorage.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId)
            || super.supportsInterface(interfaceId);
    }
}
