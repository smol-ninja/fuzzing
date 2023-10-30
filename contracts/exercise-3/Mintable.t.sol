// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Mintable.sol";

/// @dev Run the template with
///      ```
///      solc-select use 0.8.0
///      echidna program-analysis/echidna/exercises/exercise3/template.sol --contract TestToken
///      ```
contract TestMintable is MintableToken {
    address echidna = msg.sender;
    int256 totalMintable_ = 10000;

    // update the constructor
    constructor() MintableToken(totalMintable_) {
        owner = echidna;
    }

    function echidna_test_balance() public view returns (bool) {
        // add the property
        /**
         * Call sequence:
         * 1.mint(115792089237316195423570985008687907853269984665640564039457584007913129629935)
         * comment: overflow vulnerability in mint()
         */
        return balances[echidna] <= 10000;
    }
}