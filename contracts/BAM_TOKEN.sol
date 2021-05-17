// SPDX-License-Identifier: MIT

/*
Reward token
* created by: vinhphuctadang
Use this token for testing the smart contract
In applications, please use valid ERC20 deployed token contract address
*/

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BAM_TOKEN is ERC20 {
    constructor() ERC20("Bamtasia", "BAM") {
        _mint(msg.sender, 1000000000);
    }
}