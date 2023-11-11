// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {HelloWorld} from "../src/HelloWorld.sol";

contract HelloWorldTest is Test {
    HelloWorld public helloWorld;

    function setUp() public {
        string memory initialMessage = "Hello, World!";
        helloWorld = new HelloWorld(initialMessage);
    }

    function test_SetGreeting() public {
        string memory newMessage = "Hello, Blockchain!";
        helloWorld.setGreeting(newMessage);
        string memory greeting = helloWorld.greetingMessage();
        string memory expectedGreeting = "Hello, Blockchain!";
        assertEq(greeting, expectedGreeting);
    }
}