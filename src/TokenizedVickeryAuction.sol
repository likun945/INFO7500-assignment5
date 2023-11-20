// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title An on-chain, over-collateralization, sealed-bid, second-price auction
contract TokenizedVickeryAuction {
    /// @dev Representation of an auction in storage. Occupies three slots.
    /// @param seller The address selling the auctioned asset.
    /// @param startTime The unix timestamp at which bidding can start.
    /// @param endOfBiddingPeriod The unix timestamp after which bids can no
    ///        longer be placed.
    /// @param endOfRevealPeriod The unix timestamp after which commitments can
    ///        no longer be opened.
    /// @param numUnrevealedBids The number of bid commitments that have not
    ///        yet been opened.
    /// @param highestBid The value of the highest bid revealed so far, or
    ///        the reserve price if no bids have exceeded it.
    /// @param secondHighestBid The value of the second-highest bid revealed
    ///        so far, or the reserve price if no two bids have exceeded it.
    /// @param highestBidder The bidder that placed the highest bid.
    /// @param index Auctions selling the same asset (i.e. tokenContract-tokenId
    ///        pair) share the same storage. This value is incremented for
    ///        each new auction of a particular asset.
    struct Auction {
        address seller;
        uint32 startTime;
        uint32 endOfBiddingPeriod;
        uint32 endOfRevealPeriod;
        // =====================
        uint64 numUnrevealedBids;
        uint96 highestBid;
        uint96 secondHighestBid;
        // =====================
        address highestBidder;
        uint64 index;
        address erc20Token;
    }

    /// @param commitment The hash commitment of a bid value.
    /// @param collateral The amount of collateral backing the bid.
    struct Bid {
        bytes20 commitment;
        uint96 collateral;
    }

    /// @notice A mapping storing auction parameters and state, indexed by
    ///         the ERC721 contract address and token ID of the asset being
    ///         auctioned.
    mapping(address => mapping(uint256 => Auction)) public auctions;

    /// @notice A mapping storing bid commitments and records of collateral,
    ///         indexed by: ERC721 contract address, token ID, auction index,
    ///         and bidder address. If the commitment is `bytes20(0)`, either
    ///         no commitment was made or the commitment was opened.
    mapping(address => mapping(uint256 => mapping(uint64 => mapping(address => Bid)))) // ERC721 token contract // ERC721 token ID // Auction index // Bidder
        public bids;

    /// @notice Creates an auction for the given ERC721 asset with the given
    ///         auction parameters.
    /// @param tokenContract The address of the ERC721 contract for the asset
    ///        being auctioned.
    /// @param tokenId The ERC721 token ID of the asset being auctioned.
    /// @param startTime The unix timestamp at which bidding can start.
    /// @param bidPeriod The duration of the bidding period, in seconds.
    /// @param revealPeriod The duration of the commitment reveal period,
    ///        in seconds.
    /// @param reservePrice The minimum price that the asset will be sold for.
    ///        If no bids exceed this price, the asset is returned to `seller`.
    function createAuction(
        address tokenContract,
        uint256 tokenId,
        address erc20Token,
        uint32 startTime,
        uint32 bidPeriod,
        uint32 revealPeriod,
        uint96 reservePrice
    ) external {
        require(
            auctions[tokenContract][tokenId].startTime == 0 ||
                block.timestamp >
                auctions[tokenContract][tokenId].endOfRevealPeriod,
            "An active auction already exists for this item"
        );
        require(
            startTime > block.timestamp,
            "Start time must be in the future"
        );
        require(bidPeriod > 0, "Bid period must be greater than zero");
        require(revealPeriod > 0, "Reveal period must be greater than zero");
        require(reservePrice > 0, "Reserve price must be greater than zero");
        auctions[tokenContract][tokenId] = Auction({
            seller: msg.sender,
            startTime: startTime,
            endOfBiddingPeriod: startTime + bidPeriod,
            endOfRevealPeriod: startTime + bidPeriod + revealPeriod,
            numUnrevealedBids: 0,
            highestBid: reservePrice,
            secondHighestBid: reservePrice,
            highestBidder: address(0),
            index: auctions[tokenContract][tokenId].index + 1,
            erc20Token: erc20Token
        });
    }

    /// @notice Commits to a bid on an item being auctioned. If a bid was
    ///         previously committed to, overwrites the previous commitment.
    ///         Value attached to this call is used as collateral for the bid.
    /// @param tokenContract The address of the ERC721 contract for the asset
    ///        being auctioned.
    /// @param tokenId The ERC721 token ID of the asset being auctioned.
    /// @param commitment The commitment to the bid, computed as
    ///        `bytes20(keccak256(abi.encode(nonce, bidValue, tokenContract, tokenId, auctionIndex)))`.
    /// @param erc20Tokens The amount of ERC20 tokens to be used as collateral
    function commitBid(
        address tokenContract,
        uint256 tokenId,
        bytes20 commitment,
        uint256 erc20Tokens
    ) external {
        Auction storage auction = auctions[tokenContract][tokenId];
        require(auction.startTime > 0, "Auction does not exist for this item");
        require(
            block.timestamp >= auction.startTime,
            "Bidding has not started yet"
        );
        require(
            block.timestamp < auction.endOfRevealPeriod,
            "Bidding has ended"
        );
        require(erc20Tokens > 0, "Collateral must be sent with the bid");

        IERC20(auction.erc20Token).transferFrom(
            msg.sender,
            address(this),
            erc20Tokens
        );

        Bid storage bid = bids[tokenContract][tokenId][auction.index][
            msg.sender
        ];
        bid.commitment = commitment;
        bid.collateral = uint96(erc20Tokens);
    }

    /// @notice Reveals the value of a bid that was previously committed to.
    /// @param tokenContract The address of the ERC721 contract for the asset
    ///        being auctioned.
    /// @param tokenId The ERC721 token ID of the asset being auctioned.
    /// @param bidValue The value of the bid.
    /// @param nonce The random input used to obfuscate the commitment.
    function revealBid(
        address tokenContract,
        uint256 tokenId,
        uint96 bidValue,
        bytes32 nonce
    ) external {}

    /// @notice Ends an active auction. Can only end an auction if the bid reveal
    ///         phase is over, or if all bids have been revealed. Disburses the auction
    ///         proceeds to the seller. Transfers the auctioned asset to the winning
    ///         bidder and returns any excess collateral. If no bidder exceeded the
    ///         auction's reserve price, returns the asset to the seller.
    /// @param tokenContract The address of the ERC721 contract for the asset auctioned.
    /// @param tokenId The ERC721 token ID of the asset auctioned.
    function endAuction(address tokenContract, uint256 tokenId) external {}

    /// @notice Withdraws collateral. Bidder must have opened their bid commitment
    ///         and cannot be in the running to win the auction.
    /// @param tokenContract The address of the ERC721 contract for the asset
    ///        that was auctioned.
    /// @param tokenId The ERC721 token ID of the asset that was auctioned.
    /// @param auctionIndex The index of the auction that was being bid on.
    function withdrawCollateral(
        address tokenContract,
        uint256 tokenId,
        uint64 auctionIndex
    ) external {}

    /// @notice Gets the parameters and state of an auction in storage.
    /// @param tokenContract The address of the ERC721 contract for the asset auctioned.
    /// @param tokenId The ERC721 token ID of the asset auctioned.
    function getAuction(
        address tokenContract,
        uint256 tokenId
    ) external view returns (Auction memory auction) {}
}
