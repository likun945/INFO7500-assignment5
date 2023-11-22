// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "../src/AuctionDeployer.sol";
import "../src/TokenizedVickeryAuction.sol";
import "../src/TokenizedVickeryAuctionV2.sol";
import "forge-std/console.sol";

contract AuctionDeployerTest is Test {
    AuctionDeployer public deployer;
    address public proxyAdminAddress;
    address public auctionProxyAddress;
    TokenizedVickeryAuction public v1;
    TokenizedVickeryAuctionV2 public v2;

    function setUp() public {
        deployer = new AuctionDeployer();
        proxyAdminAddress = deployer.proxyAdminAddress();
        auctionProxyAddress = deployer.auctionProxyAddress();

        v1 = TokenizedVickeryAuction(deployer.auctionLogicV1());
        v2 = TokenizedVickeryAuctionV2(deployer.auctionLogicV2());
    }

    function test_InitialLogicIsV1() public {
        address payable payableProxyAddress = payable(auctionProxyAddress);

        TransparentUpgradeableProxy proxyInstance = TransparentUpgradeableProxy(
            payableProxyAddress
        );
        address currentLogic = ProxyAdmin(proxyAdminAddress)
            .getProxyImplementation(proxyInstance);
        assertEq(currentLogic, address(v1), "Initial logic is not V1");
    }

    function test_UpgradeToV2() public {
        vm.prank(proxyAdminAddress);
        deployer.upgradeToV2();

        address payable payableProxyAddress = payable(auctionProxyAddress);
        TransparentUpgradeableProxy proxyInstance = TransparentUpgradeableProxy(
            payableProxyAddress
        );
        address currentLogic = ProxyAdmin(proxyAdminAddress)
            .getProxyImplementation(proxyInstance);
        assertEq(currentLogic, address(v2), "Initial logic is not V1");
    }

    function test_UpgradeToV2_NotAdmin() public {
        vm.expectRevert("Only admin can upgrade");
        deployer.upgradeToV2();
    }
}
