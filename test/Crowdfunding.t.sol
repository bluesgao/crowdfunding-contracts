// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Crowdfunding} from "../src/Crowdfunding.sol";
import {Project} from "../src/modules/Project.sol";
import {Settlement} from "../src/modules/Settlement.sol";
import {Automation} from "../src/modules/Automation.sol";
import {Refund} from "../src/modules/Refund.sol";
import {IProject} from "../src/interfaces/IProject.sol";

/// @title 众筹合约测试
/// @notice 测试众筹合约的核心功能
contract CrowdfundingTest is Test {
    Crowdfunding public crowdfunding;
    Project public projectModule;
    Settlement public settlementModule;
    Automation public automationModule;
    Refund public refundModule;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    // ==================== 工具函数 ====================

    /// @notice 验证项目统计信息
    function _verifyProjectStats(uint256 projectId) internal view {
        console.log("=== Verifying project stats ===");
        IProject.Project memory project = projectModule.getProject(projectId);
        console.log("Project ID:", project.id);
        console.log("Project owner:", project.owner);
        console.log("Target amount:", project.targetAmount);
        console.log("Min amount:", project.minAmount);
        console.log("Max amount:", project.maxAmount);
        console.log("Start time:", project.startTime);
        console.log("End time:", project.endTime);
        console.log("contributeAmount:", project.contributeAmount);
        console.log("contributeCount:", project.contributeCount);
        console.log("Project status:", uint8(project.status));
        console.log("Project settled:", project.settled);
        console.log("=== Project stats verified ===");
    }

    /// @notice 验证赞助记录
    function _verifyContributionRecords(uint256 projectId) internal view {
        console.log("=== Verifying contribution records ===");
        IProject.ContributionRecord[] memory records = projectModule
            .getProjectContributionRecord(projectId);
        for (uint256 i = 0; i < records.length; i++) {
            console.log(
                "Contribution record status:",
                uint8(records[i].status)
            );
            console.log("Contribution record amount:", records[i].amount);
            console.log(
                "Contribution record contributor:",
                records[i].contributor
            );
            console.log("Contribution record timestamp:", records[i].timestamp);
        }
        console.log("=== Contribution records verified ===");
    }

    /// @notice 验证用户余额
    function _verifyUserBalance(
        address user,
        string memory description
    ) internal view {
        console.log("=== Verifying user balance ===");
        console.log(description, user.balance);
        console.log("=== User balance verified ===");
    }

    /// @notice 验证合约余额
    function _verifyContractBalance(string memory description) internal view {
        console.log("=== Verifying contract balance ===");
        console.log(description, address(crowdfunding).balance);
        console.log("=== Contract balance verified ===");
    }

    function setUp() public {
        console.log("=== Setting up test environment ===");

        // 设置区块时间
        vm.warp(1660000000);

        // 部署模块
        vm.prank(owner);
        projectModule = new Project(owner);
        console.log("Project module deployed at:", address(projectModule));

        vm.prank(owner);
        settlementModule = new Settlement(owner);
        console.log(
            "Settlement module deployed at:",
            address(settlementModule)
        );

        vm.prank(owner);
        automationModule = new Automation(owner);
        console.log(
            "Automation module deployed at:",
            address(automationModule)
        );

        vm.prank(owner);
        refundModule = new Refund(owner);
        console.log("Refund module deployed at:", address(refundModule));

        // 部署主合约
        vm.prank(owner);
        crowdfunding = new Crowdfunding(
            owner,
            address(projectModule),
            address(settlementModule),
            address(automationModule),
            address(refundModule)
        );
        console.log(
            "Crowdfunding main contract deployed at:",
            address(crowdfunding)
        );

        // 设置模块引用
        vm.prank(owner);
        projectModule.setSettlementModule(address(settlementModule));
        console.log("Settlement module reference set in project module");

        vm.prank(owner);
        automationModule.setProjectModule(address(projectModule));
        console.log("Project module reference set in automation module");

        vm.prank(owner);
        refundModule.setAuthorizedContract(address(crowdfunding), true);
        console.log("Crowdfunding contract authorized in refund module");

        // 转移模块所有权到主合约
        vm.prank(owner);
        projectModule.transferOwnership(address(crowdfunding));

        vm.prank(owner);
        settlementModule.transferOwnership(address(crowdfunding));

        vm.prank(owner);
        automationModule.transferOwnership(address(crowdfunding));

        vm.prank(owner);
        refundModule.transferOwnership(address(crowdfunding));
        console.log("Module ownership transferred to main contract");

        // 给用户一些ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        console.log("User1 ETH balance:", user1.balance);
        console.log("User2 ETH balance:", user2.balance);

        console.log("=== Test environment setup complete ===");
    }

    function createTestProject() internal returns (uint256) {
        vm.prank(owner);
        return
            crowdfunding.createProject(
                user1,
                5 ether,
                0.1 ether,
                1 ether,
                uint64(block.timestamp),
                uint64(block.timestamp + 30 days)
            );
    }

    function testCreateProject() public {
        console.log("=== Starting create project test ===");

        uint256 projectId = createTestProject();
        console.log("Created project ID:", projectId);

        assertEq(projectId, 1);

        IProject.Project memory project = crowdfunding.getProject(projectId);
        console.log("Project owner:", project.owner);
        console.log("Target amount:", project.targetAmount);
        console.log("Min contribution:", project.minAmount);
        console.log("Max contribution:", project.maxAmount);
        console.log("Project status:", uint8(project.status));

        assertEq(project.owner, user1);
        assertEq(project.targetAmount, 5 ether);
        assertEq(project.minAmount, 0.1 ether);
        assertEq(project.maxAmount, 1 ether);
        assertEq(uint8(project.status), uint8(IProject.ProjectStatus.Pending));

        console.log("=== Create project test completed ===");
    }

    function testContributeProject() public {
        console.log("=== Starting contribution test ===");

        // 创建项目
        uint256 projectId = createTestProject();
        console.log("Project ID:", projectId);

        // 激活项目
        vm.prank(owner);
        crowdfunding.updateProjectStatus(
            projectId,
            IProject.ProjectStatus.Active
        );
        console.log("Project activated");

        // 赞助
        // user1
        vm.prank(user1);
        crowdfunding.contributeProject{value: 0.51 ether}(projectId);
        console.log("User1 contributed 0.51 ETH");
        _verifyUserBalance(user1, "User1 current balance:");

        // user2
        vm.prank(user2);
        crowdfunding.contributeProject{value: 0.5 ether}(projectId);
        console.log("User2 contributed 0.5 ETH");
        _verifyUserBalance(user2, "User2 current balance:");

        // 验证合约余额
        _verifyContractBalance("Contract balance after contributions:");

        // 验证项目统计信息
        _verifyProjectStats(projectId);

        // 验证赞助记录
        _verifyContributionRecords(projectId);

        console.log("=== Contribution test completed ===");
    }

    function testCancelContributeProject() public {
        console.log("=== Starting cancel contribute project test ===");
        // 创建并激活项目
        uint256 projectId = createTestProject();
        console.log("Project ID:", projectId);

        vm.prank(owner);
        crowdfunding.updateProjectStatus(
            projectId,
            IProject.ProjectStatus.Active
        );
        console.log("Project activated");

        // 赞助
        // user1
        vm.prank(user1);
        crowdfunding.contributeProject{value: 0.51 ether}(projectId);
        console.log("User1 contributed 0.51 ether to project", projectId);
        _verifyUserBalance(user1, "User1 current balance:");

        // user2
        vm.prank(user2);
        crowdfunding.contributeProject{value: 0.51 ether}(projectId);
        console.log("User1 contributed 0.51 ether to project", projectId);
        _verifyUserBalance(user2, "User2 current balance:");

        // 验证项目统计信息
        _verifyProjectStats(projectId);

        // 验证赞助记录
        _verifyContributionRecords(projectId);

        // 验证合约余额
        _verifyContractBalance("Contract balance after contributions:");

        // 取消赞助
        vm.prank(user2);
        crowdfunding.cancelContributeProject(projectId);
        console.log("User2 cancelled contribute project");
        _verifyUserBalance(user2, "User2 current balance:");

        // 验证赞助记录
        _verifyContributionRecords(projectId);

        // 验证项目统计信息
        _verifyProjectStats(projectId);

        //验证用户余额
        _verifyUserBalance(user2, "User2 balance:");

        // 验证合约余额
        _verifyContractBalance("Contract balance after cancellation:");

        console.log("=== Cancel contribute project test completed ===");
    }

    function testRefundProject() public {
        console.log("=== Starting refund project test ===");
        // 创建并激活项目
        uint256 projectId = createTestProject();
        console.log("Project ID:", projectId);

        // 激活项目
        vm.prank(owner);
        crowdfunding.updateProjectStatus(
            projectId,
            IProject.ProjectStatus.Active
        );
        console.log("Project activated");

        // 赞助
        // user1
        vm.prank(user1);
        crowdfunding.contributeProject{value: 0.51 ether}(projectId);
        console.log("User1 contributed 0.51 ether to project", projectId);
        _verifyUserBalance(user1, "User1 current balance:");

        // user2
        vm.prank(user2);
        crowdfunding.contributeProject{value: 0.5 ether}(projectId);
        console.log("User2 contributed 0.5 ether to project", projectId);
        _verifyUserBalance(user2, "User2 current balance:");

        // 验证合约余额
        _verifyContractBalance("Contract balance after contributions:");

        // 验证项目统计信息
        _verifyProjectStats(projectId);

        // 验证赞助记录
        _verifyContributionRecords(projectId);

        // 项目失败
        vm.prank(owner);
        crowdfunding.updateProjectStatus(
            projectId,
            IProject.ProjectStatus.Failed
        );

        // 验证项目统计信息
        _verifyProjectStats(projectId);

        // 验证赞助记录
        _verifyContributionRecords(projectId);

        // 退款
        console.log("Refunding project", projectId);
        vm.prank(owner); // 只有owner可以退款
        crowdfunding.refundProject(projectId);

        // 验证项目统计信息
        _verifyProjectStats(projectId);

        // 验证赞助记录
        _verifyContributionRecords(projectId);

        // 验证合约余额
        _verifyContractBalance("Contract balance after refund:");

        // 测试用户提取退款
        console.log("Testing user refund claims...");

        // User1 提取退款
        uint256 user1Refund = crowdfunding.getPendingRefund(projectId, user1);
        console.log("User1 pending refund:", user1Refund);

        vm.prank(user1);
        refundModule.claimRefund(projectId);

        // User2 提取退款
        uint256 user2Refund = crowdfunding.getPendingRefund(projectId, user2);
        console.log("User2 pending refund:", user2Refund);

        vm.prank(user2);
        refundModule.claimRefund(projectId);

        // 验证最终状态
        _verifyUserBalance(user1, "User1 balance after claiming refund");
        _verifyUserBalance(user2, "User2 balance after claiming refund");
        _verifyContractBalance("Contract balance after all refunds claimed");

        console.log("=== Refund project test completed ===");
    }
}
