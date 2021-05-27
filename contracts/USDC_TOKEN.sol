// SPDX-License-Identifier: MIT

/*
Deposit token
* created by: vinhphuctadang
Use this token for testing the smart contract
Use this token as a stable currency to deposit for tickets in Auction contract
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC_TOKEN is ERC20 {
    constructor() ERC20("UsdCoin", "USDC") {
        _mint(msg.sender, 1000000000000);
    }
}