// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract Helper {
    uint dummy;
    // dummy assign to create new block for tests, do not use in production
    function dummy_assign() public { dummy = uint(blockhash(block.number - 1)); }

    // get current block count for verification
    function get_block_count() public view returns(uint) { return block.number; }
}