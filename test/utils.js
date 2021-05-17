const assert = require("assert")

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
    }
}