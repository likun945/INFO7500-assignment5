// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {TokenizedVickeryAuction} from "../src/TokenizedVickeryAuction.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {MockERC721} from "../src/MockERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract TokenizedVickeryAuctionTest is Test {
    TokenizedVickeryAuction public auction;
    MockERC20 public token;
    MockERC721 public nft;
    address bidderAddress = vm.addr(1);
    address seller = vm.addr(2);
    uint96 reservePrice = 100;
    uint32 startTime = 60;
    uint32 bidPeriod = 300;
    uint32 revealPeriod = 120;
    uint256 tokenId = 0;
    address addressOfErc20Token;
    address addressOfNFT;
    bytes32 nonce0 =
        0x1234567890123456789012345678901234567890123456789012345678901234;
    bytes32 nonce1 =
        0x1234567890123456789012345678901234567890123456789012345678901235;
    address constant bidder0 =
        address(0x742d35Cc6634C0532925a3b844Bc454e4438f44e);
    address constant bidder1 =
        address(0x4E943da844cbe1503F13499ba8d5FD70f1eEF272);
    uint96 bidValue0 = 500;
    uint96 bidValue1 = 300;
    uint96 initialBalance = 1000;

    function setUp() public {
        auction = new TokenizedVickeryAuction();
        token = new MockERC20("MockToken", "MTK");
        nft = new MockERC721("MockNFT", "MNFT");
        token.mint(bidder0, initialBalance * 1 ether);
        token.mint(bidder1, initialBalance * 1 ether);
        nft.mint(address(seller));
        nft.mint(address(seller));
        vm.startPrank(seller);
        nft.approve(address(auction), tokenId);
        nft.approve(address(auction), tokenId+1);
        vm.stopPrank();
        addressOfErc20Token = address(token);
        addressOfNFT = address(nft);
    }

    function setUp_createAuction() public {
        vm.startPrank(seller);
        auction.createAuction(
            addressOfNFT,
            tokenId,
            addressOfErc20Token,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
        vm.stopPrank();
    }

    function setUp_commitBid(
        address someAddress,
        bytes32 nonce,
        uint96 bidValue
    ) public {
        bytes20 commitment = bytes20(
            keccak256(abi.encode(nonce, bidValue, address(nft), tokenId, 1))
        );
        uint256 collateral = bidValue;
        vm.warp(block.timestamp + 61);
        vm.startPrank(someAddress);
        token.approve(address(auction), 1000 ether);
        auction.commitBid(address(nft), tokenId, commitment, collateral);
    }

    function setUp_endAuction() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);
        setUp_commitBid(bidder1, nonce1, bidValue1);

        vm.warp(361);
        vm.startPrank(bidder0);
        auction.revealBid(address(nft), tokenId, bidValue0, nonce0);
        vm.stopPrank();

        vm.startPrank(bidder1);
        auction.revealBid(address(nft), tokenId, bidValue1, nonce1);
        vm.stopPrank();

        vm.warp(block.timestamp + revealPeriod + 1);
        auction.endAuction(address(nft), tokenId);
    }

    function test_CreateAuction() public {
        vm.startPrank(seller);
        auction.createAuction(
            addressOfNFT,
            tokenId,
            addressOfErc20Token,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
        vm.stopPrank();
        TokenizedVickeryAuction.Auction memory createdAuction = auction
            .getAuction(addressOfNFT, tokenId);
        assertEq(createdAuction.seller, seller);
        assertEq(createdAuction.startTime, startTime);
        assertEq(createdAuction.endOfBiddingPeriod, startTime + bidPeriod);
        assertEq(
            createdAuction.endOfRevealPeriod,
            startTime + bidPeriod + revealPeriod
        );
        assertEq(createdAuction.numUnrevealedBids, 0);
        assertEq(createdAuction.highestBid, reservePrice);
        assertEq(createdAuction.secondHighestBid, reservePrice);
        assertEq(createdAuction.highestBidder, address(0));
        assertEq(createdAuction.index, 1);
        assertEq(createdAuction.erc20Token, addressOfErc20Token);
    }

    function test_CreateAuction_ErrorAuctionExists() public {
        setUp_createAuction();
        vm.expectRevert("An active auction already exists for this item");
        setUp_createAuction();
    }

    function test_CreateAuction_StartTimeInPast() public {
        startTime = uint32(block.timestamp - 1);
        vm.expectRevert("Start time must be in the future");
        auction.createAuction(
            addressOfNFT,
            tokenId,
            addressOfErc20Token,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
    }

    function test_CreateAuction_ZeroBidPeriod() public {
        bidPeriod = 0;
        vm.expectRevert("Bid period must be greater than zero");
        auction.createAuction(
            addressOfNFT,
            tokenId,
            addressOfErc20Token,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
    }

    function test_CreateAuction_ZeroRevealPeriod() public {
        revealPeriod = 0;
        vm.expectRevert("Reveal period must be greater than zero");
        auction.createAuction(
            addressOfNFT,
            tokenId,
            addressOfErc20Token,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
    }

    function test_CreateAuction_ZeroReservePrice() public {
        reservePrice = 0;
        vm.expectRevert("Reserve price must be greater than zero");
        auction.createAuction(
            addressOfNFT,
            tokenId,
            addressOfErc20Token,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
    }

    function test_CreateAuction_NotOwner() public {
        vm.expectRevert("Caller is not the token owner");
        auction.createAuction(
            addressOfNFT,
            tokenId,
            addressOfErc20Token,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
    }

    function test_CommitBid() public {
        setUp_createAuction();
        token.mint(bidderAddress, 1000 ether);

        vm.startPrank(bidderAddress);
        token.approve(address(auction), 1000 ether);

        bytes20 commitment = bytes20(
            keccak256(abi.encode(1, 1000, address(nft), tokenId, 1))
        );
        uint256 collateral = 1000;

        vm.warp(block.timestamp + 61);
        auction.commitBid(address(nft), tokenId, commitment, collateral);

        (bytes20 bid_commitment, uint96 bid_collateral) = auction.getBid(
            address(nft),
            tokenId,
            1,
            bidderAddress
        );
        assertEq(bid_commitment, commitment);
        assertEq(bid_collateral, collateral);

        vm.stopPrank();
    }

    function test_CommitBid_AuctionDoesNotExist() public {
        bytes20 commitment = bytes20(
            0x1234567890123456789012345678901234567890
        );
        uint256 collateral = 200;
        address someAddress = address(
            0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        );
        vm.startPrank(someAddress);
        vm.expectRevert("Auction does not exist for this item");
        auction.commitBid(address(nft), tokenId, commitment, collateral);
    }

    function test_CommitBid_BiddingNotStarted() public {
        setUp_createAuction();
        bytes20 commitment = bytes20(
            0x1234567890123456789012345678901234567890
        );
        uint256 collateral = 200;
        address someAddress = address(
            0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        );
        vm.expectRevert("Bidding has not started yet");
        vm.startPrank(someAddress);
        auction.commitBid(address(nft), tokenId, commitment, collateral);
    }

    function test_CommitBid_BiddingEnded() public {
        setUp_createAuction();
        bytes20 commitment = bytes20(
            0x1234567890123456789012345678901234567890
        );
        uint256 collateral = 200;
        vm.expectRevert("Bidding has ended");
        vm.warp(block.timestamp + 481);
        auction.commitBid(address(nft), tokenId, commitment, collateral);
    }

    function test_CommitBid_NoCollateralSent() public {
        setUp_createAuction();
        bytes20 commitment = bytes20(
            0x1234567890123456789012345678901234567890
        );
        vm.warp(block.timestamp + 61);
        vm.expectRevert("Collateral must be sent with the bid");
        auction.commitBid(address(nft), tokenId, commitment, 0);
    }

    function test_RevealBid() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);
        setUp_commitBid(bidder1, nonce1, bidValue1);

        vm.warp(block.timestamp + bidPeriod + 1);

        vm.startPrank(bidder0);
        auction.revealBid(address(nft), tokenId, bidValue0, nonce0);
        vm.stopPrank();

        vm.startPrank(bidder1);
        auction.revealBid(address(nft), tokenId, bidValue1, nonce1);
        vm.stopPrank();

        TokenizedVickeryAuction.Auction memory auction_info = auction
            .getAuction(address(nft), tokenId);
        assertEq(auction_info.highestBidder, bidder0);
        assertEq(auction_info.highestBid, bidValue0);
        assertEq(auction_info.secondHighestBid, bidValue1);
    }

    function test_RevealBid_AuctionDoesNotExist() public {
        vm.startPrank(bidder0);
        vm.expectRevert("Auction does not exist for this item");
        auction.revealBid(address(nft), tokenId, bidValue0, nonce0);
    }

    function test_RevealBid_RevealPeriodNotStarted() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);
        setUp_commitBid(bidder1, nonce1, bidValue1);
        vm.startPrank(bidder0);
        vm.expectRevert("Reveal period has not started yet");
        auction.revealBid(address(nft), tokenId, bidValue0, nonce0);
    }

    function test_RevealBid_RevealPeriodEnded() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);
        vm.warp(block.timestamp + bidPeriod + 1);

        vm.startPrank(bidder0);
        auction.revealBid(address(nft), tokenId, bidValue0, nonce0);
        vm.stopPrank();

        vm.warp(block.timestamp + 481);
        vm.expectRevert("Reveal period has ended");
        auction.revealBid(address(nft), tokenId, bidValue0, nonce0);
    }

    function test_RevealBid_NoPreviousCommitment() public {
        setUp_createAuction();
        vm.expectRevert("No previous bid commitment found");
        vm.warp(block.timestamp + 361);
        vm.startPrank(bidder0);
        auction.revealBid(address(nft), tokenId, bidValue0, nonce0);
    }

    function test_RevealBid_BidMismatch() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);
        vm.expectRevert("Revealed bid does not match the commitment");
        vm.warp(block.timestamp + 361);
        vm.startPrank(bidder0);
        auction.revealBid(address(nft), tokenId, bidValue0, nonce1);
    }

    function test_RevealBid_CollateralSufficient() public {
        setUp_createAuction();
        bytes20 commitment = bytes20(
            keccak256(abi.encode(nonce0, 500, address(nft), tokenId, 1))
        );
        uint256 collateral = 200;
        vm.warp(block.timestamp + 61);
        vm.startPrank(bidder0);
        token.approve(address(auction), 1000 ether);
        auction.commitBid(address(nft), tokenId, commitment, collateral);

        vm.expectRevert("Collateral must be at least equal to the bid value");
        vm.warp(block.timestamp + 361);
        auction.revealBid(address(nft), tokenId, bidValue0, nonce0);
    }

    function test_endAuction_ErrorAuctionExists() public {
        vm.expectRevert("Auction does not exist for this item");
        auction.endAuction(addressOfNFT, tokenId);
    }

    function test_endAuction_revealPeriodNotOver() public {
        setUp_createAuction();
        vm.warp(479);
        vm.expectRevert("Bid reveal phase is not over yet");
        auction.endAuction(addressOfNFT, tokenId);
    }

    function test_EndAuction() public {
        setUp_createAuction();
        setUp_commitBid(bidder0, nonce0, bidValue0);
        setUp_commitBid(bidder1, nonce1, bidValue1);

        vm.warp(block.timestamp + bidPeriod + 1);
        vm.startPrank(bidder0);
        auction.revealBid(address(nft), tokenId, bidValue0, nonce0);
        vm.stopPrank();

        vm.startPrank(bidder1);
        auction.revealBid(address(nft), tokenId, bidValue1, nonce1);
        vm.stopPrank();

        vm.warp(block.timestamp + revealPeriod + 1);

        vm.expectEmit(true, true, true, true);
        emit AuctionEnded(address(nft), tokenId, bidder0, bidValue1);
        auction.endAuction(address(nft), tokenId);
        assertEq(
            IERC721(address(nft)).ownerOf(tokenId),
            bidder0,
            "NFT ownership not transferred correctly"
        );
        assertEq(
            IERC20(address(token)).balanceOf(bidder0),
            initialBalance * 1 ether - bidValue1,
            "Incorrect refund to winning bidder"
        );
        assertEq(
            IERC20(address(token)).balanceOf(seller),
            bidValue1,
            "Incorrect payment to seller"
        );

        vm.warp(1);
        tokenId = 1;
        setUp_createAuction();

        vm.warp(block.timestamp + startTime + bidPeriod + revealPeriod + 1);

        vm.expectEmit(true, true, true, true);
        emit AuctionEnded(address(nft), tokenId, address(0), 0);
        auction.endAuction(address(nft), tokenId);

        assertEq(
            IERC721(address(nft)).ownerOf(tokenId),
            seller,
            "NFT should be returned to the seller"
        );
    }

    function test_EndAuction_NoWinningBidder() public {
        setUp_createAuction();

        vm.warp(block.timestamp + startTime + bidPeriod + revealPeriod + 1);

        vm.expectEmit(true, true, true, true);
        emit AuctionEnded(address(nft), tokenId, address(0), 0);
        auction.endAuction(address(nft), tokenId);

        assertEq(
            IERC721(address(nft)).ownerOf(tokenId),
            seller,
            "NFT should be returned to the seller"
        );
    }

    function test_EndAuction_HighestEqualSecondHighestBid() public {
        setUp_createAuction();

        setUp_commitBid(bidder0, nonce0, bidValue0);
        setUp_commitBid(bidder1, nonce1, bidValue0);

        vm.warp(361);
        vm.startPrank(bidder0);
        auction.revealBid(address(nft), tokenId, bidValue0, nonce0);
        vm.stopPrank();

        vm.startPrank(bidder1);
        auction.revealBid(address(nft), tokenId, bidValue0, nonce1);
        vm.stopPrank();

        vm.warp(block.timestamp + startTime + bidPeriod + revealPeriod + 1);

        auction.endAuction(address(nft), tokenId);

        assertEq(
            IERC20(address(token)).balanceOf(bidder0),
            initialBalance * 1 ether - bidValue0,
            "Winning bidder should not receive a refund"
        );

        assertEq(
            IERC20(address(token)).balanceOf(seller),
            bidValue0,
            "Seller should receive the bid amount"
        );

        assertEq(
            IERC721(address(nft)).ownerOf(tokenId),
            bidder0,
            "NFT should be transferred to the winning bidder"
        );
    }

    function test_EndAuction_AllBidsBelowReserve() public {
        setUp_createAuction();

        uint96 lowBidValue0 = 50;
        uint96 lowBidValue1 = 80;
        setUp_commitBid(bidder0, nonce0, lowBidValue0);
        setUp_commitBid(bidder1, nonce1, lowBidValue1);
        vm.warp(361);
        vm.startPrank(bidder0);
        auction.revealBid(address(nft), tokenId, lowBidValue0, nonce0);
        vm.stopPrank();

        vm.startPrank(bidder1);
        auction.revealBid(address(nft), tokenId, lowBidValue1, nonce1);
        vm.stopPrank();

        vm.warp(block.timestamp + startTime + bidPeriod + revealPeriod + 1);
        vm.expectEmit(true, true, true, true);
        emit AuctionEnded(address(nft), tokenId, address(0), 0);
        auction.endAuction(address(nft), tokenId);

        assertEq(
            IERC721(address(nft)).ownerOf(tokenId),
            seller,
            "NFT should be returned to the seller"
        );
    }

    function test_EndAuction_OneBidAboveReserve_NoSecondBid() public {
        setUp_createAuction();
        uint96 highBidValue = reservePrice + 50;
        setUp_commitBid(bidder0, nonce0, highBidValue);

        vm.warp(361);
        vm.startPrank(bidder0);
        auction.revealBid(address(nft), tokenId, highBidValue, nonce0);
        vm.stopPrank();

        vm.warp(block.timestamp + startTime + bidPeriod + revealPeriod + 1);

        vm.expectEmit(true, true, true, true);
        emit AuctionEnded(address(nft), tokenId, bidder0, reservePrice);
        auction.endAuction(address(nft), tokenId);

        assertEq(
            IERC721(address(nft)).ownerOf(tokenId),
            bidder0,
            "NFT should be transferred to the highest bidder"
        );
        assertEq(
            IERC20(address(token)).balanceOf(bidder0),
            initialBalance * 1 ether - reservePrice,
            "Incorrect payment by the highest bidder"
        );
        assertEq(
            IERC20(address(token)).balanceOf(seller),
            reservePrice,
            "Seller should receive the reserve price"
        );
    }

    function test_withdrawCollateral() public {
        setUp_endAuction();
        uint64 auctionIndex = auction.getAuction(address(nft), tokenId).index;
        uint256 initialERC20Balance = IERC20(address(token)).balanceOf(bidder1);
        vm.startPrank(bidder1);
        auction.withdrawCollateral(address(nft), tokenId, auctionIndex);
        uint256 finalERC20Balance = IERC20(address(token)).balanceOf(bidder1);
        (, uint96 bid_collateral) = auction.getBid(
            address(nft),
            tokenId,
            auctionIndex,
            bidder1
        );

        assertEq(bid_collateral, 0, "Collateral should be withdrawn");
        assertEq(
            finalERC20Balance,
            initialERC20Balance + bidValue1,
            "Incorrect ERC20 balance after withdrawal"
        );
    }

    function test_withdrawCollateral_AuctionDoesNotExist() public {
        vm.expectRevert("Auction does not exist for this item");
        auction.withdrawCollateral(address(nft), tokenId, 1);
    }

    function test_withdrawCollateral_BidRevealPhaseNotOver() public {
        setUp_createAuction();
        vm.expectRevert("Bid reveal phase is not over yet");
        auction.withdrawCollateral(address(nft), tokenId, 1);
    }

    function test_withdrawCollateral_WinningBidderCannotWithdraw() public {
        setUp_endAuction();
        vm.startPrank(bidder0);
        vm.expectRevert("Winning bidder cannot withdraw collateral");
        auction.withdrawCollateral(address(nft), tokenId, 1);
    }

    function test_withdrawCollateral_BidderHasNotCommittedBid() public {
        setUp_endAuction();
        address bidder2 = vm.addr(3);
        vm.startPrank(bidder2);
        vm.expectRevert("Bidder has not committed a bid");
        auction.withdrawCollateral(address(nft), tokenId, 1);
    }

    function test_withdrawCollateral_CollateralAlreadyWithdrawn() public {
        setUp_endAuction();
        vm.startPrank(bidder1);
        auction.withdrawCollateral(address(nft), tokenId, 1);
        vm.expectRevert("Collateral is already withdrawn");
        auction.withdrawCollateral(address(nft), tokenId, 1);
    }

    function test_GetAuction_NotExist() public {
        vm.expectRevert("Auction does not exist for this item");
        auction.getAuction(addressOfNFT, tokenId + 1);
    }

    function test_InitializeFunction() public {
        vm.prank(address(this)); 
        auction.initialize();
    }

    event AuctionEnded(
        address indexed tokenContract,
        uint256 indexed tokenId,
        address indexed winner,
        uint96 winningBid
    );
}
