# Auction for randomizingly swap token
---

Features:

- Create auction
- Allow people to call pubish_lottery_result()
- Automatically send token to winner on withdrawal calls

## Setup:

** We should use docker for development **

- Download docker:

```
Please follow instruction on https://docs.docker.com/engine/install/ubuntu/
```

- Run ganache cli:

```
docker run -d -p 7777:8545 trufflesuite/ganache-cli
```

* Docker will automatically download ganache-cli image *

I love the port 7777, you could change this port in ``truffle-config.js``, but I think we should not do that.

- Install truffle 

```
npm install -g truffle
```

- Install modules

```
npm i
```

## Run tests

```
truffle test
```

Make sure that every test works before investigating contract details


## Contract ideas:

Design:

Files:

``Auction.sol``: Main contract

``Helper.sol``: Contract for testing purpose

``BAM_TOKEN.sol``, ``USDC_TOKEN.sol``: Token contracts (ERC20)

``Migration.sol``: Truffle generated contract

2 main actors:

- Creator: Creator has token (e.g BAM) for sales but he needs random sale => so he deposit his BAM into contract and have it to choose random candidate (let's say player) to win BAM

- Player: Candidate who deposits his/her money into contract to win BAM

3 entities:

- Match: an auction session that has creators, players, reward tokens, deposit tokens

- Usdc contract: a base stable currency contract for depositing. Contract is initialized with this currency and use it forever.

- Reward token contract: contract having token for rewarding 

Scenario:

- Creators can create auction, using call to auction(), in which he needs: 
    + a valid, unoccupied match id
    + valid amount of reward token in reward token contract (says, BAM)
    + positive number of max winning ticket
    + an expirydate
    + a future block that will be the future randseed (be careful when chosing this)

  Creators can also withdraw usdc by calling to creator_withdraw_profit(), only when a winning lottery revealed.
  He/she is also able to **withdraw his deposit (BAM)** as long as there are remaining BAM (this case occurs when number of ticket < max winning count) 

- Match has 3 status:
    + OPENED: when expiryDate >= current block timestamp, players are allowed to deposit and are returned with number tickets
    + CLOSED: when expiryDate < current block timestamp, players are not allowed to deposit and wait for future block to be generated, then players are able to call to publish_lottery_result to reveal winners
    + FINISHED: when all winning ticket reaches the match's pre-set max winning ticket, every player having tickets can withdraw, either they win or lose

- Players can join a match, may be eligible to call to publish_lottery_result; for winning tickets, players are rewarded with new token, for losing ticket, usdc tokens returned. Thus, win or lose does not cost, only gas fee required
Util all winning tickets revealed, no one can withdraw **except for creators can withdraw his usdc** from contract.
Player can withdraw reward tokens and/or deposited token of their choice.

In brief:

```
function auction(
        string memory matchId, uint96 expiryBlock, uint96 futureBlock, 
        uint32 maxWinning, uint96 ticketPrice, uint96 ticketReward, 
        address tokenContractAddress, uint capPerAddress
) public payables
```

Create an auction, msg.sender will be address holds token in tokenContractAddress and is valid address on usdcContract as well to create and withdraw after the auction finished

- ``matchId``: a valid string chosen by the creator and shoud be unique in the contract scope.
- ``capPerAddress``: maximum number of ticket that a player in this auction can deposit for. 0 for infinity (2^128 max)

--- 

```
function deposit(string memory matchId, uint amount) public payable validMatch(matchId)
```

Players call deposit for buying tickets, currentTicketCount + amount must not exceeds capPerAddress specified by the auction creator, number of players not exceed 2^32-1

**Note**
Players must have account in usdcContract and approve a valid amount to the auctionContract before depositing.

---

```
function creator_withdraw_deposit(string memory matchId) public creatorOnly(matchId) matchFinished(matchId)
```

Creator call to this function to withdraw all his unused Reward when the match has ended.


```
function creator_withdraw_profit() public payable { // creator withdraw his balance
```
Creator withdraws the profit he earn from publish_lottery_result, where he is paied with usdc for each publish call


```
function player_withdraw_reward(string memory matchId, address payable newTokenRecipient) public matchFinished(matchId)
```

Player withdraw rewarded token, note that there will be newTokenRecipient

```
function player_withdraw_deposit(string memory matchId) public matchFinished(matchId)
```

Players use this function to withdraw losing tickets when matches finished 
        
## Acknowledgement:

This repository uses contracts (ERC20) and derives safemMath library from https://openzeppelin.com/contracts/