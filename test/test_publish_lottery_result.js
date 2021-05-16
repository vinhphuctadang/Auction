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

async function get_match(auctionContract, matchId) {
    // check created information by using getter
    let amatch = await auctionContract.get_match(matchId);
    // logger.debug("Match:", amatch);
    // standardize to js primitive type

    let matchData = []
    for(let key in amatch) {
        let x = amatch[key].toString()
        // string case
        matchData.push(x);
    }
    return matchData
}

contract("Test publish lottery result for edge cases", accounts => {
    let Tony = accounts[0], 
        Thor = accounts[1], 
        Steve = accounts[2],
        Banner = accounts[3],
        Natasha = accounts[4];

    let auctionContract, 
        usdcContract, 
        bamContract,
        helperContract;

    let expectedFutureBlock

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
        await bamContract.transfer(Thor,  "1000", {from: Tony});
        await usdcContract.transfer(Steve, "1200", {from: Tony});
        await usdcContract.transfer(Banner, "1200", {from: Tony});
        await usdcContract.transfer(Natasha, "1200", {from: Tony});
    })

    it("should successfully create a valid match", async()=>{
        // Thor creates aution first
        let tx
        // Thor approve bam token
        tx = await bamContract.approve(auctionContract.address,  100, { from: Thor });
        let blockCount = parseInt(await helperContract.get_block_count({from: Thor}))
        expectedFutureBlock = blockCount + 10

        logger.debug("thor balance approval tx log:", tx.logs);

        timeMarker = parseInt(Date.now() / 1000)
        // Thor create a match
        tx = await auctionContract.auction("thorMatch", timeMarker + 25, expectedFutureBlock, 10, 5, 10, bamContract.address, {from : Thor});
        logger.debug(tx.logs[0].args);
    })

    it("shoud not let publish for match id == someMatch (invalid matchId)", async()=> {
        let tx
        try {
            tx = await auctionContract.publish_lottery_result("someMatch", { from: Steve }); 
        }
        catch(err) {
            logger.error(err.toString())
            return assert.strictEqual(err.reason, "invalid match");
        }
        throw `It should throw errors "invalid match" but actually it does not`
    });


    it("shoud not publish result when match is not finished", async()=> {
        let tx
        try {
            tx = await auctionContract.publish_lottery_result("thorMatch", { from: Steve })
        }
        catch(err) {
            logger.error(err.toString())
            return assert.strictEqual(err.reason, "match is not closed");
        }
        throw `It should throw errors "match is not closed" but actually it does not`
    });

    it("shoud not publish result when future block is not generated", async()=> {
        let tx
        // lets wait for 10 seconds 
        let sleepTime = 30
        logger.info(`Wait ${sleepTime}s for 'thorMatch' match to close`);
        await sleep(sleepTime * 1000)

        // sure future block is not generated 
        try {
            tx = await auctionContract.publish_lottery_result("thorMatch", { from: Steve }); 
        }
        catch(err) {
            logger.error(err.toString())
            return assert.strictEqual(err.reason, "future block has not been generated");
        }
        throw `It should throw errors "future block has not been generated" but actually it does not`
    });

    it("shoud not publish result when no one deposits (i.e upperRandomLimit == 0)", async()=> {

        let blockCount = parseInt(await helperContract.get_block_count({from: Thor}))
        for(let i = blockCount; i <= expectedFutureBlock; ++i) {
            logger.info(`Creating block ${i+1}, target: >${expectedFutureBlock} ...`)
            // generate (expectedFutureBlock - blockCount + 1) blocks (to when future block created)
            await helperContract.dummy_assign()
        }
        
        // sure future block is not generated 
        let tx
        try {
            tx = await auctionContract.publish_lottery_result("thorMatch", { from: Steve }); 
        }
        catch(err) {
            logger.error(err.toString())
            return assert.strictEqual(err.reason, "random upper bound should be greater than 0");
        }
        throw `It should throw errors "random upper bound should be greater than 0" but actually it does not`
    });

    // it("should properly deposit", async()=>{
    //     let tx, player
    //     // steve deposit
    //     await usdcContract.approve(auctionContract.address,  15, { from: Steve });
    //     tx = await auctionContract.deposit("thorMatch", 15, {from: Steve});
    //     // get player to check again
    //     player = await auctionContract.get_player("thorMatch", Steve, { from: Steve });
    //     assert.strictEqual(player[0].toString(), '3')
    //     assert.strictEqual(player[1].toString(), '0')
        
    //     // banner depsit
    //     await usdcContract.approve(auctionContract.address,  20, { from: Banner });
    //     tx = await auctionContract.deposit("thorMatch", 20, {from: Banner});
    //     player = await auctionContract.get_player("thorMatch", Banner, { from: Banner });
    //     assert.strictEqual(player[0].toString(), '4')
    //     assert.strictEqual(player[1].toString(), '0')
        
    //     // tony depsoit
    //     await usdcContract.approve(auctionContract.address,  25, { from: Tony });
    //     tx = await auctionContract.deposit("thorMatch", 25, {from: Tony});
    //     player = await auctionContract.get_player("thorMatch", Tony, { from: Tony });
    //     assert.strictEqual(player[0].toString(), '5')
    //     assert.strictEqual(player[1].toString(), '0')  
    // })
    
    // it("shoud publish result and increase win count", async() => {
    //     return; 
    //     let tx
    //     // lets wait for 10 seconds 
    //     let sleepTime = 10
    //     logger.info(`Wait ${sleepTime}s for thorMatch match to close`);
    //     await sleep(sleepTime * 1000)

    //     // random 
    //     tx = await auctionContract.publish_lottery_result("thorMatch")
    //     logger.debug("publish_lottery tx gas used:", tx.receipt.gasUsed);
    //     let winner = tx['0']
    //     player = await auctionContract.get_player("thorMatch", winner, { from: Tony });
    //     // assert.strictEqual(player[0].toString(), '5')
    //     assert.strictEqual(player[1].toString(), '1')
    //     // check player

    // })

    // it("shoud publish result randomly", async()=> {
    //     // first auction 

    //     // second auction with the same number but differnt future block

    // });
})

