// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 * customized openzeppelin-solidity safemath 
 */
library SafeMath {
  function add(uint128 a, uint128 b) internal pure returns (uint128 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

/*
1. Where usdc of winning ticket goes 
2. (Design): Can we optimize more 
3. Create tests
*/
contract Auction {
    
    // use library
    using SafeMath for uint128;

    // constants
    address constant ADDRESS_NULL = 0x0000000000000000000000000000000000000000;
    
    // usdc address (erc20)
    address USDC_ADDRESS;
    
    // uint dummyVariable;
    // player data
    struct Player { // 1 uint256
        // number of deposit;
        uint128 ticketCount;
        // number of ticket won
        uint128 winningCount;
    }
    
    // match meta data
    struct Match { // 4 uint256
        address creatorAddress; // 20 bytes
        address tokenContractAddress; // 20 bytes
        uint96  ticketReward;
        uint96  ticketPrice;
        uint64  expiryDate;
        uint128 futureBlock;
        uint32  winningCount; 
        uint32  maxWinning; 
        uint randomUpperbound;
    }
    
    // state data
    // match id -> Match
    mapping(string => Match) matches;
    // player data for each match, use mapping for quick access 
    mapping(string => mapping(address => Player)) playerData;
    // player list for each match
    mapping(string => address[]) playerList;

    modifier validMatch(string memory matchId) {
        require(matches[matchId].creatorAddress != ADDRESS_NULL, "Invalid match");
        _;
    }
    
    modifier matchFinished(string memory matchId){
        Match memory amatch = matches[matchId];
        require(amatch.creatorAddress != ADDRESS_NULL && amatch.expiryDate < block.timestamp, "Invalid match or match is not closed yet");

        // if number of ticket < number of max winning ticket 
        if (amatch.winningCount < amatch.maxWinning && playerList[matchId].length > 0) {
            Player memory player = playerData[matchId][playerList[matchId][0]];
            require(player.winningCount == player.ticketCount, "Match is not finished");
        }
        else {
            require(amatch.winningCount == amatch.maxWinning, "Match is not finished");
        }
        _;
    }

    // events
    event CreateAuctionEvent(string matchId, address auctionCreator, uint maxWinning, uint ticketPrice, uint rewardPerTicket, address tokenContractAddress);
    event DepositEvent(string matchId, address player, uint depositAmount, uint ticketCount);
    event PublishedEvent(string matchId, address winner, uint winningOrder);
    
    // util function 
    // lower_bound = 0
    function random(uint upper_bound, uint blockNumber) private view returns(uint) {
        require(upper_bound > 0, "upper_bound must be greater than 0");
        require(blockNumber > 0, "blockNumber must be greater than 0");
        
        if (upper_bound == 1) {
            // early return to eliminate gas used
            return 0;
        }
        // random number = futureBlock + blop
        return uint(keccak256(abi.encodePacked(blockhash(blockNumber - 1), block.timestamp))) % upper_bound;
    }
    
    constructor(address usdcContractAddress) { 
        // wrong address will results in deposit failure 
        USDC_ADDRESS = usdcContractAddress; 
    }
    
    // functions
    function auction(
        string memory matchId, uint64 expiryDate, uint128 futureBlock, 
        uint32 maxWinning, uint96 ticketPrice, uint96 ticketReward, 
        address tokenContractAddress
    ) public payable {
        // use SafeMath (not safeMoon T,T)
        address creatorAddress = msg.sender;
        
        // check match validity:
        // check occupied slot 
        require(matches[matchId].creatorAddress == ADDRESS_NULL, "matches with given matchId is occupied");
        // check expiryDate ( >= now)
        require(expiryDate > block.timestamp && futureBlock > block.number, "expiry date or block must be in the future");
        // check rewardPerTicket
        require(ticketReward > 0 && ticketPrice > 0, "ticket price and reward must be greater than 0");
        // check amount == rewardPerTicket * maxWinningTicket
        require(maxWinning > 0 , "maxWinningTicket must be greater than 0");
        
        uint128 totalReward = maxWinning * ticketReward;
        // transfer token to this contract 
        bool success = ERC20(tokenContractAddress).transferFrom(payable(msg.sender), address(this), totalReward);
        require(success, "Insufficient amount for reward");
        
        // store match
        matches[matchId] = Match(
            creatorAddress, tokenContractAddress, 
            ticketReward, ticketPrice, 
            expiryDate, futureBlock, 
            0, maxWinning, 0
        ); // estimate gas: 4*23000 -> 5*23000
        
        // emit creating auction event
        emit CreateAuctionEvent(matchId, creatorAddress, maxWinning, ticketPrice, ticketReward, tokenContractAddress);
    }

    function deposit(string memory matchId, uint amount) public payable validMatch(matchId) {
        
        // check opening state
        require(matches[matchId].expiryDate > block.timestamp, "Match is not open to deposit");
        
        // to prevent overflow, should limit upper_bound for amount
        uint128 _amount = uint128(amount);
        require(_amount > 0, "deposit amount must be greater than 0");
        
        address playerAddress = msg.sender;
        uint96  ticketPrice   = matches[matchId].ticketPrice; //800 gas
        // check if sender amount is divisble by ticketPrice
        require(_amount % ticketPrice == 0, "deposit amount should be divisble by ticketPrice");
        
        bool success = ERC20(USDC_ADDRESS).transferFrom(payable(playerAddress), address(this), _amount);
        require(success, "deposit failed");
        
        uint128 ticketCount = _amount / ticketPrice;
        uint128 currentCount = playerData[matchId][playerAddress].ticketCount;
        if (currentCount == 0) {
            // create new slot for new player 
            playerData[matchId][playerAddress].ticketCount = ticketCount;
            playerList[matchId].push(playerAddress);
            
            // increase number of player, this can be optimized
            matches[matchId].randomUpperbound ++;
        }
        else {
            // just increase ticket count 
            playerData[matchId][playerAddress].ticketCount = currentCount.add(ticketCount);
        }
        
        // emit deposit event
        emit DepositEvent(matchId, playerAddress, amount, ticketCount);
    }

    // // call this function to publish lottery result
    // if not enough winining ticket published, no one can withdraw money => people are incentivize to invoke this function
    function publish_lottery_result(string memory matchId) public validMatch(matchId) { // 3 storage change at most
    
        require(matches[matchId].expiryDate < block.timestamp, "Match is not closed");
        
    	uint futureBlock = matches[matchId].futureBlock;
        require(futureBlock < block.number, "future block has not been generated");
        
        // get random between 0 and randomUpperbound
        uint upperBound = matches[matchId].randomUpperbound;
        require(upperBound > 0, "random upper bound should be greater than 0");
        
        // get next winner
        uint    nextWinner = random(upperBound, futureBlock);
        address winnerAddress = playerList[matchId][nextWinner];
        // increase number of winning ticket 
        playerData[matchId][winnerAddress].winningCount ++;
        
        // if winning ticket reach his max, swap to end in order not to being randomed again
        Player memory player = playerData[matchId][winnerAddress]; // load into memory once to save gas

        if (player.ticketCount == player.winningCount) {
            // swap address and decrease randomUpperbound 
            
            // swap current person to the last slot 
            (playerList[matchId][nextWinner],  playerList[matchId][upperBound-1]) = (playerList[matchId][upperBound-1],  playerList[matchId][nextWinner]);
            // not consider the last person any more, because he wins all his ticket
            matches[matchId].randomUpperbound --; 
        }
    	emit PublishedEvent(matchId, winnerAddress, matches[matchId].winningCount);
    }
    
    
    function withdrawReward(string memory matchId, address payable newTokenRecipient) public matchFinished(matchId) {
        
        address playerAddress = msg.sender;
        Player memory player = playerData[matchId][playerAddress];
        
        // load winning count
        uint128 winningCount = player.winningCount;
        require(winningCount > 0, "You must have winning ticket to withdraw");
 
        // update wining tickets in storage
        playerData[matchId][playerAddress].ticketCount -= winningCount;
        playerData[matchId][playerAddress].winningCount = 0;
        
        // send token
        bool success = ERC20(matches[matchId].tokenContractAddress).transfer(newTokenRecipient, winningCount * matches[matchId].ticketReward);
        require(success, "withdraw new token not success"); // if failed then reverted to initial state
    }
    
    function withdrawDeposit(string memory matchId) public matchFinished(matchId) {
        
        address playerAddress = msg.sender;
        Player memory player = playerData[matchId][playerAddress];
        
        // remaining ticket
        uint128 remainTicket = player.ticketCount - player.winningCount;
        
        // update number of remaning
        playerData[matchId][playerAddress].ticketCount = player.winningCount;
        
        // transfer usdc
        bool success = ERC20(USDC_ADDRESS).transfer(playerAddress, remainTicket * matches[matchId].ticketPrice);
        require(success, "withdraw deposit not success");
    }
    
    // getters 
    function getPlayer(string memory matchId, address playerAddress) public validMatch(matchId) view returns(uint128, uint128) {
        Player memory player = playerData[matchId][playerAddress];
        return (player.ticketCount, player.winningCount);
    }
}
