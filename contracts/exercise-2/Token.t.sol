// SPDX-License-Identifier:
pragma solidity ^0.8.0;

import "./Token.sol";

/// @dev Run the template with
///      ```
///      solc-select use 0.8.0
///      echidna program-analysis/echidna/exercises/exercise1/template.sol
///      ```
contract TestToken is Token {
    address echidna = tx.origin;

    constructor() {
        pause(); // pause the contract
        owner = address(0); // lose ownership
    }

    function echidna_test_balance() public view returns (bool) {
        // add the property
        return paused() == true;
    }
}