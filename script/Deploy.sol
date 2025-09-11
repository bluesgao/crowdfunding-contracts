// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Crowdfunding} from "../src/Crowdfunding.sol";
import {Project} from "../src/modules/Project.sol";
import {Settlement} from "../src/modules/Settlement.sol";
import {Automation} from "../src/modules/Automation.sol";
import {Refund} from "../src/modules/Refund.sol";

/// @title 众筹合约部署脚本
/// @notice 部署主合约和模块
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with the account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署项目模块
        console.log("Deploying Project module...");
        Project projectModule = new Project(deployer);
        console.log("Project deployed at:", address(projectModule));

        // 2. 部署结算模块
        console.log("Deploying Settlement module...");
        Settlement settlementModule = new Settlement(deployer);
        console.log("Settlement deployed at:", address(settlementModule));

        // 3. 部署自动化模块
        console.log("Deploying Automation module...");
        Automation automationModule = new Automation(deployer);
        console.log("Automation deployed at:", address(automationModule));

        // 4. 部署退款模块
        console.log("Deploying Refund module...");
        Refund refundModule = new Refund(deployer);
        console.log("Refund deployed at:", address(refundModule));

        // 5. 部署主合约
        console.log("Deploying Crowdfunding...");
        Crowdfunding crowdfunding = new Crowdfunding(
            deployer,
            address(projectModule),
            address(settlementModule),
            address(automationModule),
            address(refundModule)
        );
        console.log("Crowdfunding deployed at:", address(crowdfunding));

        // 6. 设置模块引用
        console.log("Setting module references...");
        projectModule.setSettlementModule(address(settlementModule));
        automationModule.setProjectModule(address(projectModule));
        refundModule.setAuthorizedContract(address(crowdfunding), true);

        // 7. 转移模块所有权到主合约
        console.log("Transferring module ownership to main contract...");
        projectModule.transferOwnership(address(crowdfunding));
        settlementModule.transferOwnership(address(crowdfunding));
        automationModule.transferOwnership(address(crowdfunding));
        refundModule.transferOwnership(address(crowdfunding));

        vm.stopBroadcast();

        // 输出部署信息
        console.log("\n=== Deployment Summary ===");
        console.log("Main Contract:", address(crowdfunding));
        console.log("Project Module:", address(projectModule));
        console.log("Settlement Module:", address(settlementModule));
        console.log("Automation Module:", address(automationModule));
        console.log("Refund Module:", address(refundModule));
        console.log("Deployer:", deployer);
    }
}
