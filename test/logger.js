const env = process.env.ENV || "test"

module.exports = {
    info: function(...args){
      if (env == 'production') return
  
      let stack = (new Error().stack).split('\n')
      let header = `\x1b[33m ${'[INFO ' + (new Date()).toISOString() + '] ' + stack[2].substring(stack[2].indexOf('('))}\x1b[0m`
      console.log(header, ...args)
    },
  
    warning: function(...args){
      if (env == 'production') return
  
      let stack = (new Error().stack).split('\n')
      let header = `\x1b[37m${'[WARN ' + (new Date()).toISOString() + '] ' + stack[2].substring(stack[2].indexOf('('))}\x1b[0m`
      console.log(header, ...args)
    },
  
    debug: function(...args){
      if (env == 'production') return
  
      let stack = (new Error().stack).split('\n')   
      let header = `\x1b[36m${'[DEBUG ' + (new Date()).toISOString() + '] ' + stack[2].substring(stack[2].indexOf('('))}\x1b[0m`
      console.log(header, ...args)
    },
  
    error: function(...args){
      if (env == 'production') return
  
      let stack = (new Error().stack).split('\n')
      let header = `\x1b[31m${'[ERROR ' + (new Date()).toISOString() + '] ' + stack[2].substring(stack[2].indexOf('('))}\x1b[0m`
      console.log(header, ...args)
    },
  }