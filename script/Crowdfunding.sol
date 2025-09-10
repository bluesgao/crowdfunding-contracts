// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Crowdfunding} from "../src/Crowdfunding.sol";

/// @title Crowdfunding 部署脚本
/// @notice 用于部署 Crowdfunding 合约到区块链网络
contract CrowdfundingScript is Script {
    function setUp() public {}

    function run() public {
        // 获取部署者私钥
        string memory privateKeyString = vm.envString("PRIVATE_KEY");

        // 获取 USDT 代币地址（从环境变量或使用测试代币地址）
        // Arbitrum Sepolia 测试网络没有官方 USDT，需要使用测试代币或部署自己的测试代币
        address usdtToken = vm.envOr("USDT_TOKEN_ADDRESS", address(0)); // 需要设置测试代币地址

        // 开始广播交易
        vm.startBroadcast();

        // 部署 Crowdfunding 合约，将部署者设为初始所有者，并传入 USDT 代币地址
        Crowdfunding crowdfunding = new Crowdfunding(msg.sender, usdtToken);

        // 停止广播
        vm.stopBroadcast();

        // 输出部署信息
        console.log(
            "Crowdfunding contract deployed to:",
            address(crowdfunding)
        );
        console.log("Contract owner:", crowdfunding.owner());
        console.log("USDT Token address:", address(crowdfunding.USDT_TOKEN()));
    }
}
