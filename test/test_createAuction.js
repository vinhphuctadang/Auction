const assert = require("assert")
const logger = require("./logger")
const Auction = artifacts.require("Auction")
const USDC_TOKEN = artifacts.require("USDC_TOKEN")
const BAM_TOKEN = artifacts.require("BAM_TOKEN")
const Helper = artifacts.require("Helper")

contract("Test (create) auction", accounts => {
    let Tony = accounts[0], Thor = accounts[1], Steve = accounts[2];

    let auctionContract, 
        usdcContract, 
        bamContract,
        helperContract;

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
        await bamContract.transfer(Steve, "1200", {from: Tony});
    })

    it("should not let create auction having id occupied", async()=>{
        // Thor creates aution first
        let tx
        // Thor approve bam token
        tx = await bamContract.approve(auctionContract.address,  100, { from: Thor });
        logger.debug("thor approve tx log:", tx);
        // Thor create
        tx = await auctionContract.auction("thorMatch", parseInt(Date.now() / 1000) + 10, 5000, 10, 2, 10, bamContract.address, {from : Thor});
        logger.debug(tx.logs[0].args);
        
        // Tony create the same code:
        try {
            tx = await auctionContract.auction("thorMatch", parseInt(Date.now() / 1000) + 10, 1000, 10, 2, 10, bamContract.address, {from : Tony});
        }
        catch(err) {
            logger.error("error creating auction:", err.toString())
            assert.strictEqual(err.reason, "matches with given matchId is occupied"); // , "error is not matches with given matchId is occupied, actual:" + err.reason);
        }
    })

    it("should not let create auction having future block <= currentBlock", async()=>{
        
        let tx, blockCount = parseInt(await helperContract.get_block_count({from: Tony}))
        // logger.debug("Current block:", blockCount)
        try {
            tx = await auctionContract.auction("tonyMatch", parseInt(Date.now() / 1000) + 10, blockCount - 1, 10, 2, 10, bamContract.address, {from : Tony});
        }
        catch(err){
            logger.error(err.toString())
            assert.strictEqual(err.reason, "expiry date or block must be in the future")
        }
    })

    it("should not let create auction having expiryDate <= now", async()=>{
        let tx, blockCount = parseInt(await helperContract.get_block_count({from: Tony}))
        // logger.debug("Current block:", blockCount)
        try {
            tx = await auctionContract.auction("tonyMatch", parseInt(Date.now() / 1000) - 10, blockCount + 10, 10, 2, 10, bamContract.address, {from : Tony});
        }
        catch(err){
            logger.error(err.toString())
            assert.strictEqual(err.reason, "expiry date or block must be in the future")
        }
    })

    it("should not let create when maxWining == 0", async()=>{
        let tx, blockCount = parseInt(await helperContract.get_block_count({from: Tony}))
        try {
            tx = await auctionContract.auction("tonyMatch", parseInt(Date.now() / 1000) + 10, blockCount + 10, 0, 2, 10, bamContract.address, {from : Tony});
        }
        catch(err){
            logger.error(err.toString())
            assert.strictEqual(err.reason, "maxWinningTicket must be greater than 0")
        }
    })

    it("should not let create when not enough amount transferred to contract", async()=>{
        let tx, blockCount = parseInt(await helperContract.get_block_count({from: Tony}))
        try {
            tx = await auctionContract.auction("tonyMatch", parseInt(Date.now() / 1000) + 10, blockCount + 10, 15, 2, 10, bamContract.address, {from : Tony});
        }
        catch(err){
            logger.error(err.toString())
            assert.strictEqual(err.reason, "ERC20: transfer amount exceeds allowance")
        }
    })

    it("should let create normally", async()=>{

        let tx
        // Tony approve to send Bam to contract
        tx = await bamContract.approve(auctionContract.address,  100, { from: Tony });

        let blockCount = parseInt(await helperContract.get_block_count({from: Tony}))
        let expiryDate = parseInt(Date.now() / 1000) + 10
        tx = await auctionContract.auction("tonyMatch", expiryDate, blockCount + 10, 10, 2, 10, bamContract.address, {from : Tony});
        // check emitted event
        logger.debug("Event:", tx.logs);

        // check created information by using getter
        let amatch = await auctionContract.get_match("tonyMatch");
        // logger.debug("Match:", amatch);
        // standardize to js primitive type

        let matchData = []
        for(let key in amatch) {
            let x = amatch[key].toString()
            // string case
            matchData.push(x);
        }

        logger.debug("Match:", matchData);
        
        // check meta:
        // amatch.creatorAddress,
        // amatch.ticketReward,
        // amatch.tokenContractAddress, 
        // amatch.ticketPrice,
        // amatch.expiryDate,
        // amatch.futureBlock,
        // amatch.winningCount, 
        // amatch.maxWinning,
        // amatch.randomUpperbound
        let expectedMatchData = [
            Tony,
            '10',
            bamContract.address,
            '2',
            expiryDate.toString(),
            (blockCount + 10).toString(),
            '0',
            '10',
        ]

        // deep equals just produces weird error on types
        assert.strictEqual(JSON.stringify(matchData), JSON.stringify(expectedMatchData));
    })
})