// SPDX-License-Identifier:
pragma solidity ^0.8.0;

import "./Token.sol";

/// @dev Run the template with
///      ```
///      solc-select use 0.8.0
///      echidna program-analysis/echidna/exercises/exercise4/template.sol --contract TestToken --test-mode assertion
///      ```
contract TestToken is Token {
    function test_transfer(address to, uint256 value) public {
        // include `assert(condition)` statements that
        // detect a breaking invariant on a transfer.
        uint256 senderBalance = balances[msg.sender];
        uint256 recipientBalance = balances[to];

        super.transfer(to, value);

        assert(balances[msg.sender] <= senderBalance);
        assert(balances[to] >= recipientBalance);
    }
}