// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VickreyAuction} from "../src/VickreyAuction.sol";

contract VickreyAuctionTest is Test {
    VickreyAuction public auction;

    function setUp() public {
        auction = new VickreyAuction();
    }

    function test_CreateAuction() public {
        uint256 itemId = 1;
        uint32 startTime = uint32(block.timestamp + 60); // Starts in 1 minute
        uint32 bidPeriod = 300; // 5 minutes
        uint32 revealPeriod = 120; // 2 minutes
        uint96 reservePrice = 100;

        auction.createAuction(itemId, startTime, bidPeriod, revealPeriod, reservePrice);

        VickreyAuction.Auction memory createdAuction = auction.getAuction(itemId);
        assertEq(createdAuction.startTime, startTime);
        assertEq(createdAuction.endOfBiddingPeriod, startTime + bidPeriod);
        assertEq(createdAuction.endOfRevealPeriod, startTime + bidPeriod + revealPeriod);
        assertEq(createdAuction.reservePrice, reservePrice);
    }

    // function test_CommitBid() public {
    //     uint256 itemId = 1;
    //     bytes20 commitment = 0x1234567890123456789012345678901234567890;
    //     uint256 collateral = 200;

    //     auction.commitBid(itemId, commitment, {value: collateral});

    //     VickreyAuction.Bid memory bid = auction.bids(itemId, 0, msg.sender);
    //     assertEq(bid.commitment, commitment);
    //     assertEq(bid.collateral, collateral);
    // }
}
