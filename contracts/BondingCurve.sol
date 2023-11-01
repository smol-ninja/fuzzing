// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC1820Registry } from "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";
import { IERC1363Receiver } from "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import { IERC1363Spender } from "@openzeppelin/contracts/interfaces/IERC1363Spender.sol";

// @notice BojackToken implements ERC20 and adds control over mint and burn by owner
contract BojackToken is ERC20 {
    error Unauthorized();
    error ZeroAddress();

    address private _saleManager;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _saleManager = _msgSender();
    }

    modifier onlySaleManager() {
        if (_msgSender() != _saleManager) revert Unauthorized();
        _;
    }

    function mint(address recipient, uint256 amount) public onlySaleManager {
        _mint(recipient, amount);
    }

    function burn(address account, uint256 amount) public onlySaleManager {
        _burn(account, amount);
    }

    function transferManager(address newManager) public onlySaleManager {
        if (newManager == address(0)) revert ZeroAddress();
        _saleManager = newManager;
    }
}

contract TokenSaleManager is IERC1363Receiver, IERC1363Spender {
    using SafeERC20 for BojackToken;
    using SafeERC20 for IERC20;

    IERC1820Registry internal constant _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    BojackToken public immutable token;

    // @notice RATIO = supply / price
    uint256 private constant RATIO = 100;
    // @notice set starting price to be 0, supports decimal prices
    uint256 internal _currentPrice;

    constructor() {
        token = new BojackToken("Bojack", "BOJ");

        // register interface for ERC777TokensRecipient
        // _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
    }

    // @return the current price of the token from the Bonding curve
    function getCurrentPrice() public view returns (uint256) {
        return _currentPrice;
    }

    // @dev this function is vulenerable to sandwich attack because of how bonding curve works.
    // @param TODO: maxAcceptablePrice the maximum acceptable price to users to mitigate risk of sandwich attacks
    // @param depositTokenAddress an ERC20 token that user wants to buy with
    // @param depositAmount amount of ERC20 token
    function buy(uint256 depositAmount, address depositTokenAddress) public {
        // transfer the token from sender address to sale manager address
        IERC20(depositTokenAddress).safeTransferFrom(msg.sender, address(this), depositAmount);

        _buy(msg.sender, depositAmount);
    }

    // @param depositTokenAddress an ERC20 token that user wants to buy with
    // @param depositAmount amount of ERC20 token
    // @param sender the address of the buyer
    function _buy(address sender, uint256 depositAmount) private {
        // loading _currentPrice in memory from storage
        uint256 curPrice = _currentPrice;

        uint256 newPrice = _calculateNewPrice(depositAmount, curPrice);

        uint256 transferAmount = (newPrice - curPrice) * RATIO;
        _currentPrice = newPrice;

        // mint and send BOJ tokens to buyer address
        token.mint(sender, transferAmount);
    }

    // @return the average price of BOJ token that user would receive
    function calculateAvgPrice(uint256 depositAmount) external view returns (uint256 avgPrice) {
        // loading _currentPrice in memory from storage
        uint256 curPrice = _currentPrice;
        uint256 newPrice = _calculateNewPrice(depositAmount, curPrice);

        avgPrice = Math.average(newPrice, curPrice);
    }

    // @notice calculate the new price of the BOJ token
    // @return the new price of the BOJ token
    function _calculateNewPrice(uint256 depositAmount, uint256 curPrice) private pure returns (uint256 newPrice) {
        // newPrice = sqrt(curPrice^2 + 2 * m * depositAmount) where m = 1 / RATIO
        newPrice = Math.sqrt(curPrice * curPrice + 2e18 * depositAmount / RATIO);
    }

    // @dev implementation for ERC777TokensRecipient interface
    function tokensReceived(address, address from, address, uint256 amount, bytes calldata, bytes calldata) external {
        require(msg.sender == 0x6B175474E89094C44Da98b954EedeAC495271d0F); // dummy address
        _buy(from, amount);
    }

    // @notice IERC1363Receiver interface to support transferAndCall
    // @dev token transfer to this address would trigger this function. msg.sender is always token address.
    function onTransferReceived(
        address,
        address from,
        uint256 amount,
        bytes calldata
    )
        external
        override
        returns (bytes4 _selector)
    {
        require(msg.sender == 0x6B175474E89094C44Da98b954EedeAC495271d0F); // dummy address
        _buy(from, amount);

        _selector = IERC1363Receiver.onTransferReceived.selector;
    }

    // @notice IERC1363Receiver interface to support approveAndCall
    // @dev msg.sender is always token address.
    function onApprovalReceived(
        address owner,
        uint256 amount,
        bytes calldata
    )
        external
        override
        returns (bytes4 _selector)
    {
        IERC20(msg.sender).safeTransferFrom(owner, address(this), amount);
        _buy(owner, amount);

        _selector = IERC1363Spender.onApprovalReceived.selector;
    }

    // @notice function to sell BOJ tokens through bonding curve
    // @param amount. number of BOJ tokens that user wants to sell, in 1e18
    // @param tokenToWithdraw, ERC20 token that user chooses to receive
    function sell(uint256 amount, address tokenToWithdraw) public {
        // loading _currentPrice in memory from storage
        uint256 curPrice = _currentPrice;

        // p1 = p2 - m * (s2 - s1)
        uint256 newPrice = curPrice - (amount / RATIO);

        // tokensOut = area under the curve = avg(p1, p2) * amount
        uint256 tokensOutValue = amount * Math.average(newPrice, curPrice) / 1e18;

        _currentPrice = newPrice;
        token.burn(msg.sender, amount);

        IERC20(tokenToWithdraw).safeTransfer(msg.sender, tokensOutValue);
    }
}

