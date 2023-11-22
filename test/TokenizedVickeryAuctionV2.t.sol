// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {TokenizedVickeryAuctionV2} from "../src/TokenizedVickeryAuctionV2.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {MockERC721} from "../src/MockERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract TokenizedVickeryAuctionV2Test is Test {
    TokenizedVickeryAuctionV2 public auctionV2;
    MockERC20 public token;
    MockERC721 public nft;
    address blacklistedSeller = vm.addr(3);
    address seller = vm.addr(2);
    uint96 reservePrice = 100;
    uint32 startTime = 60;
    uint32 bidPeriod = 300;
    uint32 revealPeriod = 120;
    uint256 tokenId = 0;
    address addressOfErc20Token;
    address addressOfNFT;

    function setUp() public {
        auctionV2 = new TokenizedVickeryAuctionV2();
        token = new MockERC20("MockToken", "MTK");
        nft = new MockERC721("MockNFT", "MNFT");
        nft.mint(address(seller));
        nft.mint(address(blacklistedSeller));
        vm.startPrank(seller);
        nft.approve(address(auctionV2), tokenId);
        vm.startPrank(blacklistedSeller);
        nft.approve(address(auctionV2), tokenId + 1);
        vm.stopPrank();
        addressOfErc20Token = address(token);
        addressOfNFT = address(nft);
    }

    function test_CreateAuction_NormalSeller() public {
        vm.startPrank(seller);
        auctionV2.createAuction(
            addressOfNFT,
            tokenId,
            addressOfErc20Token,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
        vm.stopPrank();
        TokenizedVickeryAuctionV2.Auction memory createdAuction = auctionV2
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

    function test_CreateAuction_BlacklistedSeller() public {
        auctionV2.blacklistSeller(blacklistedSeller);
        vm.startPrank(blacklistedSeller);
        vm.expectRevert("Seller is blacklisted");
        auctionV2.createAuction(
            addressOfNFT,
            tokenId + 1,
            addressOfErc20Token,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
        vm.stopPrank();
    }

    function test_CreateAuction_AfterBlacklistRemoval() public {
        auctionV2.blacklistSeller(blacklistedSeller);
        auctionV2.removeSellerFromBlacklist(blacklistedSeller);

        vm.startPrank(blacklistedSeller);
        auctionV2.createAuction(
            addressOfNFT,
            tokenId + 1,
            addressOfErc20Token,
            startTime,
            bidPeriod,
            revealPeriod,
            reservePrice
        );
        vm.stopPrank();
                TokenizedVickeryAuctionV2.Auction memory createdAuction = auctionV2
            .getAuction(addressOfNFT, tokenId + 1);
        assertEq(createdAuction.seller, blacklistedSeller);
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
}
