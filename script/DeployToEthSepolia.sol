// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Crowdfunding} from "../src/Crowdfunding.sol";
import {TestUSDT} from "../src/TestUSDT.sol";

/// @title 部署到以太坊 Sepolia 测试网络的脚本
/// @notice 部署测试 USDT 代币和众筹合约
contract DeployToEthSepolia is Script {
    function setUp() public {}

    function run() public {
        // 获取部署者私钥
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(privateKeyString);
        address deployerAddress = vm.addr(deployerPrivateKey);

        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 1. 首先部署测试 USDT 代币
        console.log("Deploying Test USDT token...");
        TestUSDT testUsdt = new TestUSDT(deployerAddress);
        console.log("Test USDT token deployed to:", address(testUsdt));

        // 2. 部署众筹合约，使用刚部署的测试 USDT 地址
        console.log("Deploying Crowdfunding contract...");
        Crowdfunding crowdfunding = new Crowdfunding(
            deployerAddress,
            address(testUsdt)
        );

        // 停止广播
        vm.stopBroadcast();

        // 输出部署信息
        console.log("=== Deployment Complete ===");
        console.log("Deployer address:", deployerAddress);
        console.log("Test USDT token address:", address(testUsdt));
        console.log("Crowdfunding contract address:", address(crowdfunding));
        console.log("Contract owner:", crowdfunding.owner());
        console.log("USDT token address:", address(crowdfunding.USDT_TOKEN()));

        // 输出一些有用的信息
        console.log("\n=== Usage Instructions ===");
        console.log("1. Add token to MetaMask:", address(testUsdt));
        console.log(
            "2. Contract automatically minted 1,000,000 test USDT to deployer"
        );
        console.log("3. View contracts on block explorer:");
        console.log("   - Crowdfunding contract:", address(crowdfunding));
        console.log("   - Test USDT:", address(testUsdt));
    }
}
