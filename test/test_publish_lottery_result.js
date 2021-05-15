const assert = require("assert")
const logger = require("./logger")
const Auction = artifacts.require("Auction")
const USDC_TOKEN = artifacts.require("USDC_TOKEN")
const BAM_TOKEN = artifacts.require("BAM_TOKEN")
const Helper = artifacts.require("Helper")

contract("Test publish lottery result", accounts => {
    let Tony = accounts[0], 
        Thor = accounts[1], 
        Steve = accounts[2],
        Banner = accounts[3],
        Natasha = accounts[4];

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
        await usdcContract.transfer(Banner, "1200", {from: Tony});
        await usdcContract.transfer(Natasha, "1200", {from: Tony});
    })

    it("shoud not publish result when match is not finished", async()=> {

    });

    it("shoud not publish result when future block is not generated", async()=> {

    });
    
    it("shoud publish result and increase win count", async() => {

    })

    it("shoud publish result randomly", async()=> {

        // first auction 

        // second auction with the same number but differnt future block
    });
})