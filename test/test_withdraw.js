const assert = require("assert")
const logger = require("./logger")
const Auction = artifacts.require("Auction")
const USDC_TOKEN = artifacts.require("USDC_TOKEN")
const BAM_TOKEN = artifacts.require("BAM_TOKEN")
const Helper = artifacts.require("Helper")

async function sleep(ms){
	return new Promise((resolve,reject)=>{
		setTimeout(()=>{
			resolve()
		}, ms)
	})
}

contract("Test withdraw reward token", accounts => {
    let Tony = accounts[0], 
        Thor = accounts[1], 
        Steve = accounts[2],
        Banner = accounts[3],
        Natasha = accounts[4];

    let auctionContract, 
        usdcContract, 
        bamContract,
        helperContract;
    
    let depositAmount = {
        [Steve]: 15,
        [Banner]: 15, 
        [Tony]: 20
    }
    let addressToName = {
        [Tony]: 'tony',
        [Thor]: 'thor',
        [Steve]: 'steve',
        [Banner]: 'banner',
        [Natasha]: 'natasha'
    }

    const bamReward = 10
    const ticketPrice = 5
    let expectedFutureBlock

    let winnerAddress

    it("should properly deploy contracts", async()=> {
        // require 4 contracts to be deployed 
        // create helper contract
        helperContract = await Helper.new({from: Tony})

        // create usdc contract 
        usdcContract = await USDC_TOKEN.new({from: Tony})
        logger.debug("usdcAddr:", usdcContract.address);
        assert(usdcContract.address != "", "USDC address is null")
        
        // create bam contract
        bamContract  = await  BAM_TOKEN.new({from: Tony})
        logger.debug("bamAddr:", bamContract.address)
        assert(bamContract.address != "", "BAM address is null");

        // create auction contract
        auctionContract = await Auction.new(usdcContract.address, {from: Tony})
        logger.debug("auctionContract:", auctionContract.address);
        assert(auctionContract.address != "", "Auction address is null");

        // transfer money
        // we believe ERC20 transfer method !
        await usdcContract.transfer(Banner,  "1000", {from: Tony});
        await usdcContract.transfer(Steve, "1200", {from: Tony});
        await bamContract.transfer(Thor, "1200", {from: Tony});
    })

    it("should successfully create a valid match", async()=>{
        // Thor creates aution first
        let tx
        // Thor approve bam token
        tx = await bamContract.approve(auctionContract.address,  20, { from: Thor });
        let blockCount = parseInt(await helperContract.get_block_count({from: Thor}))
        expectedFutureBlock = blockCount + 20

        logger.debug("thor balance approval tx log:", tx.logs);

        timeMarker = parseInt(Date.now() / 1000)
        // Thor create a match
        tx = await auctionContract.auction("thorMatch", timeMarker + 10, expectedFutureBlock, 2, ticketPrice, bamReward, bamContract.address, {from : Thor});
        logger.debug(tx.logs[0].args);
    })

    it("should properly deposit", async()=>{
        let tx
        totalTicket = 0
        for(let player in depositAmount) {
            let amount = depositAmount[player]
            logger.info(`${addressToName[player]} starts deposit amount of ${amount}, playerAddress=${player}`)
            
            await usdcContract.approve(auctionContract.address, amount, { from: player });
            tx = await auctionContract.deposit("thorMatch", amount, {from: player});

            // get player to check again
            player = await auctionContract.get_player("thorMatch", player, { from: player });
            assert.strictEqual(player[0].toString(), parseInt(amount / ticketPrice).toString())
            assert.strictEqual(player[1].toString(), '0')

            totalTicket += parseInt(amount / ticketPrice)
        }
    })

    it("should deny withdraw when the match is not closed", async()=>{
        try {
            await auctionContract.player_withdraw_reward("thorMatch", Steve, {from: Steve})
        }
        catch(err) {
            logger.debug(err.toString())
            return assert.strictEqual(err.reason, "invalid match or match is not closed yet");
        }
    })

    it("should deny withdraw when match is not finished (all result are not revealed)", async()=>{
        let tx
        // lets wait for 10 seconds 
        let sleepTime = 12
        logger.info(`Wait ${sleepTime}s for thorMatch match to close`);
        await sleep(sleepTime * 1000)

        let blockCount = parseInt(await helperContract.get_block_count({from: Thor}))
        for(let i = blockCount; i <= expectedFutureBlock; ++i) {
            logger.info(`Creating block ${i+1}, target: >${expectedFutureBlock} ...`)
            // generate (expectedFutureBlock - blockCount + 1) blocks (to when future block created)
            await helperContract.dummy_assign()
        }

        tx = await auctionContract.publish_lottery_result("thorMatch", {from: Natasha})
        logger.debug("publish_lottery_result tx gas used:", tx.receipt.gasUsed);
        winnerAddress = tx.logs[0].args[1]
        
        logger.info("Winner try to withdraw")
        try {
            await auctionContract.player_withdraw_reward("thorMatch", winnerAddress, {from: winnerAddress})
        }
        catch(err) {
            logger.debug(err.toString())
            return assert.strictEqual(err.reason, "match is not finished");
        }
    })

    it("shoud reveal the last winner and allow a winner to withdraw bam token", async()=>{
        let tx
        tx = await auctionContract.publish_lottery_result("thorMatch", {from: Natasha})
        logger.debug("publish_lottery_result tx gas used:", tx.receipt.gasUsed);
        winnerAddress = tx.logs[0].args[1]

        // get player
        let player = await auctionContract.get_player("thorMatch", winnerAddress)
        let previousTotalTicket = player[0].toNumber()
        let winningCount = player[1].toNumber()
        assert(winningCount > 0, `Expect: winning count > 0, actual winning: ${winningCount}`)

        // get current BAM of winnerAddress 
        let previousWinerBalance = await bamContract.balanceOf(winnerAddress)
        let previousContractBalance = await bamContract.balanceOf(auctionContract.address)
        let previousCreatorBalance = await auctionContract.get_creator_balance(Thor)

        tx = await auctionContract.player_withdraw_reward("thorMatch", winnerAddress, {from: winnerAddress})
        logger.debug("player_withdraw_reward tx gas used:", tx.receipt.gasUsed);
        let currentWinerBalance = await bamContract.balanceOf(winnerAddress)
        let currentContractBalance = await bamContract.balanceOf(auctionContract.address)
        let currentCreatorBalance = await auctionContract.get_creator_balance(Thor)

        assert.strictEqual(currentWinerBalance    - previousWinerBalance,       bamReward * winningCount)
        assert.strictEqual(currentContractBalance - previousContractBalance,  - bamReward * winningCount)

        // creator balance is not changed
        assert.strictEqual(currentCreatorBalance  - previousCreatorBalance,    0) 

        player = await auctionContract.get_player("thorMatch", winnerAddress)
        let totalTicket = player[0].toNumber(), 
            currentWinningCount = player[1].toNumber()
        assert.strictEqual(totalTicket, previousTotalTicket - winningCount)
        assert.strictEqual(currentWinningCount, 0)
    })

    it("shoud deny withdraw when winning count == 0", async()=>{
        let addressHavingNoWinning;
        // figure out who have no ticket
        for(let playerAddress in depositAmount) {
            let player = await auctionContract.get_player("thorMatch", playerAddress)
            if (player['1'].toNumber() == 0) { 
                addressHavingNoWinning = playerAddress; 
                break; 
            }
        }
        // that person is not allowed to withdraw
        try {
            await auctionContract.player_withdraw_reward("thorMatch", addressHavingNoWinning, {from: addressHavingNoWinning})
        }
        catch(err) {
            logger.debug(err.toString())
            return assert.strictEqual(err.reason, "must have winning ticket to withdraw");
        }
        throw `It should throw error "must have winning ticket to withdraw" but actually it does not`
    })

    it("should allow player to withdraw usdc and verify balances of all players", async()=>{
        for(let playerAddress in depositAmount) {
            // get current player tickets
            let player = await auctionContract.get_player("thorMatch", playerAddress)
            let previousTotalTicket = player[0].toNumber()
            let previousWinningCount = player[1].toNumber()
            let previousPlayerUsdc = (await usdcContract.balanceOf(playerAddress)).toNumber()

            let tx = await auctionContract.player_withdraw_deposit("thorMatch", { from: playerAddress })
            logger.debug("player_withdraw_deposit tx gas used:", tx.receipt.gasUsed);

            player = await auctionContract.get_player("thorMatch", playerAddress)
            let currentTotalTicket = player[0].toNumber()
            let currentWinningCount = player[1].toNumber()
            let currentPlayerUsdc = (await usdcContract.balanceOf(playerAddress)).toNumber()
            
            // money in wallet first
            assert.strictEqual(currentPlayerUsdc - previousPlayerUsdc, (previousTotalTicket - currentTotalTicket) * ticketPrice,
                `previousPlayerUsdc: ${previousPlayerUsdc}, currentPlayerUsdc ${currentPlayerUsdc}`)
            // no changes in creator balance
            // check in contract
            assert.strictEqual(currentWinningCount, previousWinningCount)
            assert.strictEqual(currentTotalTicket, previousWinningCount, 
                `player ${addressToName[playerAddress]} have current ticket of ${currentTotalTicket}, previous: ${previousTotalTicket}, expected: ${previousWinningCount},
                but the fact is ${currentTotalTicket - previousTotalTicket}`)
        }
    })

    it("should allow creator to withdraw usdc", async()=>{
        let previousCreatorBalance = await auctionContract.get_creator_balance(Thor)
        let tx = await auctionContract.creator_withdraw({from: Thor})
        logger.debug("creator_withdraw tx gas used:", tx.receipt.gasUsed);
        let currentCreatorBalance = await auctionContract.get_creator_balance(Thor)
        // verify that money is withdrawed
        assert.strictEqual(currentCreatorBalance.toNumber(), 0)
        assert.strictEqual((await usdcContract.balanceOf(Thor)).toNumber(), previousCreatorBalance.toNumber())
    })

    it("should not allow Natasha to withdraw as creator when she has no balance", async()=>{
        try {
            await auctionContract.creator_withdraw({from: Natasha})
        }
        catch(err) {
            logger.debug(err.toString())
            return assert.strictEqual(err.reason, "creator balance must be greater than 0");
        }
        throw `It should throw error "creator balance must be greater than 0" but actually it does not`
    })

    it("should not allow Natasha to withdraw because she has no tickets", async()=>{
        try {
            await auctionContract.player_withdraw_deposit("thorMatch", {from: Natasha})
        }
        catch(err) {
            logger.debug(err.toString())
            return assert.strictEqual(err.reason, "there must be losing ticket to withdraw");
        }
        throw `It should throw error "creator balance must be greater than 0" but actually it does not`
    })
})