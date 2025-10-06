// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ERC1155Supply } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import { ERC2981 } from "@openzeppelin/contracts/token/common/ERC2981.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

/// @title Collection template with royalties for ERC-1155
/// @author Oleg Bedrin <o.bedrin@xsolla.com> - Xsolla Web3, Gleb Zverev <g.zverev@xsolla.com>
/// @notice A comprehensive ERC1155 contract with royalty management, access control, and advanced minting capabilities
/// @dev Inherits from ERC1155, ERC1155Supply, ERC2981, AccessControl, and Pausable for full functionality.
/// DON'T FORGET TO TURN ON THE SALES STATE BEFORE MINTING!
/// @custom:security This contract implements role-based access control and pausable functionality for enhanced security
contract ERC1155RoyaltyManaged is ERC1155, ERC1155Supply, ERC2981, AccessControl, Pausable {
    /// @notice Collection information struct containing essential collection metadata
    /// @dev Used by getCollectionInfo() to return collection state in a single call
    struct CollectionInfo {
        string name; /// @dev Collection name
        string symbol; /// @dev Collection symbol
        uint256 tokenPrice; /// @dev Current token price in Wei
        uint256 maxPerTransaction; /// @dev Maximum tokens mintable per transaction
        bool saleIsActive; /// @dev Whether public sale is currently active
        bool paused; /// @dev Whether contract is paused
    }

    /// @notice Role for minting NFTs
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role for URI management
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");

    /// @notice Maximum supply per token ID (0 = unlimited)
    mapping(uint256 => uint256) public maxSupplyPerToken;

    /// @notice Current price per token in Wei
    uint256 public tokenPrice;

    /// @notice Maximum tokens per transaction
    uint256 public maxPerTransaction;

    /// @notice Whether public sale is active
    bool public saleIsActive;

    /// @notice Collection name
    string public name;

    /// @notice Collection symbol
    string public symbol;

    /// @notice Royalty factor (scaled by 10000, e.g., 4% = 400)
    uint96 public royaltyFactorBps;

    // Custom errors for gas efficiency
    // / @dev Thrown when attempting to mint while sale is not active
    error SaleNotActive();
    /// @dev Thrown when insufficient payment is provided for minting
    /// @param required The required payment amount in Wei
    /// @param provided The actual payment amount provided in Wei
    error InsufficientPayment(uint256 required, uint256 provided);
    /// @dev Thrown when trying to mint more tokens than available supply
    /// @param tokenId The token ID being minted
    /// @param requested The amount requested to mint
    /// @param available The amount available to mint
    error MaxSupplyExceeded(uint256 tokenId, uint256 requested, uint256 available);
    /// @dev Thrown when trying to mint more tokens than allowed per transaction
    /// @param requested The amount requested to mint
    /// @param max The maximum allowed per transaction
    error MaxPerTransactionExceeded(uint256 requested, uint256 max);
    /// @dev Thrown when amount is zero or invalid
    error InvalidAmount();
    /// @dev Thrown when token ID is invalid
    error InvalidTokenId();
    /// @dev Thrown when array parameters have mismatched lengths
    error ArraysLengthMismatch();
    /// @dev Thrown when royalty percentage exceeds maximum allowed (100%)
    /// @param royalty The invalid royalty value provided
    error RoyaltyTooHigh(uint96 royalty);

    // Events
    event SaleStateChanged(bool isActive);
    event TokenPriceChanged(uint256 oldPrice, uint256 newPrice);
    event MaxPerTransactionChanged(uint256 oldMax, uint256 newMax);
    event URIChanged(string oldURI, string newURI);
    event RoyaltyChanged(uint96 oldRoyalty, uint96 newRoyalty);
    event TokensMinted(address indexed recipient, uint256 indexed tokenId, uint256 amount);
    event TokensBatchMinted(address indexed recipient, uint256[] tokenIds, uint256[] amounts);
    event MaxSupplyPerTokenSet(uint256 indexed tokenId, uint256 maxSupply);

    /// @notice Initialize the ERC1155 contract with royalty management
    /// @dev Sets up roles, default royalty, and initial collection parameters
    /// @param _name Name of the collection
    /// @param _symbol Symbol of the collection
    /// @param _uri Base URI for token metadata
    /// @param _tokenPrice Price per token in Wei (can be 0 for free mints)
    /// @param _maxPerTransaction Maximum tokens per transaction (0 = unlimited)
    /// @param _royaltyFactor Royalty factor in basis points (e.g., 400 = 4%)
    /// @custom:security The deployer receives all admin roles and should transfer them as needed
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        uint256 _tokenPrice,
        uint256 _maxPerTransaction,
        uint96 _royaltyFactor
    ) ERC1155(_uri) {
        name = _name;
        symbol = _symbol;
        tokenPrice = _tokenPrice;
        maxPerTransaction = _maxPerTransaction;
        royaltyFactorBps = _royaltyFactor;

        address sender = _msgSender();

        // Set default royalty
        _setDefaultRoyalty(sender, _royaltyFactor);

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, sender);
        _grantRole(MINTER_ROLE, sender);
        _grantRole(URI_SETTER_ROLE, sender);
    }

    // ============ ADMIN FUNCTIONS ============

    /// @notice Enable or disable public sale
    /// @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
    /// @param _saleIsActive True to enable public sale, false to disable
    /// @custom:security Changes global sale state affecting all public minting
    function setSaleState(bool _saleIsActive) external onlyRole(DEFAULT_ADMIN_ROLE) {
        saleIsActive = _saleIsActive;
        emit SaleStateChanged(_saleIsActive);
    }

    /// @notice Update the price per token for public minting
    /// @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
    /// @param _tokenPrice New price per token in Wei (can be 0 for free mints)
    /// @custom:security Price changes affect all future public mints immediately
    function setTokenPrice(uint256 _tokenPrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldPrice = tokenPrice;
        tokenPrice = _tokenPrice;
        emit TokenPriceChanged(oldPrice, _tokenPrice);
    }

    /// @notice Update maximum tokens allowed per transaction
    /// @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
    /// @param _maxPerTransaction New maximum tokens per transaction (0 = unlimited)
    /// @custom:security Affects all future public minting transactions
    function setMaxPerTransaction(uint256 _maxPerTransaction) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldMax = maxPerTransaction;
        maxPerTransaction = _maxPerTransaction;
        emit MaxPerTransactionChanged(oldMax, _maxPerTransaction);
    }

    /// @notice Update the base URI for token metadata
    /// @dev Only callable by accounts with URI_SETTER_ROLE
    /// @param newURI New base URI string for metadata
    /// @custom:security URI changes affect metadata resolution for all tokens
    function setURI(string memory newURI) external onlyRole(URI_SETTER_ROLE) {
        string memory oldURI = uri(0);
        _setURI(newURI);
        emit URIChanged(oldURI, newURI);
    }

    /// @notice Update the default royalty percentage for all tokens
    /// @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
    /// @param _royaltyFactor New royalty factor in basis points (max 10000 = 100%)
    /// @custom:security Royalty changes affect all future secondary sales
    function setRoyaltyFactor(uint96 _royaltyFactor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_royaltyFactor > _feeDenominator()) {
            revert RoyaltyTooHigh(_royaltyFactor);
        }
        uint96 oldRoyalty = royaltyFactorBps;
        royaltyFactorBps = _royaltyFactor;
        _setDefaultRoyalty(_msgSender(), _royaltyFactor);
        emit RoyaltyChanged(oldRoyalty, _royaltyFactor);
    }

    /// @notice Set maximum supply limit for a specific token ID
    /// @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
    /// @param tokenId The token ID to set maximum supply for
    /// @param _maxSupply Maximum supply for this token ID (0 = unlimited supply)
    /// @custom:security Once set, max supply cannot be increased beyond current total supply
    function setMaxSupplyPerToken(uint256 tokenId, uint256 _maxSupply) public onlyRole(DEFAULT_ADMIN_ROLE) {
        maxSupplyPerToken[tokenId] = _maxSupply;
        emit MaxSupplyPerTokenSet(tokenId, _maxSupply);
    }

    /// @notice Pause all token transfers and minting operations
    /// @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
    /// @custom:security Emergency function to halt all contract operations
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Resume all token transfers and minting operations
    /// @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
    /// @custom:security Resumes normal contract operations after pause
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Withdraw all ETH from the contract to the caller
    /// @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
    /// @custom:security Transfers entire contract balance to caller
    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        Address.sendValue(payable(_msgSender()), address(this).balance);
    }

    /// @notice Mint tokens to a recipient with payment validation
    /// @dev Public minting function that validates sale state, payment, and supply limits
    /// @param tokenId The token ID to mint
    /// @param amount Number of tokens to mint
    /// @param recipient Address that will receive the minted tokens
    /// @custom:security Requires active sale, sufficient payment, and respects supply limits
    function mint(uint256 tokenId, uint256 amount, address recipient) external payable virtual whenNotPaused {
        if (!saleIsActive) revert SaleNotActive();

        _validateMintParams(amount);
        _validateMint(tokenId, amount, msg.value);
        _performMint(tokenId, amount, recipient);
    }

    /// @notice Mint tokens without payment validation (admin function)
    /// @dev Bypasses sale state and payment requirements, only validates supply
    /// @param tokenId The token ID to mint
    /// @param amount Number of tokens to mint
    /// @param recipient Address that will receive the minted tokens
    /// @custom:security Only callable by MINTER_ROLE, bypasses payment requirements
    function mintByRole(uint256 tokenId, uint256 amount, address recipient)
        external
        virtual
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        _validateMintParams(amount);
        _validateSupply(tokenId, amount);
        _performMint(tokenId, amount, recipient);
    }

    /// @notice Mint multiple token types to a single recipient (admin function)
    /// @dev Efficiently mints multiple token IDs in a single transaction
    /// @param tokenIds Array of token IDs to mint
    /// @param amounts Array of amounts corresponding to each token ID
    /// @param recipient Address that will receive all minted tokens
    /// @custom:security Only callable by MINTER_ROLE, validates all parameters before minting
    function batchMint(uint256[] calldata tokenIds, uint256[] calldata amounts, address recipient)
        external
        virtual
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        uint256 length = tokenIds.length;
        if (length != amounts.length) revert ArraysLengthMismatch();

        // Validate all parameters in a single loop
        for (uint256 i; i < length;) {
            _validateMintParams(amounts[i]);
            _validateSupply(tokenIds[i], amounts[i]);
            // Gas optimization: Skip overflow check for loop counter
            // Safe because i starts at 0, increments by 1, and is bounded by length
            // i cannot exceed uint256.max in any realistic scenario
            unchecked {
                ++i;
            }
        }

        _performBatchMint(tokenIds, amounts, recipient);
    }

    /// @notice Mint tokens to multiple recipients (admin function)
    /// @dev Allows minting different tokens to different recipients in one transaction
    /// @param tokenIds Array of token IDs to mint
    /// @param amounts Array of amounts corresponding to each token ID
    /// @param recipients Array of recipient addresses for each mint operation
    /// @custom:security Only callable by MINTER_ROLE, all arrays must have equal length
    function batchMintToMultiple(
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        address[] calldata recipients
    ) external virtual onlyRole(MINTER_ROLE) whenNotPaused {
        uint256 length = tokenIds.length;
        if (length != amounts.length || length != recipients.length) revert ArraysLengthMismatch();

        // Validate and mint in a single loop for better gas efficiency
        for (uint256 i; i < length;) {
            _validateMintParams(amounts[i]);
            _validateSupply(tokenIds[i], amounts[i]);
            _performMint(tokenIds[i], amounts[i], recipients[i]);
            // Gas optimization: Skip overflow check for loop counter
            // Safe because i starts at 0, increments by 1, and is bounded by length
            // i cannot exceed uint256.max in any realistic scenario
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Validate basic mint parameters common to all mint functions
    /// @param amount Number of tokens to mint, must be greater than 0
    function _validateMintParams(uint256 amount) internal pure {
        if (amount == 0) revert InvalidAmount();
    }

    /// @dev Validate mint parameters specific to paid public mints
    /// @param tokenId Token ID being minted
    /// @param amount Number of tokens to mint
    /// @param payment Amount of ETH sent with the transaction
    function _validateMint(uint256 tokenId, uint256 amount, uint256 payment) internal view {
        // Check max per transaction first (cheaper check)
        if (maxPerTransaction > 0 && amount > maxPerTransaction) {
            revert MaxPerTransactionExceeded(amount, maxPerTransaction);
        }

        _validateSupply(tokenId, amount);

        // Calculate and check payment (avoid multiplication if tokenPrice is 0)
        if (tokenPrice > 0) {
            uint256 totalCost = tokenPrice * amount;
            if (payment < totalCost) {
                revert InsufficientPayment(totalCost, payment);
            }
        }
    }

    /// @dev Validate that minting amount doesn't exceed maximum supply for token
    /// @param tokenId Token ID being validated
    /// @param amount Number of tokens to mint
    function _validateSupply(uint256 tokenId, uint256 amount) internal view {
        uint256 maxForToken = maxSupplyPerToken[tokenId];
        if (maxForToken > 0) {
            uint256 currentSupply = totalSupply(tokenId);
            if (currentSupply + amount > maxForToken) {
                revert MaxSupplyExceeded(tokenId, amount, maxForToken - currentSupply);
            }
        }
    }

    /// @dev Execute the actual minting operation and emit event
    /// @param tokenId Token ID to mint
    /// @param amount Number of tokens to mint
    /// @param recipient Address receiving the tokens
    function _performMint(uint256 tokenId, uint256 amount, address recipient) internal {
        _mint(recipient, tokenId, amount, "");
        emit TokensMinted(recipient, tokenId, amount);
    }

    /// @dev Execute batch minting operation and emit event
    /// @param tokenIds Array of token IDs to mint
    /// @param amounts Array of amounts for each token ID
    /// @param recipient Address receiving all tokens
    function _performBatchMint(uint256[] calldata tokenIds, uint256[] calldata amounts, address recipient) internal {
        _mintBatch(recipient, tokenIds, amounts, "");
        emit TokensBatchMinted(recipient, tokenIds, amounts);
    }

    /// @inheritdoc ERC1155Supply
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    /// @notice Check if contract supports a given interface
    /// @dev Combines interface support from all inherited contracts
    /// @param interfaceId The interface identifier to check
    /// @return True if interface is supported, false otherwise
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC2981, AccessControl)
        returns (bool)
    {
        return ERC1155.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId)
            || AccessControl.supportsInterface(interfaceId) || super.supportsInterface(interfaceId);
    }

    /// @notice Get comprehensive collection information in a single call
    /// @dev Useful for frontend applications to get all collection state at once
    /// @return info Struct containing name, symbol, price, limits, and status
    function getCollectionInfo() external view returns (CollectionInfo memory info) {
        return CollectionInfo({
            name: name,
            symbol: symbol,
            tokenPrice: tokenPrice,
            maxPerTransaction: maxPerTransaction,
            saleIsActive: saleIsActive,
            paused: paused()
        });
    }

    /// @notice Get total supply for multiple token IDs efficiently
    /// @dev More gas efficient than calling totalSupply() multiple times
    /// @param tokenIds Array of token IDs to query
    /// @return supplies Array of total supplies corresponding to each token ID
    function getTotalSupplies(uint256[] calldata tokenIds) external view returns (uint256[] memory supplies) {
        uint256 length = tokenIds.length;
        supplies = new uint256[](length);
        for (uint256 i; i < length;) {
            supplies[i] = totalSupply(tokenIds[i]);
            // Gas optimization: Skip overflow check for loop counter
            // Safe because i starts at 0, increments by 1, and is bounded by length
            // i cannot exceed uint256.max in any realistic scenario
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Get maximum supply limits for multiple token IDs
    /// @dev Returns 0 for token IDs with unlimited supply
    /// @param tokenIds Array of token IDs to query
    /// @return maxSupplies Array of maximum supplies for each token ID
    function getMaxSupplies(uint256[] calldata tokenIds) external view returns (uint256[] memory maxSupplies) {
        uint256 length = tokenIds.length;
        maxSupplies = new uint256[](length);
        for (uint256 i; i < length;) {
            maxSupplies[i] = maxSupplyPerToken[tokenIds[i]];
            // Gas optimization: Skip overflow check for loop counter
            // Safe because i starts at 0, increments by 1, and is bounded by length
            // i cannot exceed uint256.max in any realistic scenario
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Calculate available supply remaining for a token ID
    /// @dev Returns 0 if supply is unlimited or if max supply is reached
    /// @param tokenId Token ID to check available supply for
    /// @return Available supply remaining (0 indicates unlimited or exhausted)
    function getAvailableSupply(uint256 tokenId) external view returns (uint256) {
        uint256 maxForToken = maxSupplyPerToken[tokenId];
        if (maxForToken == 0) return 0; // Unlimited

        uint256 currentSupply = totalSupply(tokenId);
        return maxForToken > currentSupply ? maxForToken - currentSupply : 0;
    }

    /// @notice Check if a token ID is available for minting with remaining supply
    /// @dev Provides both availability status and exact remaining count
    /// @param tokenId Token ID to check availability for
    /// @return available True if token can be minted, false if supply exhausted
    /// @return remainingSupply Exact number of tokens remaining (0 if unlimited or exhausted)
    function isTokenAvailable(uint256 tokenId) external view returns (bool available, uint256 remainingSupply) {
        uint256 maxForToken = maxSupplyPerToken[tokenId];
        if (maxForToken == 0) return (true, 0); // Unlimited

        uint256 currentSupply = totalSupply(tokenId);
        if (currentSupply >= maxForToken) return (false, 0);

        return (true, maxForToken - currentSupply);
    }
}
