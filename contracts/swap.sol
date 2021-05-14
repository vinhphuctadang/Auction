// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Swapper {
    
    address constant USDC_CONTRACT = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    address constant BAM_CONTRACT = 0xD7ACd2a9FD159E69Bb102A1ca21C9a3e3A5F771B;
    uint constant EXCHANGE_RATE = 10; // 1 BAM  = 10 usdc
    
    mapping(address => uint) bamBalance;
    
    uint availableBam;
    address payable admin;
    

    modifier adminOnly() {
        require(admin == msg.sender, "Admin only function");
        _;
    }

    constructor(){
        admin = payable(msg.sender);
        availableBam = 0;
    }
    
    function stakeBam(uint amount) public adminOnly {
        uint currentBam = availableBam;
        ERC20 bamContract = ERC20(BAM_CONTRACT);
        bool success = bamContract.transferFrom(admin, address(this), amount);
        require(success, "bam deposit is not success");
        require(bamContract.balanceOf(address(this)) == currentBam + amount, "Balance not equals to currentBam + amount");

        availableBam += amount;
    }
    
    function getBamBalance() public view returns(uint) {
        return bamBalance[msg.sender];
    }
    
    function getAvailableBam() public view returns(uint) {
        return availableBam;
    }

    function swapUsdcToBam(uint amount) public {
        ERC20 usdcContract = ERC20(USDC_CONTRACT);
        require(usdcContract.balanceOf(msg.sender) >= amount, "Usdc balance insufficient");
        uint bam = amount / EXCHANGE_RATE;
        require(bam > 0, "Invalid bam count");
        require(bam <= availableBam);
        
        availableBam -= bam;
        bool success = usdcContract.transferFrom(payable(msg.sender), admin, amount);
        require(success, "transfer is not success");
        bamBalance[msg.sender] += bam;
    }
}