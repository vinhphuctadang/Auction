// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;


contract Auction {
    
    // constants
    address constant ADDRESS_NULL = 0x0000000000000000000000000000000000000000;
    uint    constant MAX_TICKET_PER_DEPOSIT = 100;
    
    struct Match {
        address creatorAdress;
        uint totalReward;
        uint ticketPrice; 
        uint ticketReward;
        uint expiryDate;
        uint futureBlock;
        uint winingCount;
        uint maxWining;
    }
    
    // state data
    // match id -> Match
    mapping(string => Match) matches;
    mapping(string => address[]) tickets;
    
    
    // modifiers
    modifier creatorOnly(address creatorAddress, string memory matchId) {
        require(creatorAddress != ADDRESS_NULL && matches[matchId].creatorAdress == creatorAddress, "Caller must be creator of this match");
        _;
    }

    modifier validMatch(string memory matchId) {
        Match storage amatch = matches[matchId];
        require(amatch.creatorAdress != ADDRESS_NULL, "Invalid creator");
        require(amatch.expiryDate < block.timestamp, "Match is unable to deposit");
        _;
    }

    // events
    // event Deposit(address player, uint value);
    constructor(){
        // init
    }
    
    // functions
    // TODO: Notice case where maxWiningTicket > number of ticket bought
    function auction(string memory matchId, uint expiryDate, uint futureBlock, uint maxWining, uint ticketPrice, uint rewardPerTicket) public payable {
        // use SafeMath (not safeMoon T,T)
        address creatorAdress = msg.sender;
        uint totalReward = msg.value;
        // check match validity:
        // check occupied slot 
        // check expiryDate ( >= now)
        // check future block is valid
        // check rewardPerTicket
        // check amount == rewardPerTicket * maxWiningTicket
        require(matches[matchId].creatorAdress == ADDRESS_NULL, "Matches with given matchId is occupied");
        require(expiryDate > block.timestamp, "expiryDate must be in the future");
        require(futureBlock > block.number,   "futureBlock must be greater than current block");
        require(rewardPerTicket > 0, "rewardPerTicket must be greater than 0");
        require(maxWining > 0, "maxWiningTicket must be greater than 0");
        require(ticketPrice > 0, "ticketPrice must be greater than 0");
        
        // TODO: use safemath
        require(maxWining * rewardPerTicket == totalReward, "sent amount must be equals to maxWiningTicket * rewardPerTicket");
        
        // store match
        matches[matchId] = Match(creatorAdress, totalReward, ticketPrice, rewardPerTicket, expiryDate, 0, maxWining, futureBlock);
        // emit creating auction event
    }
    
    function deposit(string memory matchId) public payable validMatch(matchId) {
        
        uint depositValue = msg.value;
        uint ticketPrice =  matches[matchId].ticketPrice;
        require(depositValue > 0, "depositValue must be greater than 0");
        require(depositValue % ticketPrice == 0, "depositValue should be divisble by ticketPrice");
        uint numberTicket = depositValue / ticketPrice;
        require(numberTicket <= MAX_TICKET_PER_DEPOSIT, "Number of ticket exceeds");
        // TODO: Add to tickets
        // check if sender amount is divisble by ticketPrice
        // check if match limit reach 
        // generate hashes
        // store hashes and inverted  
        // emit events
    }
    
    // call this function to check if the block hash for the randomness seed has been generated
    function publish_lottery_result(string memory matchId) public validMatch(matchId) {
    	// check auctionCreator, auctionId validity
    	// check if desired block generated
    	uint futureBlock = matches[matchId].futureBlock;
    	uint winingCount = matches[matchId].winingCount;
    	
    	require(block.number >= matches[matchId].futureBlock, "futureBlock is not generated");
    	require(winingCount < matches[matchId].maxWining, "maxWining reached");
    	address[] storage matchTickets = tickets[matchId];
    	
    	bytes32 hash = blockhash(futureBlock - 1);
    	
    	// compute randrange(numWin, tickets.length-1);
    	
    	// swap matchTickets[i] and [j]
    	
    	// pay
    }
    
    // withdraw the price
    function withdraw(string memory matchId) public validMatch(matchId) {
    	// check for valid host, auctionId
    	// check if hashes in won hashes
    	
    	// check how many tickets win
    	// send BAM and USDC
    }
    
    function min(uint x, uint y) private returns(uint){
        return (x > y ? y : x);
    }

    function creatorWithdraw(string memory matchId) public creatorOnly(msg.sender, matchId) {
        Match storage amatch = matches[matchId];
        require(amatch.expiryDate >= block.timestamp, "Match is not over");
        require(amatch.winingCount >= min(tickets[matchId].length, amatch.maxWining), "Match is not over");
        
        // withdraw 
        // remember to set count == 0 first
    }
}
