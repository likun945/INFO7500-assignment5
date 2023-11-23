// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VickreyAuction} from "../src/VickreyAuction.sol";
import "forge-std/console.sol";

contract VickreyAuctionTest is Test {
    VickreyAuction public auction;
    address constant seller = address(0);
    address constant bidder0 =
        address(0x742d35Cc6634C0532925a3b844Bc454e4438f44e);
    address constant bidder1 =
        address(0x4E943da844cbe1503F13499ba8d5FD70f1eEF272);
    address constant contract_addr = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    bytes32 nonce0 =
        0x1234567890123456789012345678901234567890123456789012345678901234;
    bytes32 nonce1 =
        0x1234567890123456789012345678901234567890123456789012345678901235;
    uint96 bidValue0 = 500;
    uint96 bidValue1 = 300;
    uint96 reservePrice = 100;

    function setUp() public {
        auction = new VickreyAuction();
        vm.deal(bidder0, 1000);
        vm.deal(bidder1, 1000);
    }

    function setUp_createAuction() public {
        uint256 itemId = 1;
        uint32 startTime = uint32(block.timestamp + 60);
        uint32 bidPeriod = 300;
        uint32 revealPeriod = 120;
        vm.prank(seller);
        auction.createAuction(
            itemId,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
    }

    function setUp_commitBid(
        address someAddress,
        bytes32 nonce,
        uint96 bidValue
    ) public {
        bytes20 commitment = bytes20(keccak256(abi.encode(nonce, bidValue)));
        uint256 collateral = bidValue;
        vm.startPrank(someAddress);
        vm.warp(block.timestamp + 61);
        auction.commitBid{value: collateral}(1, commitment);
    }

    function test_CreateAuction() public {
        uint256 itemId = 1;
        uint32 startTime = uint32(block.timestamp + 60);
        uint32 bidPeriod = 300;
        uint32 revealPeriod = 120;
        auction.createAuction(
            itemId,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
        VickreyAuction.Auction memory createdAuction = auction.getAuction(
            itemId
        );
        assertEq(createdAuction.seller, address(this));
        assertEq(createdAuction.startTime, startTime);
        assertEq(createdAuction.endOfBiddingPeriod, startTime + bidPeriod);
        assertEq(
            createdAuction.endOfRevealPeriod,
            startTime + bidPeriod + revealPeriod
        );
        assertEq(createdAuction.reservePrice, reservePrice);
        assertEq(createdAuction.highestBid, reservePrice);
        assertEq(createdAuction.secondHighestBid, reservePrice);
        assertEq(createdAuction.highestBidder, address(0));
        assertEq(createdAuction.index, 0);
    }

    function test_CreateAuction_ErrorAuctionExists() public {
        uint256 itemId = 1;
        uint32 startTime = uint32(block.timestamp + 60);
        uint32 bidPeriod = 300;
        uint32 revealPeriod = 120;
        auction.createAuction(
            itemId,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
        vm.expectRevert("Auction already exists for this item");
        auction.createAuction(
            itemId,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
    }

    function test_CreateAuction_StartTimeInPast() public {
        uint256 itemId = 1;
        uint32 startTime = uint32(block.timestamp - 1);
        uint32 bidPeriod = 300;
        uint32 revealPeriod = 120;
        vm.expectRevert("Start time must be in the future");
        auction.createAuction(
            itemId,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
    }

    function test_CreateAuction_ZeroBidPeriod() public {
        uint256 itemId = 1;
        uint32 startTime = uint32(block.timestamp + 60);
        uint32 bidPeriod = 0;
        uint32 revealPeriod = 120;
        vm.expectRevert("Bid period must be greater than zero");
        auction.createAuction(
            itemId,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
    }

    function test_CreateAuction_ZeroRevealPeriod() public {
        uint256 itemId = 1;
        uint32 startTime = uint32(block.timestamp + 60);
        uint32 bidPeriod = 300;
        uint32 revealPeriod = 0;
        vm.expectRevert("Reveal period must be greater than zero");
        auction.createAuction(
            itemId,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
    }

    function test_CreateAuction_ZeroReservePrice() public {
        uint256 itemId = 1;
        uint32 startTime = uint32(block.timestamp + 60);
        uint32 bidPeriod = 300;
        uint32 revealPeriod = 120;
        reservePrice = 0;
        vm.expectRevert("Reserve price must be greater than zero");
        auction.createAuction(
            itemId,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
    }

    function test_CommitBid() public {
        uint256 itemId = 1;
        bytes20 commitment = bytes20(
            0x1234567890123456789012345678901234567890
        );
        uint256 collateral = 200;
        address someAddress = address(
            0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        );
        vm.startPrank(someAddress);
        auction.createAuction(
            itemId,
            uint32(block.timestamp + 60),
            300,
            120,
            100
        );
        vm.warp(block.timestamp + 61);
        auction.commitBid{value: collateral}(itemId, commitment);
        (bytes20 bid_commitment, uint96 bid_collateral) = auction.getBid(
            itemId,
            0,
            someAddress
        );
        assertEq(bid_commitment, commitment);
        assertEq(bid_collateral, collateral);
    }

    function test_CommitBid_AuctionDoesNotExist() public {
        uint256 itemId = 1;
        bytes20 commitment = bytes20(
            0x1234567890123456789012345678901234567890
        );
        uint256 collateral = 200;
        address someAddress = address(
            0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        );
        vm.startPrank(someAddress);
        vm.expectRevert("Auction does not exist for this item");
        auction.commitBid{value: collateral}(itemId, commitment);
    }

    function test_CommitBid_BiddingNotStarted() public {
        uint256 itemId = 1;
        bytes20 commitment = bytes20(
            0x1234567890123456789012345678901234567890
        );
        uint256 collateral = 200;
        address someAddress = address(
            0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        );
        uint32 futureStartTime = uint32(block.timestamp + 60);
        auction.createAuction(itemId, futureStartTime, 300, 120, 100);
        vm.expectRevert("Bidding has not started yet");
        vm.startPrank(someAddress);
        auction.commitBid{value: collateral}(itemId, commitment);
    }

    function test_CommitBid_BiddingEnded() public {
        uint256 itemId = 1;
        bytes20 commitment = bytes20(
            0x1234567890123456789012345678901234567890
        );
        uint256 collateral = 200;
        address someAddress = address(
            0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        );
        vm.startPrank(someAddress);
        auction.createAuction(
            itemId,
            uint32(block.timestamp + 60),
            300,
            120,
            100
        );
        vm.expectRevert("Bidding has ended");
        vm.warp(block.timestamp + 481);
        auction.commitBid{value: collateral}(itemId, commitment);
    }

    function test_CommitBid_NoCollateralSent() public {
        uint256 itemId = 1;
        bytes20 commitment = bytes20(
            0x1234567890123456789012345678901234567890
        );
        address someAddress = address(
            0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        );
        vm.startPrank(someAddress);
        auction.createAuction(
            itemId,
            uint32(block.timestamp + 60),
            300,
            120,
            100
        );
        vm.warp(block.timestamp + 61);
        vm.expectRevert("Collateral must be sent with the bid");
        auction.commitBid(itemId, commitment);
    }

    function test_RevealBid_AuctionDoesNotExist() public {
        vm.startPrank(bidder0);
        vm.expectRevert("Auction does not exist for this item");
        auction.revealBid(1, 500, nonce0);
    }

    function test_RevealBid_RevealPeriodNotStarted() public {
        uint256 itemId = 1;
        uint96 bidValue = 500;
        bytes32 nonce = 0x1234567890123456789012345678901234567890123456789012345678901234;
        bytes20 commitment = bytes20(keccak256(abi.encode(nonce, bidValue)));
        auction.createAuction(
            itemId,
            uint32(block.timestamp + 60),
            300,
            120,
            100
        );
        vm.warp(block.timestamp + 61);
        auction.commitBid{value: 200}(itemId, commitment);
        vm.expectRevert("Reveal period has not started yet");
        auction.revealBid(itemId, bidValue, nonce);
    }

    function test_RevealBid_RevealPeriodEnded() public {
        uint256 itemId = 1;
        uint96 bidValue = 500;
        bytes32 nonce = 0x1234567890123456789012345678901234567890123456789012345678901234;
        bytes20 commitment = bytes20(keccak256(abi.encode(nonce, bidValue)));
        auction.createAuction(
            itemId,
            uint32(block.timestamp + 60),
            300,
            120,
            100
        );
        vm.warp(block.timestamp + 61);
        auction.commitBid{value: 200}(itemId, commitment);
        vm.expectRevert("Reveal period has ended");
        vm.warp(block.timestamp + 481);
        auction.revealBid(itemId, bidValue, nonce);
    }

    function test_RevealBid_NoPreviousCommitment() public {
        uint256 itemId = 1;
        uint96 bidValue = 500;
        bytes32 nonce = 0x1234567890123456789012345678901234567890123456789012345678901234;
        auction.createAuction(
            itemId,
            uint32(block.timestamp + 60),
            300,
            120,
            100
        );
        vm.expectRevert("No previous bid commitment found");
        vm.warp(block.timestamp + 360);
        auction.revealBid(itemId, bidValue, nonce);
    }

    function test_RevealBid_BidMismatch() public {
        uint256 itemId = 1;
        uint96 bidValue = 500;
        bytes32 nonce = 0x1234567890123456789012345678901234567890123456789012345678901234;
        bytes20 commitment = bytes20(
            keccak256(abi.encode(nonce, bidValue + 200))
        );
        auction.createAuction(
            itemId,
            uint32(block.timestamp + 60),
            300,
            120,
            100
        );
        vm.warp(block.timestamp + 61);
        auction.commitBid{value: 200}(itemId, commitment);
        vm.expectRevert("Revealed bid does not match the commitment");
        vm.warp(block.timestamp + 360);
        auction.revealBid(itemId, bidValue, nonce);
    }

    function test_RevealBid_CollateralSufficient() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);
        bytes20 commitment = bytes20(keccak256(abi.encode(nonce0, 500)));
        vm.startPrank(bidder0);
        vm.warp(block.timestamp + 61);
        auction.commitBid{value: 300}(1, commitment);
        vm.warp(361);
        vm.startPrank(bidder0);
        vm.expectRevert("Collateral must be at least equal to the bid value");
        auction.revealBid(1, bidValue0, nonce0);
    }

    function test_RevealBid() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);
        setUp_commitBid(bidder1, nonce1, bidValue1);

        vm.warp(361);
        vm.startPrank(bidder0);
        auction.revealBid(1, bidValue0, nonce0);

        vm.startPrank(bidder1);
        auction.revealBid(1, bidValue1, nonce1);

        VickreyAuction.Auction memory auction_info = auction.getAuction(1);
        assertEq(auction_info.highestBidder, bidder0);
        assertEq(auction_info.highestBid, bidValue0);
        assertEq(auction_info.secondHighestBid, bidValue1);
    }

    function test_endAuction_ErrorAuctionExists() public {
        vm.expectRevert("Auction does not exist for this item");
        auction.endAuction(1);
    }

    function test_endAuction_revealPeriodNotOver() public {
        setUp_createAuction();
        vm.warp(479);
        vm.expectRevert("Bid reveal phase is not over yet");
        auction.endAuction(1);
    }

    function test_endAuction() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);
        setUp_commitBid(bidder1, nonce1, bidValue1);
        vm.warp(361);
        vm.startPrank(bidder0);
        auction.revealBid(1, bidValue0, nonce0);

        vm.startPrank(bidder1);
        auction.revealBid(1, bidValue1, nonce1);

        vm.warp(481);
        vm.expectEmit(true, true, true, true);
        emit AssetTransferred(1, bidder0);
        auction.endAuction(1);

        uint256 winnerBalance = address(bidder0).balance;
        uint256 notWinnerBalance = address(bidder1).balance;
        uint256 sellerBalance = address(seller).balance;
        assertEq(winnerBalance, 1000 - bidValue1);
        assertEq(notWinnerBalance, 1000 - bidValue1);
        assertEq(sellerBalance, bidValue1);
    }

    function test_endAuction_noSecondHighestBid() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);

        vm.warp(361);
        vm.startPrank(bidder0);
        auction.revealBid(1, bidValue0, nonce0);

        vm.warp(481);
        auction.endAuction(1);
        uint256 winnerBalance = address(bidder0).balance;
        uint256 notWinnerBalance = address(bidder1).balance;
        uint256 sellerBalance = address(seller).balance;

        assertEq(winnerBalance, 1000 - reservePrice);
        assertEq(notWinnerBalance, 1000);
        assertEq(sellerBalance, reservePrice);
    }

    function test_endAuction_noHighestBid() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, 50);
        setUp_commitBid(bidder1, nonce1, 50);

        vm.warp(361);
        vm.startPrank(bidder0);
        auction.revealBid(1, 50, nonce0);

        vm.startPrank(bidder1);
        auction.revealBid(1, 50, nonce1);

        vm.warp(481);
        vm.expectEmit(true, true, true, true);
        emit AssetTransferred(1, seller);
        auction.endAuction(1);

        uint256 bidderBalance = address(bidder0).balance;
        uint256 sellerBalance = address(seller).balance;
        assertEq(bidderBalance, 950);
        assertEq(sellerBalance, 0);

        vm.startPrank(bidder0);
        auction.withdrawCollateral(1, 0);
        assertEq(address(bidder0).balance, 1000);
    }

    function test_withdrawCollateral() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);
        setUp_commitBid(bidder1, nonce1, bidValue1);

        vm.warp(361);
        vm.startPrank(bidder0);
        auction.revealBid(1, bidValue0, nonce0);

        vm.startPrank(bidder1);
        auction.revealBid(1, bidValue1, nonce1);

        vm.warp(481);
        auction.endAuction(1);

        vm.startPrank(bidder1);
        auction.withdrawCollateral(1, 0);
        uint256 bidderBalance = address(bidder1).balance;
        (, uint96 bid_collateral) = auction.getBid(1, 0, bidder1);
        assertEq(bid_collateral, 0);
        assertEq(bidderBalance, 1000);
    }

    function test_withdrawCollateral_AuctionDoesNotExist() public {
        vm.expectRevert("Auction does not exist for this item");
        auction.withdrawCollateral(1, 0);
    }

    function test_withdrawCollateral_BidRevealPhaseNotOver() public {
        setUp_createAuction();
        vm.expectRevert("Bid reveal phase is not over yet");
        auction.withdrawCollateral(1, 0);
    }

    function test_withdrawCollateral_WinningBidderCannotWithdraw() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);
        setUp_commitBid(bidder1, nonce1, bidValue1);

        vm.warp(361);
        vm.startPrank(bidder0);
        auction.revealBid(1, bidValue0, nonce0);

        vm.startPrank(bidder1);
        auction.revealBid(1, bidValue1, nonce1);

        vm.warp(481);
        auction.endAuction(1);

        vm.startPrank(bidder0);
        vm.expectRevert("Winning bidder cannot withdraw collateral");
        auction.withdrawCollateral(1, 0);
    }

    function test_withdrawCollateral_BidderHasNotCommittedBid() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);

        vm.warp(361);
        vm.startPrank(bidder0);
        auction.revealBid(1, bidValue0, nonce0);

        vm.warp(481);
        auction.endAuction(1);

        vm.startPrank(bidder1);
        vm.expectRevert("Bidder has not committed a bid");
        auction.withdrawCollateral(1, 1);
    }

    function test_withdrawCollateral_CollateralAlreadyWithdrawn() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);
        setUp_commitBid(bidder1, nonce1, bidValue1);

        vm.warp(361);
        vm.startPrank(bidder0);
        auction.revealBid(1, bidValue0, nonce0);

        vm.startPrank(bidder1);
        auction.revealBid(1, bidValue1, nonce1);

        vm.warp(481);
        auction.endAuction(1);

        vm.startPrank(bidder1);
        auction.withdrawCollateral(1, 0);
        vm.expectRevert("Collateral is already withdrawn");
        auction.withdrawCollateral(1, 0);
    }

    function test_GetAuction_NotExist() public {
        vm.expectRevert("Auction does not exist for this item");
        auction.getAuction(1);
    }

    event AssetTransferred(uint256 indexed assetId, address indexed newOwner);
}
