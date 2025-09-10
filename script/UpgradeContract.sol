// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CrowdfundingV2} from "../src/CrowdfundingV2.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title 升级众筹合约的脚本
/// @notice 用于升级已部署的众筹合约
contract UpgradeContract is Script {
    function setUp() public {}

    function run() public {
        // 获取部署者私钥
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(privateKeyString);
        address deployerAddress = vm.addr(deployerPrivateKey);

        // 从环境变量获取代理合约地址
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署新的实现合约
        console.log("Deploying new CrowdfundingV2 implementation...");
        CrowdfundingV2 newImplementation = new CrowdfundingV2();
        console.log(
            "New implementation deployed to:",
            address(newImplementation)
        );

        // 2. 获取当前实现合约实例
        CrowdfundingV2 currentImplementation = CrowdfundingV2(proxyAddress);

        // 3. 通过当前实现合约升级到新实现
        console.log("Upgrading proxy to new implementation...");
        currentImplementation.upgradeToAndCall(address(newImplementation), "");
        console.log("Proxy upgraded successfully!");

        // 4. 验证升级
        CrowdfundingV2 crowdfunding = CrowdfundingV2(proxyAddress);
        console.log("Contract owner:", crowdfunding.owner());
        console.log("USDT token address:", address(crowdfunding.USDT_TOKEN()));

        // 获取平台费用信息
        (uint256 feeRate, address recipient) = crowdfunding
            .getPlatformFeeInfo();
        console.log("Platform fee rate:", feeRate, "basis points");
        console.log("Fee recipient:", recipient);

        // 停止广播
        vm.stopBroadcast();

        console.log("=== Upgrade Complete ===");
        console.log("Proxy address:", proxyAddress);
        console.log("New implementation address:", address(newImplementation));
        console.log("Contract is now upgraded and ready to use!");
    }
}
