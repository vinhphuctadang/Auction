// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 * customized openzeppelin-solidity safemath 
 */
library SafeMath {
  function add(uint128 a, uint128 b) internal pure returns (uint128 c) {
    c = a + b;
    require (c >= a, "sum c must be larger or equals to a");
    return c;
  }
}

contract Auction {
    
    // use library
    using SafeMath for uint128;

    // constants
    address constant ADDRESS_NULL = 0x0000000000000000000000000000000000000000;

    uint constant MAX_UINT             = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint constant MAX_PLAYER           = 0xffffffff;
    uint constant MAX_PUBLISH_PER_CALL = 16; 
    
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
        uint96  ticketReward;
        address tokenContractAddress; // 20 bytes
        uint96  ticketPrice;
        uint96  expiryBlock;
        uint96  futureBlock;
        uint32  winningCount;
        uint32  maxWinning;
        // a player's ticket count cannot be more than capPerAddress
        uint    capPerAddress;
    }
    
    // state datas
    mapping(string => bytes32) currentRandomSeed;
    // creator balance in usdc, address -> amount of money
    mapping(address => uint) creatorBalance;
    // match id -> Match
    mapping(string => Match) matches;
    // player data for each match, use mapping for quick access 
    mapping(string => mapping(address => Player)) playerData;
    // player list for each match
    mapping(string => address[]) playerList;

    // address
    address admin;

    modifier creatorOnly(string memory matchId) {
        address creatorAddress = matches[matchId].creatorAddress;
        require(creatorAddress != ADDRESS_NULL && creatorAddress == msg.sender, "only creator allowed");
        _;
    }

    modifier validMatch(string memory matchId) {
        require(matches[matchId].creatorAddress != ADDRESS_NULL, "invalid match");
        _;
    }
    
    modifier matchFinished(string memory matchId){
        Match memory amatch = matches[matchId];
        require(amatch.creatorAddress != ADDRESS_NULL && amatch.futureBlock < block.number, "invalid match or match is not closed yet");

        bool randomSeedNotSet = currentRandomSeed[matchId] == 0 && (block.number - amatch.futureBlock > 255);
        // if no more candidate player in list or winningCount reached
        require (playerList[matchId].length == 0 || amatch.winningCount >= amatch.maxWinning || randomSeedNotSet, "match is not finished");
        _;
    }

    modifier canPublishResult(string memory matchId, uint publishCount) {
        require(publishCount <= MAX_PUBLISH_PER_CALL && publishCount > 0, "publishCount is out of range");
        Match memory amatch = matches[matchId];
        // check if match closed
        require(amatch.expiryBlock < block.number, "match is not closed");  
        require(amatch.futureBlock <= block.number, "future block has not been generated");
        // cannot publish any more
        require(currentRandomSeed[matchId] > 0 || block.number - amatch.futureBlock <= 256, "match is finished");
        // check if max wining reached
        require(publishCount <=  amatch.maxWinning && amatch.winningCount <= amatch.maxWinning - publishCount, "max wining reached");
        // get random between 0 and randomUpperbound
        require(playerList[matchId].length > 0, "player list length should be greater than 0");
        _;
    }

    // events
    event CreateAuctionEvent(string matchId, address auctionCreator, uint32 maxWinning, uint96 ticketPrice, uint96 ticketReward, address tokenContractAddress);
    event DepositEvent(string matchId, address player, uint128 depositAmount, uint128 ticketCount);
    event PublishEvent(string matchId, address winner);
    event BatchPublishEvent(string matchId, address[] winners, uint count);

    constructor(address usdcContractAddress) { 
        // wrong address will results in deposit failure 
        USDC_ADDRESS = usdcContractAddress; 

        // admin of contract
        admin = msg.sender;
    }
    
    // functions
    function auction(
        string memory matchId, uint96 expiryBlock, uint96 futureBlock, 
        uint32 maxWinning, uint96 ticketPrice, uint96 ticketReward, 
        address tokenContractAddress, uint capPerAddress
    ) public payable {
        // use SafeMath (not safeMoon T,T)
        address creatorAddress = msg.sender;
        
        // check match validity:
        // check occupied slot 
        require(matches[matchId].creatorAddress == ADDRESS_NULL, "matches with given matchId is occupied");
        // check expiryDate ( >= now)
        require(expiryBlock > block.number && futureBlock > expiryBlock, "future block > expiryBlock > current chain length");
        // check rewardPerTicket
        require(ticketReward > 0 && ticketPrice > 0, "ticket price and reward must be greater than 0");
        // check amount == rewardPerTicket * maxWinningTicket
        require(maxWinning > 0 , "maxWinningTicket must be greater than 0");
        
        if (capPerAddress == 0) { capPerAddress = MAX_UINT; }

        uint128 totalReward = maxWinning * ticketReward;
        
        // store match
        matches[matchId] = Match(
            creatorAddress, 
            ticketReward, 
            tokenContractAddress, 
            ticketPrice, 
            expiryBlock, futureBlock, 
            0, maxWinning,
            capPerAddress
        ); // estimate gas: 4*23000 -> 5*23000

        // transfer token to this contract 
        bool success = ERC20(tokenContractAddress).transferFrom(payable(msg.sender), address(this), totalReward);
        require(success, "insufficient amount for reward");
        
        // emit creating auction event
        emit CreateAuctionEvent(matchId, creatorAddress, maxWinning, ticketPrice, ticketReward, tokenContractAddress);
    }

    function deposit(string memory matchId, uint amount) public payable validMatch(matchId) {
        
        // check opening state
        require(matches[matchId].expiryBlock >= block.number, "match is not opened to deposit");
        
        // to prevent overflow, should limit upper_bound for amount
        uint128 _amount = uint128(amount);
        require(_amount > 0, "deposit amount must be greater than 0");
        
        address playerAddress = msg.sender;
        uint96  ticketPrice   = matches[matchId].ticketPrice; //800 gas
        // check if sender amount is divisble by ticketPrice
        require(_amount % ticketPrice == 0, "deposit amount should be divisible by ticket price");
        
        uint128 ticketCount = _amount / ticketPrice;

        uint128 currentCount = playerData[matchId][playerAddress].ticketCount;
        uint128 nextCount = currentCount.add(ticketCount);

        // prevent player from deposit large number of ticket
        require(nextCount <= matches[matchId].capPerAddress, "Number of ticket exceeds cap");

        // transfer money
        bool success = ERC20(USDC_ADDRESS).transferFrom(payable(playerAddress), address(this), _amount);
        require(success, "deposit failed");

        if (currentCount == 0) {
            require(playerList[matchId].length < MAX_PLAYER, "Player limit exceeds");

            // create new slot for new player 
            playerData[matchId][playerAddress] = Player(nextCount, 0);
            playerList[matchId].push(playerAddress);
        }
        else {
            // just increase ticket count
            playerData[matchId][playerAddress].ticketCount = nextCount;
        }
        
        // emit deposit event
        emit DepositEvent(matchId, playerAddress, _amount, ticketCount);
    }

    // increase wining ticket of chosen user
    // should be called from publish_lottery_result with modifier, all input should be valid before calling this function
    function process_winner(string memory matchId, uint nextWinner, address creatorAddress, uint playerListLength) private returns(address, uint){
        address winnerAddress = playerList[matchId][nextWinner];
        // increase number of winning ticket to player
        playerData[matchId][winnerAddress].winningCount ++;

        // increase usdc balance of creator
        creatorBalance[creatorAddress] += matches[matchId].ticketPrice;

        // if winning ticket reach his max, swap to end in order not to being randomed again
        Player memory player = playerData[matchId][winnerAddress]; // load into memory once to save gas

        if (player.ticketCount == player.winningCount) {
            // swap address and decrease randomUpperbound
            // swap current person to the last slot
            playerList[matchId][nextWinner] = playerList[matchId][playerListLength - 1];
            // not consider the last person any more, because he wins all his ticket
            playerList[matchId].pop();
            playerListLength --;
        }

        // return both winner and remaining number of player
        return (winnerAddress, playerListLength);
    }
    

    function get_randomseed(string memory matchId, uint futureBlock) private view returns(bytes32){
        // dont need to store, caller to this function will store seed to eliminate gas used
        bytes32 randomSeed = currentRandomSeed[matchId];
        if (randomSeed == 0) {
            randomSeed = keccak256(abi.encodePacked(blockhash(futureBlock - 1)));
        }
        return randomSeed;
    }

    // // call this function to publish lottery result
    // if not enough winining ticket published, no one can withdraw money => people are incentivize to invoke this function
    function publish_lottery_result(string memory matchId) public validMatch(matchId) canPublishResult(matchId, 1) { 
        // 6 storage change at most

        // read 4 uint from storage
        address creatorAddress = matches[matchId].creatorAddress;
        uint    playerListLength = playerList[matchId].length;
        // the randomSeed will be different even in the same block, thanks to keccak
        bytes32 randomSeed = get_randomseed(matchId, matches[matchId].futureBlock);

        uint    nextWinner = uint(randomSeed) % playerListLength;
        (address winnerAddress, ) = process_winner(matchId, nextWinner, creatorAddress, playerListLength);
        // increase winning count of the match
        matches[matchId].winningCount ++;
        // rehash and save randomSeed for next random 
        currentRandomSeed[matchId] = keccak256(abi.encodePacked(randomSeed));
        // emit event
    	emit PublishEvent(matchId, winnerAddress);
    }

    function publish_lottery_result_batch(string memory matchId, uint32 count) public validMatch(matchId) canPublishResult(matchId, count) { 
        // read 4 uint from storage
        address creatorAddress   = matches[matchId].creatorAddress;
        uint    playerListLength = playerList[matchId].length;
        // get random seed
        bytes32 randomSeed = get_randomseed(matchId, matches[matchId].futureBlock);

        address[] memory winners = new address[](count);
        uint index;

        for(index = 0; (index < count) && (playerListLength > 0); ++index) {
            uint nextWinner = uint(randomSeed) % playerListLength;
            (address winnerAddress, uint tmpLen) = process_winner(matchId, nextWinner, creatorAddress, playerListLength);
            playerListLength = tmpLen;
            // store result
            winners[index]   = winnerAddress;
            // update random seed (in memory)
            randomSeed = keccak256(abi.encodePacked(randomSeed));
        }

        // add to winning count
        matches[matchId].winningCount += uint32(index);
        // store the random seed for next random
        currentRandomSeed[matchId] = randomSeed;

        // emit event
        emit BatchPublishEvent(matchId, winners, index);
    }

    // used when number of ticket < number ticket deposited, we may rules out that if no ticket bought, we withdraw
    function creator_withdraw_deposit(string memory matchId) public creatorOnly(matchId) matchFinished(matchId) {
        Match memory amatch = matches[matchId];
        require(amatch.maxWinning > amatch.winningCount, "no more unused wining ticket");
        uint remainingTicket = amatch.maxWinning - amatch.winningCount;
        matches[matchId].maxWinning = amatch.winningCount;
        
        bool success = ERC20(amatch.tokenContractAddress).transfer(amatch.creatorAddress, remainingTicket * amatch.ticketReward);
        require(success, "withdraw not success");
    }
    
    function creator_withdraw_profit() public payable { // creator withdraw his balance
        uint balance = creatorBalance[msg.sender];
        require(balance > 0, "creator balance must be greater than 0");
        creatorBalance[msg.sender] = 0;
        // send token
        bool success = ERC20(USDC_ADDRESS).transfer(msg.sender, balance);
        require(success, "withdraw not success"); // if failed then reverted to initial state
    }
    
    function player_withdraw_reward(string memory matchId, address payable newTokenRecipient) public matchFinished(matchId) {
        
        address playerAddress = msg.sender;
        // update wining tickets in storage
        Player storage player = playerData[matchId][playerAddress];

        // load winning count
        uint128 winningCount = player.winningCount;
        require(winningCount > 0, "must have winning ticket to withdraw");
 
        player.ticketCount -= winningCount;
        player.winningCount = 0;
        
        // send token
        bool success = ERC20(matches[matchId].tokenContractAddress).transfer(newTokenRecipient, winningCount * matches[matchId].ticketReward);
        require(success, "withdraw new token not success"); // if failed then reverted to initial state
    }
    
    function player_withdraw_deposit(string memory matchId) public matchFinished(matchId) {
        
        address playerAddress = msg.sender;
        Player memory player = playerData[matchId][playerAddress];
        
        // remaining ticket
        uint128 remainTicket = player.ticketCount - player.winningCount;
        require(remainTicket > 0, "there must be losing ticket to withdraw");
        // update number of remaning
        playerData[matchId][playerAddress].ticketCount = player.winningCount;
        
        // transfer usdc
        bool success = ERC20(USDC_ADDRESS).transfer(playerAddress, remainTicket * matches[matchId].ticketPrice);
        require(success, "withdraw deposit not success");
    }

    // getters 
    function get_player(string memory matchId, address playerAddress) public validMatch(matchId) view returns(uint128, uint128) {
        Player memory player = playerData[matchId][playerAddress];
        return (player.ticketCount, player.winningCount);
    }

    function get_match(string memory matchId) public validMatch(matchId) view returns (address, uint96, address, uint96, uint96, uint96, uint32, uint32, uint) {
        Match memory amatch = matches[matchId];
        return (
            amatch.creatorAddress,
            amatch.ticketReward,
            amatch.tokenContractAddress, 
            amatch.ticketPrice,
            amatch.expiryBlock,
            amatch.futureBlock,
            amatch.winningCount, 
            amatch.maxWinning,
            amatch.capPerAddress
        );
    }

    function get_creator_balance(address creatorAddress) public view returns(uint){
        return creatorBalance[creatorAddress];
    }

    function get_player_count(string memory matchId) public view returns(uint) {
        return playerList[matchId].length;
    }

    function get_current_randomseed(string memory matchId) public view returns(uint) {
        return uint(currentRandomSeed[matchId]);
    }
}
