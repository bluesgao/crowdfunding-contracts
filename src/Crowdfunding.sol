// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IProject} from "./interfaces/IProject.sol";
import {ISettlement} from "./interfaces/ISettlement.sol";
import {IAutomation} from "./interfaces/IAutomation.sol";
import {IRefund} from "./interfaces/IRefund.sol";
import {Errors} from "./libs/Errors.sol";

/// @title 众筹合约 Crowdfunding
/// @notice 组合 Project 和 Settlement 模块的核心众筹功能
contract Crowdfunding is Ownable, ReentrancyGuard {
    // ==================== 状态变量 ====================

    // 模块引用
    IProject public projectModule;
    ISettlement public settlementModule;
    IAutomation public automationModule;
    IRefund public refundModule;

    // 项目状态缓存 - 避免重复调用getProject
    mapping(uint256 => bool) public projectExists;
    mapping(uint256 => IProject.ProjectStatus) public projectStatusCache;

    // ==================== 修饰符 ====================

    modifier onlyValidProject(uint256 projectId) {
        if (projectId == 0 || !projectExists[projectId]) {
            revert Errors.ProjectDoesNotExist();
        }
        _;
    }

    modifier canContribute(uint256 projectId) {
        if (!projectExists[projectId]) {
            revert Errors.ProjectDoesNotExist();
        }
        if (projectStatusCache[projectId] != IProject.ProjectStatus.Active) {
            revert Errors.ProjectNotActive();
        }
        // 对于时间检查，仍需要获取项目详情
        IProject.Project memory project = projectModule.getProject(projectId);
        if (
            block.timestamp < project.startTime ||
            block.timestamp > project.endTime
        ) {
            revert Errors.ProjectNotAvailableForContribution();
        }
        _;
    }

    // ==================== 构造函数 ====================

    constructor(
        address initialOwner,
        address _projectModule,
        address _settlementModule,
        address _automationModule,
        address _refundModule
    ) Ownable(initialOwner) {
        projectModule = IProject(_projectModule);
        settlementModule = ISettlement(_settlementModule);
        automationModule = IAutomation(_automationModule);
        refundModule = IRefund(_refundModule);
    }

    // ==================== 项目管理 ====================

    function createProject(
        address owner,
        uint256 targetAmount,
        uint256 minAmount,
        uint256 maxAmount,
        uint64 startTime,
        uint64 endTime
    ) external onlyOwner returns (uint256 projectId) {
        projectId = projectModule.createProject(
            owner,
            targetAmount,
            minAmount,
            maxAmount,
            startTime,
            endTime
        );

        // 更新缓存
        projectExists[projectId] = true;
        projectStatusCache[projectId] = IProject.ProjectStatus.Pending;

        // 添加到自动化检查列表
        automationModule.addProjectToCheckList(projectId);
    }

    function freezeProject(
        uint256 projectId
    ) external onlyOwner onlyValidProject(projectId) {
        projectModule.freezeProject(projectId);
    }

    function settleProject(
        uint256 projectId
    ) external onlyOwner onlyValidProject(projectId) {
        IProject.Project memory project = projectModule.getProject(projectId);
        settlementModule.settleProject(
            projectId,
            project.contributeAmount,
            project.owner
        );
    }

    function getProject(
        uint256 projectId
    )
        external
        view
        onlyValidProject(projectId)
        returns (IProject.Project memory)
    {
        return projectModule.getProject(projectId);
    }

    function updateProjectStatus(
        uint256 projectId,
        IProject.ProjectStatus newStatus
    ) external onlyOwner onlyValidProject(projectId) {
        projectModule.updateProjectStatus(projectId, newStatus);

        // 更新缓存
        projectStatusCache[projectId] = newStatus;
    }

    // ==================== 赞助功能 ====================

    function contributeProject(
        uint256 projectId
    ) external payable nonReentrant canContribute(projectId) {
        if (msg.value == 0) {
            revert Errors.AmountMustBePositive();
        }

        IProject.Project memory project = projectModule.getProject(projectId);

        if (msg.value < project.minAmount) {
            revert Errors.AmountLessThanMin();
        }
        if (msg.value > project.maxAmount) {
            revert Errors.AmountExceedsMax();
        }

        // 调用项目模块的赞助接口
        projectModule.contributeProject(projectId, msg.sender, msg.value);
    }

    function cancelContributeProject(
        uint256 projectId
    ) external nonReentrant onlyValidProject(projectId) {
        // 调用项目模块的取消赞助接口，获取退款金额
        uint256 refundAmount = projectModule.cancelContributeProject(
            projectId,
            msg.sender
        );

        // 主合约处理退款
        if (refundAmount > 0) {
            (bool success, ) = payable(msg.sender).call{value: refundAmount}(
                ""
            );
            if (!success) {
                revert Errors.TransferFailed();
            }
        }
    }

    // ==================== 项目失败退款功能 ====================
    function refundProject(
        uint256 projectId
    ) external onlyOwner onlyValidProject(projectId) {
        // 获取退款明细并更新状态
        IProject.RefundDetail[] memory refundDetails = projectModule
            .getProjectRefundDetails(projectId);

        // 提取地址和金额数组
        address[] memory contributors = new address[](refundDetails.length);
        uint256[] memory amounts = new uint256[](refundDetails.length);
        uint256 totalRefundAmount = 0;

        for (uint256 i = 0; i < refundDetails.length; i++) {
            contributors[i] = refundDetails[i].contributor;
            amounts[i] = refundDetails[i].amount;
            totalRefundAmount += refundDetails[i].amount;
        }

        // 使用独立退款合约设置退款
        refundModule.setBatchRefunds(projectId, contributors, amounts);

        // 将退款金额转移到退款合约
        if (totalRefundAmount > 0) {
            (bool success, ) = address(refundModule).call{
                value: totalRefundAmount
            }("");
            if (!success) {
                revert Errors.TransferFailed();
            }
        }
    }

    // ==================== 用户提取退款功能 ====================
    function claimRefund(
        uint256 projectId
    ) external nonReentrant onlyValidProject(projectId) {
        // 直接从退款合约提取退款
        refundModule.claimRefund(projectId);
    }

    // ==================== 查询功能 ====================

    function getProjectContributionRecord(
        uint256 projectId
    ) external view returns (IProject.ContributionRecord[] memory) {
        return projectModule.getProjectContributionRecord(projectId);
    }

    function getPendingRefund(
        uint256 projectId,
        address contributor
    ) external view returns (uint256 amount) {
        return refundModule.getPendingRefund(projectId, contributor);
    }

    // ==================== 自动化管理 ====================

    function checkAndUpdateProjectStatus(
        uint256 projectId
    ) external onlyOwner onlyValidProject(projectId) returns (bool updated) {
        bool result = automationModule.checkAndUpdateProjectStatus(projectId);

        // 更新缓存
        if (result) {
            IProject.Project memory project = projectModule.getProject(
                projectId
            );
            projectStatusCache[projectId] = project.status;
        }

        return result;
    }

    function batchCheckProjects(
        uint256[] calldata projectIds
    ) external onlyOwner returns (uint256 updatedCount) {
        return automationModule.batchCheckProjects(projectIds);
    }

    function getProjectsToCheck() external view returns (uint256[] memory) {
        return automationModule.getProjectsToCheck();
    }

    // ==================== 接收ETH ====================

    receive() external payable {
        // 允许接收ETH
    }
}
