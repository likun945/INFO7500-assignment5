// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {TokenizedVickeryAuction} from "../src/TokenizedVickeryAuction.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {MockERC721} from "../src/MockERC721.sol";
import "forge-std/console.sol";

contract TokenizedVickeryAuctionTest is Test {
    TokenizedVickeryAuction public auction;
    MockERC20 token;
    MockERC721 public nft;
    function setUp() public {
        auction = new TokenizedVickeryAuction();
        token = new MockERC20("MockToken", "MTK");
        nft = new MockERC721("MockNFT", "MNFT");
        token.mint(address(this), 1000 ether);
        nft.mint(address(this));
    }

}