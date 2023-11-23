// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;
import "forge-std/console.sol";

contract VickreyAuction {
    event AssetTransferred(uint256 indexed assetId, address indexed newOwner);
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
    /// @param index Auctions selling the same asset
    struct Auction {
        address seller;
        uint32 startTime;
        uint32 endOfBiddingPeriod;
        uint32 endOfRevealPeriod;
        uint64 numUnrevealedBids;
        uint96 highestBid;
        uint96 secondHighestBid;
        address highestBidder;
        uint64 index;
        uint96 reservePrice;
    }

    /// @dev Representation of a bid in storage. Occupies one slot
    /// @param commitment The hash commitment of a bid value
    /// @param collateral The amount of collateral backing the bid
    struct Bid {
        bytes20 commitment;
        uint96 collateral;
    }

    /// @notice A mapping storing auction index and state
    mapping(uint256 => Auction) public auctions;

    /// @notice A mapping storing bid commitments and records of collateral,
    ///         indexed by item ID, auction index,
    ///         and bidder address. If the commitment is `bytes20(0)`, either
    ///         no commitment was made or the commitment was opened.
    mapping(uint256 => mapping(uint64 => mapping(address => Bid))) // item ID // Auction index // Bidder
        public bids;

    /// @notice Creates an auction for the given physical asset with the given
    ///         auction parameters.
    /// @param itemId The physical asset being auctioned.
    /// @param startTime The unix timestamp at which bidding can start.
    /// @param bidPeriod The duration of the bidding period, in seconds.
    /// @param revealPeriod The duration of the commitment reveal period,
    ///        in seconds.
    /// @param reservePrice The minimum price that the asset will be sold for.
    ///        If no bids exceed this price, the asset is returned to `seller`.
    function createAuction(
        uint256 itemId,
        uint32 startTime,
        uint32 bidPeriod,
        uint32 revealPeriod,
        uint96 reservePrice
    ) external {
        require(
            auctions[itemId].startTime == 0,
            "Auction already exists for this item"
        );
        require(
            startTime > block.timestamp,
            "Start time must be in the future"
        );
        require(bidPeriod > 0, "Bid period must be greater than zero");
        require(revealPeriod > 0, "Reveal period must be greater than zero");
        require(reservePrice > 0, "Reserve price must be greater than zero");
        auctions[itemId] = Auction({
            seller: msg.sender,
            startTime: startTime,
            endOfBiddingPeriod: startTime + bidPeriod,
            endOfRevealPeriod: startTime + bidPeriod + revealPeriod,
            numUnrevealedBids: 0,
            highestBid: reservePrice,
            secondHighestBid: reservePrice,
            highestBidder: address(0),
            index: 0,
            reservePrice: reservePrice
        });
    }

    /// @notice Commits to a bid on an item being auctioned. If a bid was
    ///         previously committed to, overwrites the previous commitment.
    ///         Value attached to this call is used as collateral for the bid.
    /// @param itemId The item ID of the asset being auctioned.
    /// @param commitment The commitment to the bid, computed as
    ///        `bytes20(keccak256(abi.encode(nonce, bidValue, tokenContract, tokenId, auctionIndex)))`.
    function commitBid(uint256 itemId, bytes20 commitment) external payable {
        Auction storage auction = auctions[itemId];
        require(auction.startTime > 0, "Auction does not exist for this item");
        require(
            block.timestamp >= auction.startTime,
            "Bidding has not started yet"
        );
        require(
            block.timestamp < auction.endOfRevealPeriod,
            "Bidding has ended"
        );
        require(msg.value > 0, "Collateral must be sent with the bid");
        Bid storage bid = bids[itemId][auction.index][msg.sender];
        bid.commitment = commitment;
        bid.collateral = uint96(msg.value);
    }

    /// @notice Reveals the value of a bid that was previously committed to.
    /// @param itemId The item ID of the asset being auctioned.
    /// @param bidValue The value of the bid.
    /// @param nonce The random input used to obfuscate the commitment.
    function revealBid(
        uint256 itemId,
        uint96 bidValue,
        bytes32 nonce
    ) external {
        Auction storage auction = auctions[itemId];
        Bid storage bid = bids[itemId][auction.index][msg.sender];
        require(auction.startTime > 0, "Auction does not exist for this item");
        require(
            block.timestamp >= auction.endOfBiddingPeriod,
            "Reveal period has not started yet"
        );
        require(
            block.timestamp < auction.endOfRevealPeriod,
            "Reveal period has ended"
        );
        require(
            bid.commitment != bytes20(0),
            "No previous bid commitment found"
        );
        require(
            bid.commitment == bytes20(keccak256(abi.encode(nonce, bidValue))),
            "Revealed bid does not match the commitment"
        );
        require(
            bid.collateral >= bidValue,
            "Collateral must be at least equal to the bid value"
        );
        if (bidValue > auction.highestBid) {
            auction.secondHighestBid = auction.highestBid;
            auction.highestBid = bidValue;
            auction.highestBidder = msg.sender;
        } else if (bidValue > auction.secondHighestBid) {
            auction.secondHighestBid = bidValue;
        }
    }

    /// @notice Ends an active auction. Can only end an auction if the bid reveal
    ///         phase is over, or if all bids have been revealed. Disburses the auction
    ///         proceeds to the seller. Transfers the auctioned asset to the winning
    ///         bidder and returns any excess collateral. If no bidder exceeded the
    ///         auction's reserve price, returns the asset to the seller.
    /// @param itemId The item ID of the asset auctioned.
    function endAuction(uint256 itemId) external {
        Auction storage auction = auctions[itemId];
        require(auction.startTime > 0, "Auction does not exist for this item");
        require(
            block.timestamp >= auction.endOfRevealPeriod,
            "Bid reveal phase is not over yet"
        );
        address winningBidder = auction.highestBidder;
        if (winningBidder != address(0)) {
            uint96 secondHighestBid = auction.secondHighestBid;
            uint96 paymentAmount = secondHighestBid;
            Bid storage winnerBid = bids[itemId][auction.index][winningBidder];
            payable(auction.seller).transfer(paymentAmount);
            emit AssetTransferred(itemId, winningBidder);
            payable(winningBidder).transfer(
                winnerBid.collateral - paymentAmount
            );
            winnerBid.collateral = 0;
        } else {
            emit AssetTransferred(itemId, auction.seller);
        }
    }

    /// @notice Withdraws collateral. Bidder must have opened their bid commitment
    ///         and cannot be in the running to win the auction.
    /// @param itemId The item ID of the asset that was auctioned.
    /// @param auctionIndex The index of the auction that was being bid on.
    function withdrawCollateral(uint256 itemId, uint64 auctionIndex) external {
        Auction storage auction = auctions[itemId];
        require(auction.startTime > 0, "Auction does not exist for this item");
        require(
            block.timestamp >= auction.endOfRevealPeriod,
            "Bid reveal phase is not over yet"
        );
        address bidder = msg.sender;
        require(
            bidder != auction.highestBidder,
            "Winning bidder cannot withdraw collateral"
        );
        Bid storage bid = bids[itemId][auctionIndex][bidder];
        require(bid.commitment != bytes20(0), "Bidder has not committed a bid");
        require(bid.collateral > 0, "Collateral is already withdrawn");
        payable(bidder).transfer(bid.collateral);
        bid.collateral = 0;
    }

    /// @notice Gets the parameters and state of an auction in storage.
    /// @param itemId The item ID of the asset auctioned.
    function getAuction(
        uint256 itemId
    ) external view returns (Auction memory auction) {
        auction = auctions[itemId];
        require(auction.startTime > 0, "Auction does not exist for this item");
        string memory logMessage = "success";
        console.logString(logMessage);
        return auction;
    }

    function getBid(
        uint256 itemId,
        uint64 index,
        address bidder
    ) public view returns (bytes20, uint96) {
        return (
            bids[itemId][index][bidder].commitment,
            bids[itemId][index][bidder].collateral
        );
    }
}
