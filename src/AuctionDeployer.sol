// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "./TokenizedVickeryAuction.sol";
import "./TokenizedVickeryAuctionV2.sol";

contract AuctionDeployer {
    address public proxyAdminAddress;
    address public auctionProxyAddress;
    address public auctionLogicV1;
    address public auctionLogicV2;
    ProxyAdmin public proxyAdmin;

    constructor() {
        auctionLogicV1 = address(new TokenizedVickeryAuction());
        auctionLogicV2 = address(new TokenizedVickeryAuctionV2());

        proxyAdmin = new ProxyAdmin();
        proxyAdminAddress = address(proxyAdmin);

        bytes memory initData = "";
        TransparentUpgradeableProxy auctionProxy = new TransparentUpgradeableProxy(
                auctionLogicV1,
                proxyAdminAddress,
                initData
            );
        auctionProxyAddress = address(auctionProxy);
    }

    function upgradeToV2() public {
        require(msg.sender == proxyAdminAddress, "Only admin can upgrade");

        TransparentUpgradeableProxy proxyInstance = TransparentUpgradeableProxy(
            payable(auctionProxyAddress)
        );
        proxyAdmin.upgrade(proxyInstance, auctionLogicV2);
    }
}
