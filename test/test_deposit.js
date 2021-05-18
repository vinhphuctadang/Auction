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

    let expiryBlock, futureBlock, capPerAddress = 6;
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

    it("should create a match named thorMatch and limit capacity per address = 6", async()=>{
        // Thor creates aution first
        let tx
        // Thor approve bam token
        tx = await bamContract.approve(auctionContract.address, 100, { from: Thor });
        let blockCount = parseInt(await helperContract.get_block_count({from: Thor}))
        logger.debug("thor balance approval tx gas used:", tx.receipt.gasUsed);

        expiryBlock = blockCount + 30
        futureBlock = blockCount + 60
        
        // timeMarker = parseInt(Date.now() / 1000)
        // Thor create a match
        tx = await auctionContract.auction("thorMatch", expiryBlock, futureBlock, 10, 5, 10, bamContract.address, capPerAddress, {from : Thor});
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
            return assert.strictEqual(err.reason, "invalid match");
        }
        throw `It should throw "invalid match" but actually it does not`
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
            return assert.strictEqual(err.reason, "deposit amount must be greater than 0");
        }
        throw `It should throw "deposit amount must be greater than 0" but actually it does not`
    })

    it("should not let deposit when amount is not divisible by ticket price, amount = 12, ticketprice = 5", async()=>{
        // call to deposit but amount is not divisible
        let tx
        try {
            tx = await auctionContract.deposit("thorMatch", 12, {from: Steve}); 
        } 
        catch(err) {
            logger.error(err.toString())
            return assert.strictEqual(err.reason, "deposit amount should be divisible by ticket price");
        }
        throw `It should throw "deposit amount should be divisible by ticket price" but actually it does not`
    })

    it("should not let deposit when allowance usdc is not enough", async()=>{
        let tx
        // approve 15 units
        await usdcContract.approve(auctionContract.address, 15, { from: Steve });
        // deposit 20 units
        try {
            tx = await auctionContract.deposit("thorMatch", 20, {from: Steve});
        }
        catch(err) {
            logger.error(err.toString())
            return assert.strictEqual(err.reason, "ERC20: transfer amount exceeds allowance")
        }
        throw `It should throw error "ERC20: transfer amount exceeds allowance" but actually it does not`
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
        logger.debug("Transaction gas used for deposit 2nd time:", tx.receipt.gasUsed);
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

    it("should let Tony deposit and get player should return 2", async() => {
        let tx
        // get number of player
        tx = await auctionContract.get_player_count("thorMatch", {from: Steve});
        assert.strictEqual(tx.toNumber(), 1)

        // approve 15 units
        await usdcContract.approve(auctionContract.address, 20, { from: Tony });
        // deposit 20 units
        let previousContractBalance = (await usdcContract.balanceOf(auctionContract.address)).toNumber()
        tx = await auctionContract.deposit("thorMatch", 20, {from: Tony});
        logger.debug("Transaction gas used for deposit:", tx.receipt.gasUsed);
        let currentContractBalance = (await usdcContract.balanceOf(auctionContract.address)).toNumber()

        utils.eventEquals(tx, "DepositEvent", {
            matchId: "thorMatch", 
            player: Tony, 
            depositAmount: 20, 
            ticketCount: 4
        })
        assert.strictEqual(currentContractBalance - previousContractBalance, 20)

        tx = await auctionContract.get_player("thorMatch", Tony, {from: Steve});
        assert.strictEqual(tx['0'].toString(), '4'); // 4 tickets
        assert.strictEqual(tx['1'].toString(), '0'); // 0 winning

        // check number of player
        tx = await auctionContract.get_player_count("thorMatch", {from: Steve});
        assert.strictEqual(tx.toNumber(), 2)
    })

    it("should not let Steve deposit for 2 more tickets", async()=>{
        let tx;
        await usdcContract.increaseAllowance(auctionContract.address, 10, { from: Steve });
        try {
            tx = await auctionContract.deposit("thorMatch", 10, {from: Steve}); 
        }
        catch(err) {
            logger.error(err.toString());
            assert.strictEqual(err.reason, "Number of ticket exceeds cap");
            // also check for player information to make sure that it stays unchange
            logger.info("Checking Steve data to make sure that it is unchanged")
            tx = await auctionContract.get_player("thorMatch", Steve, {from: Steve});
            assert.strictEqual(tx['0'].toString(), '5'); // 5 tickets
            assert.strictEqual(tx['1'].toString(), '0'); // 0 winning 
            return // all expected errors happened
        }
        throw `It should throw "Number of ticket exceeds cap" but actually it does not`
    })

    it("[try again] should let Steve deposit for 1 more tickets", async()=>{
        let tx;
        // we don't increase allowanace again
        // await usdcContract.increaseAllowance(auctionContract.address, 10, { from: Steve });
        tx = await auctionContract.deposit("thorMatch", 5, {from: Steve});
        logger.info("Checking Steve data to make sure that it is increased")
        tx = await auctionContract.get_player("thorMatch", Steve, {from: Steve});
        assert.strictEqual(tx['0'].toString(), '6'); // 6 tickets
        assert.strictEqual(tx['1'].toString(), '0'); // 0 winning 
    })
    
    it("should not let desposit to closed match", async()=>{
        // generate
        await utils.generateBlock(helperContract, expiryBlock + 1);

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