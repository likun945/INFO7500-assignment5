// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract HelloWorld {
    string public greetingMessage;

    constructor(string memory initialMessage) {
        greetingMessage = initialMessage;
    }

    function setGreeting(string memory newMessage) public {
        greetingMessage = newMessage;
    }
}
