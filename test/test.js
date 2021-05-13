const assert = require("assert")

const Auction = artifacts.require("Auction");

contract("Auction", accounts => {

    let instance 
    it("should deploy contract", async()=> {
        instance = await Auction.new({from: accounts[0]})
    })

    it("should create auction", async()=>{
        let tx = await instance.auction("m1", parseInt(Date.now()/1000) + 24*60, 100, 2, 5, 10, {value: 10 * 2});
        // console.log("logs:", tx.logs);
        let log = tx.logs[0];
        assert(log.event === "CreateAuctionEvent");
        assert(log.args["matchId"] === "m1");
        assert(log.args["maxWinning"] == 2);
        assert(log.args["ticketPrice"] == 5);
        assert(log.args["rewardPerTicket"] == 10);
    })

    it("should deposit 500", async()=> {
        let tx = await instance.deposit("m1", {value: 20, from: accounts[1]});
        console.log("logs:", tx.logs);

        
    })
})