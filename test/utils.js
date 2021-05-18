const assert = require("assert")
const logger = require("./logger")

module.exports = {
    eventEquals: function(tx, eventName, expectedData) {
        let depositEvent = tx.logs.filter(event => event.event === eventName)
        assert.strictEqual(depositEvent.length, 1)
            
        let args = depositEvent[0].args 
        let cnt = 0
        for(let key in expectedData) {
            let x
            x = args[key]
            assert.strictEqual(x.toString(), expectedData[key].toString())
            
            // use order
            x = args[cnt.toString()]
            assert.strictEqual(x.toString(), expectedData[key].toString())

            cnt ++;
        }       
    },

    generateBlock: async function(helperContract, targetBlock, caller) {
        let blockCount = parseInt(await helperContract.get_block_count({from: caller}))
        assert(targetBlock > blockCount, `blockCount: ${blockCount} >= target: ${targetBlock}`);

        for(let i = blockCount; i < targetBlock; ++i) {
            logger.info(`Creating block ${i+1}, target: >${targetBlock} ...`)
            // generate (expectedFutureBlock - blockCount) blocks (to when future block created)
            await helperContract.dummy_assign()
        }
    }
}