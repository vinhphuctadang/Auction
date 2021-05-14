// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract Auction {
    // constants
    address constant ADDRESS_NULL = 0x0000000000000000000000000000000000000000;
    uint    constant MAX_TICKET_PER_DEPOSIT = 5;
    
    uint dummyVariable;

    // player data
    struct Player {
        // number of deposit;
        uint224 depositAmount;
        // number of ticket won
        uint32 ticketWon;
    }
    
    // match meta data
    struct Match {
        address creatorAdress; // 20 bytes
        uint96  ticketReward;
        uint128 totalReward;
        uint96  ticketPrice;
        uint64  expiryDate;
        uint160 futureBlock;
        uint32  winningCount;
        uint32  maxWinning; 
    }
    
    // state data
    // match id -> Match
    mapping(string => Match) matches;
    // tickets, [player1, player1, player2, player3, player3, ...]
    mapping(string => address[]) tickets;
    // player information for a match
    mapping(string => mapping(address => Player)) players;
    
    // modifiers
    modifier creatorOnly(address creatorAddress, string memory matchId) {
        require(creatorAddress != ADDRESS_NULL && matches[matchId].creatorAdress == creatorAddress, "Caller must be creator of this match");
        _;
    }

    modifier validMatch(string memory matchId) {
        Match storage amatch = matches[matchId];
        require(amatch.creatorAdress != ADDRESS_NULL, "Creator is invalid");
        _;
    }
    
    // modifier expiredMatch(string memory matchId) {
    //     Match storage amatch = matches[matchId];
    //     require(amatch.creatorAdress != ADDRESS_NULL, "Creator is invalid");
    //     require(amatch.expiryDate < block.timestamp, "Match must be expired to be deposited");
    //     _;
    // }

    // events
    event DepositEvent(string matchId, address player, uint depositAmount, uint ticketCount);
    event PublishedEvent(string matchId, address winner, uint winningOrder);
    event CreateAuctionEvent(string matchId, address auctionCreator, uint maxWinning, uint ticketPrice, uint rewardPerTicket, string tokenName);
    
    // util functions
    function min(uint x, uint y) private pure returns(uint){
        return (x > y ? y : x);
    }
    
    // util function 
    function randrange(uint lower_bound, uint upper_bound, uint blockNumber, address previousWinner) private view returns(uint) {
        require(lower_bound < upper_bound, "lower_bound must be less than upper_bound");
        require(blockNumber > 0, "blockNumber must be greater than 0");
        // random number = futureBlock + previousWinner
        return uint(keccak256(abi.encodePacked(blockhash(blockNumber-1), previousWinner))) % (upper_bound - lower_bound) + lower_bound;
    }
    
    constructor() public{
        
    }
    
    // functions
    function auction(string memory matchId, uint64 expiryDate, uint160 futureBlock, uint32 maxWinning, uint96 ticketPrice, uint96 rewardPerTicket) public payable {
        // use SafeMath (not safeMoon T,T)
        address creatorAdress = msg.sender;
        uint128 totalReward = maxWinning * rewardPerTicket;
        require(uint256(totalReward) == msg.value, "sent amount must be equals to maxWinningTicket * rewardPerTicket");
        // check match validity:
        // check occupied slot 
        // check expiryDate ( >= now)
        // check future block is valid
        // check rewardPerTicket
        // check amount == rewardPerTicket * maxWinningTicket
        require(matches[matchId].creatorAdress == ADDRESS_NULL, "Matches with given matchId is occupied");
        require(expiryDate > block.timestamp, "expiryDate must be in the future");
        require(futureBlock > block.number,   "futureBlock must be greater than current block");
        require(rewardPerTicket > 0, "rewardPerTicket must be greater than 0");
        require(maxWinning > 0, "maxWinningTicket must be greater than 0");
        require(ticketPrice > 0, "ticketPrice must be greater than 0");
        
        // store match
        matches[matchId] = Match(creatorAdress, rewardPerTicket, totalReward, ticketPrice, expiryDate, futureBlock, 0, maxWinning);
        // emit creating auction event
        
        emit CreateAuctionEvent(matchId, creatorAdress, maxWinning, ticketPrice, rewardPerTicket, "BAM");
    }

    function deposit(string memory matchId) public payable validMatch(matchId) {
        // check if sender amount is divisble by ticketPrice
        // check if match limit reach 
        // store tickets and push to queue
        Match memory amatch = matches[matchId];
        
        uint224 depositAmount = uint224(msg.value);
        uint    ticketPrice   = amatch.ticketPrice;
        address playerAddress = msg.sender;
        uint    ticketCount = depositAmount / ticketPrice;
        // // conditions
        require(amatch.expiryDate > block.timestamp, "Match is expired");
        require(depositAmount > 0, "depositValue must be greater than 0");
        require(depositAmount % ticketPrice == 0, "depositValue should be divisble by ticketPrice");
        require(ticketCount <= MAX_TICKET_PER_DEPOSIT, "Number of ticket per deposit call exceeds");
        
        // push
        for(uint i = 0; i < ticketCount; ++i) {
            // bad pratice
            tickets[matchId].push(playerAddress);
        }
        players[matchId][playerAddress].depositAmount += depositAmount;
        // // emit events
        emit DepositEvent(matchId, playerAddress, depositAmount, ticketCount);
    }

    // // call this function to publish lottery result
    // // if not enough winining ticket published, no one can withdraw money
    function publish_lottery_result(string memory matchId) public {
    	// check auctionCreator, auctionId validity
    	// check if desired block generated
    	
    	// read match information
        Match memory amatch = matches[matchId];
    	uint futureBlock    = amatch.futureBlock;
    	uint winningCount   = amatch.winningCount;
    	
    	address[] storage matchTickets = tickets[matchId];
    	
    	// check: valid block 
    	// check winningCount exceeds min(maxWinning or max ticket count)
        require(block.number >= futureBlock, "futureBlock is not generated");
    	require(winningCount < amatch.maxWinning, "maxWinning reached");
    	
        address previousWinner = ADDRESS_NULL;
    	if (amatch.winningCount > 0) {
    	    previousWinner = matchTickets[winningCount - 1];
    	}
    	
    	// random next winner
    	uint nextWinner = uint(keccak256(abi.encodePacked(blockhash(futureBlock-1), previousWinner, block.difficulty))) % (matchTickets.length - winningCount) + winningCount;
    	
    	// locate winner address 
    	address winnerAddress = matchTickets[nextWinner];
    	
    	// swap winner to top to avoid being chosen again 
    	(matchTickets[winningCount], matchTickets[nextWinner]) = (matchTickets[nextWinner], matchTickets[winningCount]);
    	
    	// increase ticketWon
    	players[matchId][winnerAddress].ticketWon ++;
    
    	// increase number of win
    	matches[matchId].winningCount ++;
    	
    	// emit events
    	emit PublishedEvent(matchId, winnerAddress, matches[matchId].winningCount);
    }

    // withdraw the price
    function withdraw(string memory matchId) public returns(bool) {
        
        Player storage player = players[matchId][msg.sender];
        Match memory amatch = matches[matchId];
        
        // prevent withdrawal when maxWinning not reached
        require(amatch.winningCount == min(amatch.maxWinning, tickets[matchId].length), "Match is not over, call to publish_lottery_result to publish tickets");
        
        // depositAmount
        require(player.depositAmount > 0, "player has no deposit amount for this match");
    	
    	// TODO: Use safemath
    	uint224 depositAmount = player.depositAmount;
    	uint32 ticketWon = player.ticketWon;
    	// send win token first
    	// in case sending token fails, we just restore 
    	
    	// TODO: Add ERC20 token here
    	if (ticketWon > 0) {
    	    
    	    player.ticketWon = 0;
    	    uint128 reward = ticketWon * matches[matchId].ticketReward;
        	if (!msg.sender.send(reward)) {
        	    // just recover 
        	    player.ticketWon = ticketWon;
        	    // return if failed
        	    return false;
        	}
        	
        	// decrease totalReward 
        	matches[matchId].totalReward -= reward;
        	
        	// compute refund 
        	player.depositAmount -= matches[matchId].ticketPrice * ticketWon;
        	depositAmount = player.depositAmount;
    	}
    	
    	player.depositAmount = 0;
    	if (!msg.sender.send(depositAmount)) {
    	    // just restore 
    	    player.depositAmount = depositAmount;
    	    // fail with full withdrawal
    	    return false;
    	}
    	return true;
    }

    function dummySet(uint a) public {
        dummyVariable = a;
    }
}


// TODO: Notice case where maxWinningTicket > number of ticket bought
// function creatorWithdraw(string memory matchId) public creatorOnly(msg.sender, matchId) returns(bool){
//     Match memory amatch = matches[matchId];
//     // prevent withdrawal when maxWinning not reached
//     require(amatch.winningCount > tickets[matchId].length, "Match is not over, call to publish_lottery_result to publish tickets");
    
//     uint totalReward = amatch.totalReward;
//     require(amatch.totalReward > 0, "Total reward must be larger than 0");
    
//     // TODO: Use ERC20
//     matches[matchId].totalReward = 0;
//     if (!payable(msg.sender).send(totalReward)) {
//         matches[matchId].totalReward = totalReward;
//         return false;
//     }
//     return true;
// }