// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;


contract Auction {
    // constants
    address constant ADDRESS_NULL = 0x0000000000000000000000000000000000000000;
    uint    constant MAX_TICKET_PER_DEPOSIT = 5;
    
    // player data
    struct Player {
        // number of deposit;
        uint depositAmount;
        // number of ticket won
        uint ticketWon;
    }
    
    // match meta data
    struct Match {
        address creatorAdress;
        uint totalReward;
        uint ticketPrice; 
        uint ticketReward;
        uint expiryDate;
        uint futureBlock;
        uint winningCount;
        uint maxWinning;
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
    
    modifier expiredMatch(string memory matchId) {
        Match storage amatch = matches[matchId];
        require(amatch.creatorAdress != ADDRESS_NULL, "Creator is invalid");
        require(amatch.expiryDate < block.timestamp, "Match must be expired to be deposited");
        _;
    }

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
        require(lower_bound < upper_bound, "left must be less than right");
        require(blockNumber > 0, "blockNumber must be greater than 0");
        // random number = futureBlock + previousWinner
        return uint(keccak256(abi.encodePacked(blockhash(blockNumber-1), previousWinner))) % (upper_bound - lower_bound) + lower_bound;
    }
    
    constructor(){
        // init
    }
    
    // functions
    function auction(string memory matchId, uint expiryDate, uint futureBlock, uint maxWinning, uint ticketPrice, uint rewardPerTicket) public payable {
        // use SafeMath (not safeMoon T,T)
        address creatorAdress = msg.sender;
        uint totalReward = msg.value;
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
        
        require(maxWinning * rewardPerTicket == totalReward, "sent amount must be equals to maxWinningTicket * rewardPerTicket");
        
        // store match
        matches[matchId] = Match(creatorAdress, totalReward, ticketPrice, rewardPerTicket, expiryDate, futureBlock, 0, maxWinning);
        // emit creating auction event
        
        emit CreateAuctionEvent(matchId, creatorAdress, maxWinning, ticketPrice, rewardPerTicket, "BAM");
    }

    function deposit(string memory matchId) public payable validMatch(matchId) {
        // check if sender amount is divisble by ticketPrice
        // check if match limit reach 
        // store tickets and push to queue
        // Match memory amatch = matches[matchId];
        // uint    depositAmount = msg.value;
        // uint    ticketPrice   = amatch.ticketPrice;
        // address playerAddress = msg.sender;
        
        // // conditions
        // require(amatch.creatorAdress != ADDRESS_NULL, "Creator of this matches is invalid");
        // require(amatch.expiryDate > block.timestamp, "Match is expired");
        // require(depositAmount > 0, "depositValue must be greater than 0");
        // require(depositAmount % ticketPrice == 0, "depositValue should be divisble by ticketPrice");
        // uint ticketCount = depositAmount / ticketPrice;
        // require(ticketCount <= MAX_TICKET_PER_DEPOSIT, "Number of ticket exceeds");
        
        // // push
        // for(uint i = 0; i < ticketCount; ++i) {
        //     tickets[matchId].push(playerAddress);
        // }
        // players[matchId][playerAddress].depositAmount += depositAmount;
        // // emit events
        // emit DepositEvent(matchId, playerAddress, depositAmount, ticketCount);
    }

    // call this function to publish lottery result
    // if not enough winining ticket published, no one can withdraw money
    function publish_lottery_result(string memory matchId) public expiredMatch(matchId) {
    	// check auctionCreator, auctionId validity
    	// check if desired block generated
    	
    	// read match information
        Match memory amatch =  matches[matchId];
    	uint futureBlock = amatch.futureBlock;
    	uint winningCount = amatch.winningCount;
    	address[] storage matchTickets = tickets[matchId];
    	
    	// check: valid block 
    	// check winningCount exceeds min(maxWinning or max ticket count)
    	
    	require(block.number >= futureBlock, "futureBlock is not generated");
    	require(winningCount < amatch.maxWinning, "maxWinning reached");
    	require(winningCount < matchTickets.length, "winningCount reached number of tickets");
    	
        // 	address[] storage matchTickets = tickets[matchId];
        address previousWinner = ADDRESS_NULL;
    	if (winningCount > 0) {
    	    previousWinner = matchTickets[winningCount - 1];
    	}
    	
    	uint nextWinner = randrange(winningCount, tickets[matchId].length, futureBlock, previousWinner);
    	(matchTickets[winningCount], matchTickets[nextWinner]) = (matchTickets[nextWinner], matchTickets[winningCount]);
    	address winnerAddress = matchTickets[nextWinner];
    	// increase ticketWon
    	players[matchId][winnerAddress].ticketWon ++;
    	// increase number of win
    	matches[matchId].winningCount ++;
    	// emit events
    	emit PublishedEvent(matchId, winnerAddress, matches[matchId].winningCount);
    }
    
    

    // withdraw the price
    function withdraw(string memory matchId) public expiredMatch(matchId) returns(bool) {
        
        Player storage player = players[matchId][msg.sender];
        Match memory amatch = matches[matchId];
        
        // prevent withdrawal when maxWinning not reached
        require(amatch.winningCount == min(amatch.maxWinning, tickets[matchId].length), "Match is not over, call to publish_lottery_result to publish tickets");
        
        // depositAmount
        require(player.depositAmount > 0, "player has no deposit amount for this match");
    	
    	// TODO: Use safemath
    	uint depositAmount = player.depositAmount;
    	uint ticketWon = player.ticketWon;
    	// send win token first
    	// in case sending token fails, we just restore 
    	
    	// TODO: Add ERC20 token here
    	if (ticketWon > 0) {
    	    
    	    player.ticketWon = 0;
    	    uint reward = ticketWon * matches[matchId].ticketReward;
        	if (!payable(msg.sender).send(reward)) {
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
    	if (!payable(msg.sender).send(depositAmount)) {
    	    // just restore 
    	    player.depositAmount = depositAmount;
    	    // fail with full withdrawal
    	    return false;
    	}
    	return true;
    }
    
    function getTimestamp() public view returns(uint) {
        return block.timestamp;
    }
    
    function getMatch(string memory matchId) public view returns(uint, uint, uint) {
        return (matches[matchId].winningCount, matches[matchId].maxWinning, matches[matchId].expiryDate);
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
}