/**
 * @notice ERC20 mock token for testing with a new approve function
 */
contract ERC20Mock is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mintAndApprove(address owner, address spender, uint amount) public {
        _mint(owner, amount);
        _approve(owner, spender, amount);
    }
}

/**
 * @notice Test contract for Invariant testing with echidna
 */
contract TestTokenSaleManager is TokenSaleManager {
    address echidna = msg.sender;
    ERC20Mock someToken = new ERC20Mock("random token", "DD");

    constructor() TokenSaleManager() {
        // mint and approve someTokens on behalf of echidna
        ERC20Mock(someToken).mintAndApprove(echidna, address(this), type(uint256).max);
    }

    // pre: some value for current price and token supply
    // invariant: sell is not called
    // post: token supply and price must always increases
    function echidna_token_supply_invariant_onBuy() public returns (bool) {
        // set current price and mint some tokens to random address
        _currentPrice = 10e18;
        token.mint(address(1), 1000e18);

        uint256 initialSupply = token.totalSupply();
        uint256 initialPrice = _currentPrice;

        buy(100, address(someToken));

        return token.totalSupply() > initialSupply && _currentPrice > initialPrice;
    }

    // pre: some value for current price and token supply
    // invariant: buy is not called
    // post: token supply and price must always decreases
    function echidna_token_supply_invariant_onSell() public returns (bool) {
        // set current price and mint some tokens to echidna address
        _currentPrice = 10e18;
        token.mint(echidna, 1000e18);

        uint256 initialSupply = token.totalSupply();
        uint256 initialPrice = _currentPrice;

        sell(100, address(someToken));

        return token.totalSupply() < initialSupply && _currentPrice < initialPrice;
    }

    // invariant: token supply > 0
    // post: current price > 0
    function echidna_non_zero_price() public view returns (bool) {
        return token.totalSupply() > 0 ? _currentPrice > 0 : _currentPrice == 0;
    }

    // invariant: current price > 0
    // post: token supply > 0
    function echidna_non_zero_supply() public view returns (bool) {
        return _currentPrice > 0 ? token.totalSupply() > 0 : token.totalSupply() == 0;
    }

    // invariant: current price > 0 or token supply > 0
    // post: balanceOf(saleManager) > 0
    function echidna_non_zero_balance() public view returns (bool) {
        /**
         *  INVARIANT RESULT #1
         *  Call sequence:                                                                                                   │
    │           1.onTransferReceived(0x0,0xdeadbeef,1,"\NUL")
            Resolution
                1. require(msg.sender == address(acceptedToken));
            
            INVARIANT RESULT #2
            Call sequence:                                                                                                   │
    │           1.tokensReceived(0x0,0xdeadbeef,0x0,1,"","\NUL")
            Resolution
                1. require(msg.sender == address(acceptedToken));
        */
        return _currentPrice > 0 || token.totalSupply() > 0 ? someToken.balanceOf(address(this)) > 0 : true;
    }
}