contract("Test publish lottery result on normal cases", accounts => {
    let Tony = accounts[0], 
        Thor = accounts[1], 
        Steve = accounts[2],
        Banner = accounts[3],
        Natasha = accounts[4];

    let ticketPrice = 5;

    let addressToName = {
        [Tony]: 'tony',
        [Thor]: 'thor',
        [Steve]: 'steve',
        [Banner]: 'banner',
        [Natasha]: 'natasha'
    }

    let depositAmount = {
        [Steve]: 15,
        [Banner]: 20, 
        [Tony]: 25
    }

    let auctionContract, 
        usdcContract, 
        bamContract,
        helperContract;

    let expectedFutureBlock

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
        await bamContract.transfer(Thor,  "1000", {from: Tony});
        await usdcContract.transfer(Steve, "1200", {from: Tony});
        await usdcContract.transfer(Banner, "1200", {from: Tony});
        await usdcContract.transfer(Natasha, "1200", {from: Tony});
    })

    it("should successfully create a valid match", async()=>{
        // Thor creates aution first
        let tx
        // Thor approve bam token
        tx = await bamContract.approve(auctionContract.address,  100, { from: Thor });
        let blockCount = parseInt(await helperContract.get_block_count({from: Thor}))
        expectedFutureBlock = blockCount + 20

        logger.debug("thor balance approval tx log:", tx.logs);

        timeMarker = parseInt(Date.now() / 1000)
        // Thor create a match
        tx = await auctionContract.auction("thorMatch", timeMarker + 10, expectedFutureBlock, 10, ticketPrice, 10, bamContract.address, {from : Thor});
        logger.debug(tx.logs[0].args);
    })

    it("should properly deposit", async()=>{
        let tx, player

        for(let player in depositAmount) {
            let amount = depositAmount[player]
            logger.info(`${addressToName[player]} starts deposit amount of ${amount}, playerAddress=${player}`)
            
            await usdcContract.approve(auctionContract.address, amount, { from: player });
            tx = await auctionContract.deposit("thorMatch", amount, {from: player});

            // get player to check again
            player = await auctionContract.get_player("thorMatch", player, { from: player });
            assert.strictEqual(player[0].toString(), parseInt(amount / ticketPrice).toString())
            assert.strictEqual(player[1].toString(), '0')
        }
    })
    
    it("shoud publish result and increase win count", async() => {
        let tx
        // lets wait for 10 seconds 
        let sleepTime = 10
        logger.info(`Wait ${sleepTime}s for thorMatch match to close`);
        await sleep(sleepTime * 1000)

        let blockCount = parseInt(await helperContract.get_block_count({from: Thor}))
        for(let i = blockCount; i <= expectedFutureBlock; ++i) {
            logger.info(`Creating block ${i+1}, target: >${expectedFutureBlock} ...`)
            // generate (expectedFutureBlock - blockCount + 1) blocks (to when future block created)
            await helperContract.dummy_assign()
        }

        // random 
        tx = await auctionContract.publish_lottery_result("thorMatch", {from: Natasha})
        logger.debug("publish_lottery_result tx gas used:", tx.receipt.gasUsed);
        let winnerAddress = tx.logs[0].args[1]
        
        logger.debug("Winner addr:", winnerAddress, ", alias:", addressToName[winnerAddress])
        player = await auctionContract.get_player("thorMatch", winnerAddress, { from: Tony });

        // check player
        assert.strictEqual(player[0].toString(), parseInt(depositAmount[winnerAddress] / ticketPrice).toString())
        // winning ticket is added by 1
        assert.strictEqual(player[1].toString(), '1')
    })

    it("shoud find that winning tickets does not exceeds number of deposited", async()=> {
        let tx
        let winners = []
        let winnerAddresses = []
        for(let i = 1; i<10; ++i) {
            tx = await auctionContract.publish_lottery_result("thorMatch", {from: Natasha})
            logger.debug("publish_lottery_result tx gas used:", tx.receipt.gasUsed);
            let winnerAddress = tx.logs[0].args[1]

            // 
            winnerAddresses.push(winnerAddress)
            winners.push(addressToName[winnerAddress])
        }
        logger.debug("Winners (respectively):", winners)
        
        // compute winning count of each address
        let count = {} 
        for(let winnerAddress of winnerAddresses) { 
            if (!winners[winnerAddress]) { 
                count[winnerAddress] = 1; 
            } 
            else {
                count[winnerAddress] ++
            } 
        }
        for(let winnerAddress in count) {
            assert(count[winnerAddress] <= parseInt(depositAmount[winnerAddress] / ticketPrice), "Winning ticket exceeds deposited")
        }
    });

    it("should not allow people to publish more result when winningTicket reach max", async()=>{
        let tx
        try {
            tx = await auctionContract.publish_lottery_result("thorMatch", { from: Steve }); 
        }
        catch(err) {
            logger.error(err.toString())
            return assert.strictEqual(err.reason, "max wining reached");
        }
        throw `It should throw errors "max wining reached" but actually it does not`
    })
})