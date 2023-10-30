// SPDX-License-Identifier:
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
    constructor() public MintableToken(totalMintable_) {
        owner = echidna;
    }

    function echidna_test_balance() public view returns (bool) {
        // add the property
        return balances[echidna] <= 10000;
    }
}