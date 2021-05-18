const assert = require("assert")
const logger = require("./logger")
const utils = require('./utils')

// contracts
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
        let blockCount = parseInt(await helperContract.get_block_count({from: Tony}))
        // Thor approve bam token
        tx = await bamContract.approve(auctionContract.address,  100, { from: Thor });
        logger.debug("thor approve tx log:", tx);
        // Thor create
        tx = await auctionContract.auction("thorMatch", blockCount + 5, blockCount + 10, 10, 2, 10, bamContract.address, 0, {from : Thor});
        logger.debug("auction() gas used:", tx.receipt.gasUsed);
        
        // Tony create the same code:
        try {
            tx = await auctionContract.auction("thorMatch", blockCount + 5, blockCount + 20, 10, 2, 10, bamContract.address, 0, {from : Tony});
        }
        catch(err) {
            logger.error("error creating auction:", err.toString())
            return assert.strictEqual(err.reason, "matches with given matchId is occupied"); // , "error is not matches with given matchId is occupied, actual:" + err.reason);
        }
    })

    it("should not let create auction having expiry block <= current block", async()=>{
        let tx, blockCount = parseInt(await helperContract.get_block_count({from: Tony}))
        // logger.debug("Current block:", blockCount)
        try {
            tx = await auctionContract.auction("tonyMatch", blockCount - 1, blockCount + 1, 10, 2, 10, bamContract.address, 0, {from : Tony});
        }
        catch(err){
            logger.error(err.toString())
            return assert.strictEqual(err.reason, "future block > expiryBlock > current chain length")
        }
        throw `It should throw "future block > expiryBlock > current chain length" but actually it does not` 
    })

    it("should not let create auction having future block = blockCount + 10 == currentBlock = blockCount + 10", async()=>{
        let tx, blockCount = parseInt(await helperContract.get_block_count({from: Tony}))
        // logger.debug("Current block:", blockCount)
        try {
            tx = await auctionContract.auction("tonyMatch", blockCount + 10, blockCount + 10, 10, 2, 10, bamContract.address, 0, {from : Tony});
        }
        catch(err){
            logger.error(err.toString())
            return assert.strictEqual(err.reason, "future block > expiryBlock > current chain length")
        }
        throw `It should throw "future block > expiryBlock > current chain length" but actually it does not`
    })

    it("should not let create auction having future block = blockCount + 9 < currentBlock = blockCount + 10", async()=>{
        let tx, blockCount = parseInt(await helperContract.get_block_count({from: Tony}))
        // logger.debug("Current block:", blockCount)
        try {
            tx = await auctionContract.auction("tonyMatch", blockCount + 10, blockCount + 9, 10, 2, 10, bamContract.address, 0, {from : Tony});
        }
        catch(err){
            logger.error(err.toString())
            return assert.strictEqual(err.reason, "future block > expiryBlock > current chain length")
        }
        throw `It should throw "future block > expiryBlock > current chain length" but actually it does not`
    })

    it("should not let create when maxWining == 0", async()=>{
        let tx, blockCount = parseInt(await helperContract.get_block_count({from: Tony}))
        try {
            tx = await auctionContract.auction("tonyMatch", blockCount + 5, blockCount + 10, 0, 2, 10, bamContract.address, 0, {from : Tony});
        }
        catch(err){
            logger.error(err.toString())
            return assert.strictEqual(err.reason, "maxWinningTicket must be greater than 0")
        }

    })

    it("should not let create when not enough amount transferred to contract", async()=>{
        let tx, blockCount = parseInt(await helperContract.get_block_count({from: Tony}))
        try {
            tx = await auctionContract.auction("tonyMatch", blockCount + 5, blockCount + 10, 15, 2, 10, bamContract.address, 0, {from : Tony});
        }
        catch(err){
            logger.error(err.toString())
            return assert.strictEqual(err.reason, "ERC20: transfer amount exceeds allowance")
        }
    })

    it("should let create normally, no cap per address limit", async()=>{
        let tx
        // Tony approve to send Bam to contract
        tx = await bamContract.approve(auctionContract.address, 100, { from: Tony });

        let blockCount = parseInt(await helperContract.get_block_count({from: Tony}))
        tx = await auctionContract.auction("tonyMatch", blockCount + 5, blockCount + 10, 10, 2, 10, bamContract.address, 0, {from : Tony});
        logger.debug("auction() gas used:", tx.receipt.gasUsed);
        // check emitted event
        logger.debug("Event:", tx.logs);
        utils.eventEquals(tx, "CreateAuctionEvent", {
            matchId: "tonyMatch",
            auctionCreator: Tony,
            maxWinning: 10,
            ticketPrice: 2,
            ticketReward: 10,
            tokenContractAddress: bamContract.address
        })

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
        // amatch.capPerAddress
        let expectedMatchData = [
            Tony,
            '10',
            bamContract.address,
            '2',
            (blockCount + 5).toString(),
            (blockCount + 10).toString(),
            '0',
            '10',
            '115792089237316195423570985008687907853269984665640564039457584007913129639935' // max uint 128, use python to compute this value LOL
        ]

        // deep equals just produces weird error on types
        assert.strictEqual(JSON.stringify(matchData), JSON.stringify(expectedMatchData));
    })

    it("should let create auction normally, capPerAddress limit == 19", async()=>{
        let tx
        // Tony approve to send Bam to contract
        tx = await bamContract.approve(auctionContract.address, 1000, { from: Tony });

        let blockCount = parseInt(await helperContract.get_block_count({from: Tony}))
        let capPerAddress = 19

        tx = await auctionContract.auction("tonyMatchExtra", blockCount + 6, blockCount + 9, 10, 2, 100, bamContract.address, capPerAddress, {from : Tony});
        logger.debug("auction() gas used:", tx.receipt.gasUsed);
        // check emitted event
        logger.debug("Event:", tx.logs);
        utils.eventEquals(tx, "CreateAuctionEvent", {
            matchId: "tonyMatchExtra",
            auctionCreator: Tony,
            maxWinning: 10,
            ticketPrice: 2,
            ticketReward: 100,
            tokenContractAddress: bamContract.address
        })

        // check created information by using getter
        let amatch = await auctionContract.get_match("tonyMatchExtra");
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
        // amatch.capPerAddress
        let expectedMatchData = [
            Tony,
            '100',
            bamContract.address,
            '2',
            (blockCount + 6).toString(),
            (blockCount + 9).toString(),
            '0',
            '10',
            capPerAddress.toString()
        ]

        // deep equals just produces weird error on types
        assert.strictEqual(JSON.stringify(matchData), JSON.stringify(expectedMatchData));
    })
})