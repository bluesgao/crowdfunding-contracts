// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CrowdfundingV2} from "../src/CrowdfundingV2.sol";
import {TestUSDT} from "../src/TestUSDT.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title 部署可升级众筹合约的脚本
/// @notice 使用代理模式部署可升级的众筹合约
contract DeployUpgradeable is Script {
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

        // 2. 部署可升级众筹合约的实现
        console.log("Deploying CrowdfundingV2 implementation...");
        CrowdfundingV2 implementation = new CrowdfundingV2();
        console.log("Implementation deployed to:", address(implementation));

        // 3. 准备初始化数据
        uint256 platformFeeRate = 250; // 2.5% 平台费用
        address feeRecipient = deployerAddress; // 费用接收地址设为部署者

        bytes memory initData = abi.encodeWithSelector(
            CrowdfundingV2.initialize.selector,
            deployerAddress, // initialOwner
            address(testUsdt), // _usdtToken
            platformFeeRate, // _platformFeeRate
            feeRecipient // _feeRecipient
        );

        // 4. 部署代理合约
        console.log("Deploying proxy...");
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        console.log("Proxy deployed to:", address(proxy));

        // 5. 获取代理合约实例
        CrowdfundingV2 crowdfunding = CrowdfundingV2(address(proxy));

        // 停止广播
        vm.stopBroadcast();

        // 输出部署信息
        console.log("=== Upgradeable Deployment Complete ===");
        console.log("Deployer address:", deployerAddress);
        console.log("Test USDT token address:", address(testUsdt));
        console.log("Implementation address:", address(implementation));
        console.log("Proxy address:", address(proxy));
        console.log(
            "Crowdfunding contract address (proxy):",
            address(crowdfunding)
        );
        console.log("Contract owner:", crowdfunding.owner());
        console.log("USDT token address:", address(crowdfunding.USDT_TOKEN()));

        // 获取平台费用信息
        (uint256 feeRate, address recipient) = crowdfunding
            .getPlatformFeeInfo();
        console.log("Platform fee rate:", feeRate, "basis points");
        console.log("Fee recipient:", recipient);

        // 输出一些有用的信息
        console.log("\n=== Usage Instructions ===");
        console.log("1. Add token to MetaMask:", address(testUsdt));
        console.log(
            "2. Contract automatically minted 1,000,000 test USDT to deployer"
        );
        console.log("3. View contracts on block explorer:");
        console.log(
            "   - Crowdfunding contract (proxy):",
            address(crowdfunding)
        );
        console.log("   - Implementation:", address(implementation));
        console.log("   - Test USDT:", address(testUsdt));
        console.log("\n=== Upgrade Instructions ===");
        console.log("To upgrade the contract:");
        console.log("1. Deploy new implementation");
        console.log("2. Call proxy.upgradeTo(newImplementation) as owner");
    }
}
