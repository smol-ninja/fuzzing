// SPDX-License-Identifier: UNLICENSED
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
        balances[echidna] = 10000;
    }

    function echidna_test_balance() public view returns (bool) {
        // add the property
        /**
         *  Call sequence:
         *  1.transfer(0x2fffffffd,115765784617545820972138066965335662155749220024220347647371619785953704469996)
         *  comment: sending a large value to `transfer()` can change the condition. Probably an overflow vulnerability.
         */
        return balances[echidna] <= 10000;
    }
}