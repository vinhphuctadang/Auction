const assert = require("assert")
const logger = require("./logger")
const Auction = artifacts.require("Auction")
const utils = require("./utils")

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

contract("Test deposit", accounts => {
    let Tony = accounts[0], Thor = accounts[1], Steve = accounts[2];

    let timeMarker
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
        await usdcContract.transfer(Steve, "1200", {from: Tony});
    })

    it("should create a match named thorMatch", async()=>{
        // Thor creates aution first
        let tx
        // Thor approve bam token
        tx = await bamContract.approve(auctionContract.address,  100, { from: Thor });
        let blockCount = parseInt(await helperContract.get_block_count({from: Thor}))
        logger.debug("thor balance approval tx gas used:", tx.receipt.gasUsed);

        timeMarker = parseInt(Date.now() / 1000)
        // Thor create a match
        tx = await auctionContract.auction("thorMatch", timeMarker + 10, blockCount + 100, 10, 5, 10, bamContract.address, {from : Thor});
        logger.debug("Transaction gas used:", tx.receipt.gasUsed);
        logger.debug(tx.logs[0].args);
    })

    it("should not let deposit to invalid match", async()=>{
        let tx
        try {
            tx = await auctionContract.deposit("voidId", 100, {from: Steve});
        } 
        catch(err) {
            logger.error(err.toString())
            assert.strictEqual(err.reason, "invalid match");
        }
    })

    it("should not let desposit when amount is 0", async()=>{
        // call to deposit
        let tx
        try {
            tx = await auctionContract.deposit("thorMatch", 0, {from: Steve});
            // logger.debug(tx[0].toString(), tx[1].toString());
        }
        catch(err) {
            logger.error(err.toString())
            assert.strictEqual(err.reason, "deposit amount must be greater than 0");
        }
    })

    it("should not let deposit when amount is not divisible by ticket price, amount = 12, ticketprice = 5", async()=>{
        // call to deposit
        let tx
        try {
            tx = await auctionContract.deposit("thorMatch", 12, {from: Steve}); 
        } 
        catch(err) {
            logger.error(err.toString())
            assert.strictEqual(err.reason, "deposit amount should be divisible by ticket price");
        }
    })

    it("should not let deposit when allowance usdc is not enough", async()=>{
        let tx
        // approve 15 units
        await usdcContract.approve(auctionContract.address,  15, { from: Steve });
        // deposit 20 units
        try {
            tx = await auctionContract.deposit("thorMatch", 20, {from: Steve});
        }
        catch(err) {
            logger.error(err.toString())
            assert.strictEqual(err.reason, "ERC20: transfer amount exceeds allowance")
        }
    })

    // TODO: should test not enough balance
    it("should create new player data on first deposit, deposit 3 tickets, 0 winning count", async()=>{
        let tx;

        let previousContractBalance = (await usdcContract.balanceOf(auctionContract.address)).toNumber()
        tx = await auctionContract.deposit("thorMatch", 15, {from: Steve});    
        let currentContractBalance = (await usdcContract.balanceOf(auctionContract.address)).toNumber()

        logger.debug("Transaction gas used for deposit:", tx.receipt.gasUsed);

        utils.eventEquals(tx, "DepositEvent", {
            matchId: "thorMatch", 
            player: Steve, 
            depositAmount: 15, 
            ticketCount: 3
        })

        tx = await auctionContract.get_player("thorMatch", Steve, {from: Steve});
        assert.strictEqual(tx['0'].toString(), '3'); // 3 tickets
        assert.strictEqual(tx['1'].toString(), '0'); // 0 winning
        
        assert.strictEqual(currentContractBalance - previousContractBalance, 15)
    })

    it("should increase ticket count to 5 on second time deposit", async()=>{
        let tx;
        await usdcContract.increaseAllowance(auctionContract.address,  10, { from: Steve });
        tx = await auctionContract.deposit("thorMatch", 10, {from: Steve}); 
        logger.debug("Transaction gas used for deposit:", tx.receipt.gasUsed);
        utils.eventEquals(tx, "DepositEvent", {
            matchId: "thorMatch", 
            player: Steve, 
            depositAmount: 10, 
            ticketCount: 2
        })

        tx = await auctionContract.get_player("thorMatch", Steve, {from: Steve});
        assert.strictEqual(tx['0'].toString(), '5'); // 3 tickets
        assert.strictEqual(tx['1'].toString(), '0'); // 0 winning 
    })

    it("should not let desposit to closed match", async()=>{
        // we sleep  
        let sleepTime = timeMarker + 12 - parseInt(Date.now()/1000)
        logger.info(`Wait ${sleepTime}s for thorMatch match to close`);
        if (sleepTime > 0) await sleep(sleepTime * 1000)

        // call to deposit
        let tx
        try {
            tx = await auctionContract.deposit("thorMatch", 100, {from: Steve});
        } 
        catch(err) {
            logger.error(err.toString())
            assert.strictEqual(err.reason, "match is not opened to deposit");
        }
    })
})