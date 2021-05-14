// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Auction {
    // enum 
    enum MatchStatus { OPENED, CLOSED, FINISHED }
    
    // constants
    address constant ADDRESS_NULL = 0x0000000000000000000000000000000000000000;
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
    struct Match { // 3 uint256
        address creatorAddress; // 20 bytes
        address tokenContractAddress; // 20 bytes
        uint96  ticketReward;
        uint96  ticketPrice;
        
        uint64  expiryDate;
        uint128 futureBlock;
        uint32  winningCount; // winning ticket count
        uint32  maxWinning; // max wining
        
        uint randomUpperbound;
    }
    
    // state data
    // match id -> Match
    mapping(string => Match) matches;
    // match player id
    mapping(string => mapping(address => uint)) matchPlayerId;
    // player information for a match
    mapping(string => Player[]) players;
    
    // modifiers
    // modifier creatorOnly(address creatorAddress, string memory matchId) {
    //     require(creatorAddress != ADDRESS_NULL && matches[matchId].creatorAdress == creatorAddress, "Caller must be creator of this match");
    //     _;
    // }

    modifier validMatch(string memory matchId) {
        Match storage amatch = matches[matchId];
        require(amatch.creatorAddress != ADDRESS_NULL, "Creator is invalid");
        _;
    }
    
    modifier matchStatus(string memory matchId, MatchStatus status) { // -1 for check
        Match memory amatch = matches[matchId]; // read 4 uint, 800*4 ~ 3200 gas
        require(amatch.creatorAddress != ADDRESS_NULL, "Invalid match");
        if (status == MatchStatus.OPENED) {
            // allow people to deposit
            require(amatch.expiryDate < block.timestamp, "Match is not open to deposit");
        }
        else if (status == MatchStatus.CLOSED) {
            // close does not means that they can withdraw
            require(amatch.expiryDate > block.timestamp, "Match is not closed");
        }
        else if (status == MatchStatus.FINISHED) {
            require(amatch.expiryDate > block.timestamp, "Match is not closed to be finished");
            // match finished when winning count reaches maxWinning, or reach number of tickets
            if (amatch.winningCount < amatch.maxWinning && players[matchId].length > 0) {
                // last person is rewarded
                require(players[matchId][0].winningCount == players[matchId][0].ticketCount, "Match is not finished");
            }
            // else match is finished
        }
        _;
    }

    // events
    event DepositEvent(string matchId, address player, uint depositAmount, uint ticketCount);
    event PublishedEvent(string matchId, address winner, uint winningOrder);
    event CreateAuctionEvent(string matchId, address auctionCreator, uint maxWinning, uint ticketPrice, uint rewardPerTicket, address tokenContractAddress);
    
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
    function auction(
        string memory matchId, uint64 expiryDate, uint128 futureBlock, 
        uint32 maxWinning, uint96 ticketPrice, uint96 ticketReward, 
        address tokenContractAddress
    ) public payable {
        // use SafeMath (not safeMoon T,T)
        address creatorAddress = msg.sender;
        // check match validity:
        // check occupied slot 
        // check expiryDate ( >= now)
        // check future block is valid
        // check rewardPerTicket
        // check amount == rewardPerTicket * maxWinningTicket
        require(matches[matchId].creatorAddress == ADDRESS_NULL, "Matches with given matchId is occupied");
        require(expiryDate > block.timestamp, "expiryDate must be in the future");
        require(futureBlock > block.number,   "futureBlock must be greater than current block");
        require(ticketReward > 0, "rewardPerTicket must be greater than 0");
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
        // check if sender amount is divisble by ticketPrice
        // check if match limit reach 
        // store tickets and push to queue
        
        // for safety, should limit upper_bound for amount
        uint128 _amount = uint128(amount);
        require(_amount > 0, "deposit amount must be greater than 0");
        
        address playerAddress = msg.sender;
        uint96 ticketPrice   = matches[matchId].ticketPrice; //800 gas
        require(_amount % ticketPrice == 0, "deposit amount should be divisble by ticketPrice");
        
        bool success = ERC20(USDC_ADDRESS).transferFrom(payable(playerAddress), address(this), _amount);
        require(success, "Deposit failed");
        
        uint128 ticketCount = _amount / ticketPrice;
        uint    id = matchPlayerId[matchId][playerAddress];
        if (id == 0) {
            id = players[matchId].length + 1;
            // create new slot
            matchPlayerId[matchId][playerAddress] = id; 
            players[matchId].push(Player(ticketCount, 0));
        }
        else {
            // just increase tickets 
            players[matchId][id - 1].ticketCount += ticketCount;
        }
        
        // emit deposit event
        emit DepositEvent(matchId, playerAddress, amount, ticketCount);
    }

    // // call this function to publish lottery result
    // // if not enough winining ticket published, no one can withdraw money
    function publish_lottery_result(string memory matchId) public {
    	
    	// emit events
    // 	emit PublishedEvent(matchId, winnerAddress, matches[matchId].winningCount);
    }

    // withdraw the price
    function withdraw(string memory matchId) public returns(bool) {
        
    }

    function dummySet(uint a) public {
        // dummyVariable = a;
    }
}
// }