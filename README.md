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