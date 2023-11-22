// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TokenizedVickeryAuction.sol";

contract TokenizedVickeryAuctionV2 is TokenizedVickeryAuction {
    mapping(address => bool) public blacklistedSellers;

    event SellerBlacklisted(address indexed seller);

    event SellerRemovedFromBlacklist(address indexed seller);

    /**
     * @notice Modifier to check if the seller is not blacklisted
     */
    modifier notBlacklistedSeller() {
        require(!blacklistedSellers[msg.sender], "Seller is blacklisted");
        _;
    }

    /**
     * @notice Creates an auction for the given ERC721 asset with the given
     *         auction parameters.
     * @dev Overridden to include a check against the blacklist
     */
    function createAuction(
        address tokenContract,
        uint256 tokenId,
        address erc20Token,
        uint32 startTime,
        uint32 bidPeriod,
        uint32 revealPeriod,
        uint96 reservePrice
    ) public override notBlacklistedSeller {
        super.createAuction(
            tokenContract,
            tokenId,
            erc20Token,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
    }

    /**
     * @notice Adds a seller to the blacklist
     * @param seller The address of the seller to blacklist
     */
    function blacklistSeller(address seller) external {
        // Only the contract owner or another authorized entity should be able to blacklist sellers
        // require(msg.sender == owner, "Only owner can blacklist"); // Uncomment if using Ownable or similar
        blacklistedSellers[seller] = true;
        emit SellerBlacklisted(seller);
    }

    /**
     * @notice Removes a seller from the blacklist
     * @param seller The address of the seller to remove from the blacklist
     */
    function removeSellerFromBlacklist(address seller) external {
        // Only the contract owner or another authorized entity should be able to remove from blacklist
        // require(msg.sender == owner, "Only owner can remove from blacklist"); // Uncomment if using Ownable or similar
        blacklistedSellers[seller] = false;
        emit SellerRemovedFromBlacklist(seller);
    }
}
