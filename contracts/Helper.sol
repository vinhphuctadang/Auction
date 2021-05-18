// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
* This helper is just for testing purpose
* created by vinhphuctadang
*/
contract Helper {
    uint dummy;
    
    uint savedHash;
    uint randomValue;

    // dummy assign to create new block for tests, do not use in production
    function dummy_assign() public { dummy = uint(blockhash(block.number - 1)); }

    // get current block count
    function get_block_count() public view returns(uint) { return block.number; }
}