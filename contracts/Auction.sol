// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;


contract Auction {
    
    struct Match {
        uint totalPrice;
        uint expiryDate;
        uint winingCount;
        uint maxWining;
        uint[] ticketIds;
        mapping(uint => address) ticketIdToPlayers;
        // store player data
        
    }

    mapping(address => mapping(string => Match)) matches;

    constructor(){
        // init
    }

    function auction(string memory matchId, uint futureBlock, uint maxWiningTicket, uint rewardPerTicket) public payable {
        // use SafeMath (not safeMoon T,T)
        // check match validity:
            // check occupied slot 
            // check expiryDate ( >= now)
            // check future block is valid
        // check amount == rewardPerTicket * maxWiningTicket
        
        // store struct 
        // matches[msg.sender][matchId] = Match(...)
        // emit creating auction event
    }
    
    function deposit(address creatorAdress, string memory matchId) public payable {
        // check match validity by creatorAdress, matchId
        
        // check if sender amount is divisble by ticketPrice 
        
        // check if match limit reach 
        // generate hashes
        // store hashes and inverted  
        // emit events
    }
    
    // call this function to check if the block hash for the randomness seed has been generated
    function publish_lottery_result(address creatorAdress, string memory matchId) public {
    	// check auctionCreator, auctionId validity
    	// check if desired block generated
    	// compute tickets win -> store hashes (using blockhash) tickets
        // repay full ticket to person calling this
        // emit wining price event 
    }
    
    // withdraw the price
    function withdraw(address creatorAdress, string memory matchId) public {
    	// check for valid host, auctionId
    	// check if hashes in won hashes
    	
    	// check how many tickets win
    	// send BAM and USDC
    }

}
