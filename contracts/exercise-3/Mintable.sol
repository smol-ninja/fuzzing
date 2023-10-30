// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Token.sol";

contract MintableToken is Token {
    int256 public totalMinted;
    int256 public totalMintable;

    constructor(int256 totalMintable_) {
        totalMintable = totalMintable_;
    }

    function mint(uint256 value) public onlyOwner {
        // casting uint256 to int256 can lead to arithmetic errors. check that value is less than type(int256).max
        require(value <= uint256(type(int256).max));
        require(int256(value) + totalMinted < totalMintable);
        totalMinted += int256(value);

        balances[msg.sender] += value;
    }
}