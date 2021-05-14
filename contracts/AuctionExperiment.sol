// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Auction {
    // enum 
    enum MatchStatus { OPENED, CLOSED, FINISHED }
    
    // constants
    address constant ADDRESS_NULL = 0x0000000000000000000000000000000000000000;
    
    // usdc address (erc20)
    address constant USDC_ADDRESS = 0x2855F9fdC4aDb2825a7fb03bE5d3eC3c8fEcE934;
    
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
    // match player id
    mapping(string => mapping(address => Player)) matchPlayerId;
    // player information for a match
    mapping(string => address[]) players;

    modifier matchStatus(string memory matchId, MatchStatus status) { // -1 for check
        Match memory amatch = matches[matchId]; // read 4 uint, 800*4 ~ 3200 gas
        require(amatch.creatorAddress != ADDRESS_NULL, "Invalid match");
        if (status == MatchStatus.OPENED) {
            // allow people to deposit
            require(amatch.expiryDate > block.timestamp, "Match is not open to deposit");
        }
        else if (status == MatchStatus.CLOSED) {
            // close does not means that they can withdraw
            require(amatch.expiryDate < block.timestamp, "Match is not closed");
        }
        else if (status == MatchStatus.FINISHED) {
            require(amatch.expiryDate < block.timestamp, "Match is not closed to be finished");
            // match finished when winning count reaches maxWinning, or reach number of tickets
            if (amatch.winningCount < amatch.maxWinning && players[matchId].length > 0) {
                // last person is rewarded
                address lastPerson = players[matchId][0];
                Player memory player = matchPlayerId[matchId][lastPerson];
                require(player.winningCount == player.ticketCount, "Match is not finished");
            }
            // else match is finished
        }
        _;
    }

    // events
    event CreateAuctionEvent(string matchId, address auctionCreator, uint maxWinning, uint ticketPrice, uint rewardPerTicket, address tokenContractAddress);
    event DepositEvent(string matchId, address player, uint depositAmount, uint ticketCount);
    event PublishedEvent(string matchId, address winner, uint winningOrder);
    
    // util functions
    function min(uint x, uint y) private pure returns(uint){
        return (x > y ? y : x);
    }
    
    // util function 
    // lower_bound = 0
    function random(uint upper_bound, uint blockNumber) private view returns(uint) {
        require(upper_bound > 0, "upper_bound must be greater than 0");
        require(blockNumber > 0, "blockNumber must be greater than 0");
        
        if (upper_bound == 1) {
            // early return to eliminate gas used
            return 0;
        }
        // random number = futureBlock + previousWinner
        return uint(keccak256(abi.encodePacked(blockhash(blockNumber - 1), block.timestamp))) % upper_bound;
    }
    
    constructor() { }
    
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
        require(expiryDate > block.timestamp, "expiryDate must be in the future");
        
        // check future block is valid
        require(futureBlock > block.number,   "futureBlock must be greater than current block");
        
        // check rewardPerTicket
        require(ticketReward > 0, "rewardPerTicket must be greater than 0");
        
        // check amount == rewardPerTicket * maxWinningTicket
        require(maxWinning > 0, "maxWinningTicket must be greater than 0");
        require(ticketPrice > 0, "ticketPrice must be greater than 0");
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

    function deposit(string memory matchId, uint amount) public matchStatus(matchId, MatchStatus.OPENED) {
        // for safety, should limit upper_bound for amount
        uint128 _amount = uint128(amount);
        require(_amount > 0, "deposit amount must be greater than 0");
        
        address playerAddress = msg.sender;
        uint96  ticketPrice   = matches[matchId].ticketPrice; //800 gas
        // check if sender amount is divisble by ticketPrice
        require(_amount % ticketPrice == 0, "deposit amount should be divisble by ticketPrice");
        
        bool success = ERC20(USDC_ADDRESS).transferFrom(payable(playerAddress), address(this), _amount);
        require(success, "deposit failed");
        
        uint128 ticketCount = _amount / ticketPrice;
        if (matchPlayerId[matchId][playerAddress].ticketCount == 0) {
            // create 2 new slot
            matchPlayerId[matchId][playerAddress] = Player(ticketCount, 0);
            players[matchId].push(playerAddress); 
            matches[matchId].randomUpperbound ++;
        }
        else {
            // just increase tickets 
            // modify 1 slot
            matchPlayerId[matchId][playerAddress].ticketCount += ticketCount;
        }
        
        // emit deposit event
        emit DepositEvent(matchId, playerAddress, amount, ticketCount);
    }

    // // call this function to publish lottery result
    // if not enough winining ticket published, no one can withdraw money => people are incentivize to invoke this function
    function publish_lottery_result(string memory matchId) public matchStatus(matchId, MatchStatus.CLOSED) { // 3 storage change at most 
    	uint futureBlock = matches[matchId].futureBlock;
        require(futureBlock < block.number, "future block has not been generated");
        // get random between 0 and max
        uint upperBound = matches[matchId].randomUpperbound;
        require(upperBound > 0, "random upper bound should be greater than 0");
        
        // get next winner
        uint    nextWinner = random(upperBound, futureBlock);
        address winnerAddress = players[matchId][nextWinner];
        // increase price 
        matchPlayerId[matchId][winnerAddress].winningCount ++;
        
        // if winning Ticket reach his max, swap to end in order not to being randomed again
        Player memory player = matchPlayerId[matchId][winnerAddress]; // load into memory once to save gas
        uint numPlayer = players[matchId].length;

        if (player.ticketCount == player.winningCount) {
            // swap address and decrease count 
            // it is not likely to happen
            // cost 2 storage change 
            (players[matchId][nextWinner],  players[matchId][numPlayer-1]) = (players[matchId][numPlayer-1],  players[matchId][nextWinner]);
            // not consider this person any more
            matches[matchId].randomUpperbound --; 
        }
    	emit PublishedEvent(matchId, winnerAddress, matches[matchId].winningCount);
    }

    // withdraw the price
    function withdraw(string memory matchId, address payable newTokenRecipient) public matchStatus(matchId, MatchStatus.FINISHED) returns(bool)  {
        // locate people 
        address playerAddress = msg.sender;
        
        Player memory player = matchPlayerId[matchId][playerAddress];
        uint128 winningCount = player.winningCount;
        require(player.ticketCount > 0, "You must have ticket to withdraw");
        
        if (winningCount > 0) {
            // withdraw new token first 
            // compute winning token 
            uint winningToken = winningCount * matches[matchId].ticketReward;
            
            // delete wining tickets in storage
            matchPlayerId[matchId][playerAddress].winningCount = 0;
            bool success = ERC20(matches[matchId].tokenContractAddress).transfer(newTokenRecipient, winningToken);
            require(success, "transfer new token is not success"); // if failed then reverted to initial state
        }
        
        // if money left for this match > 0 then withdraw
        if (matchPlayerId[matchId][playerAddress].ticketCount > 0) {
            
            uint128 remainTicket = (player.ticketCount - winningCount);
            uint    refund = remainTicket * matches[matchId].ticketPrice;
            
            matchPlayerId[matchId][playerAddress].ticketCount = 0;
            if (!ERC20(USDC_ADDRESS).transfer(playerAddress, refund)) {
                // just restore number of remain ticket
                matchPlayerId[matchId][playerAddress].ticketCount = remainTicket;     
                // dont call revert, revert will potentially restore successful token withdraw
                return false;
            }
            // withdrawal succeed! 
        }
        
        return true;
    }
}
