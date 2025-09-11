// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IAutomation} from "../interfaces/IAutomation.sol";
import {IProject} from "../interfaces/IProject.sol";
import {Errors} from "../libs/Errors.sol";
import {Events} from "../libs/Events.sol";

/// @title 自动化模块
/// @notice 负责项目状态自动检查和更新
contract Automation is IAutomation, Ownable, ReentrancyGuard {
    // ==================== 状态变量 ====================

    // 项目模块引用
    IProject public projectModule;

    // 批量检查计数器
    uint256 public batchCheckCounter;

    // 需要检查的项目列表
    uint256[] public projectsToCheck;
    mapping(uint256 => bool) public isInCheckList;

    // ==================== 构造函数 ====================

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ==================== 模块设置 ====================

    function setProjectModule(address _projectModule) external onlyOwner {
        if (_projectModule == address(0)) {
            revert Errors.InvalidAddress();
        }
        projectModule = IProject(_projectModule);
    }

    // ==================== 自动化检查接口 ====================

    function checkAndUpdateProjectStatus(
        uint256 projectId
    ) external override onlyOwner nonReentrant returns (bool updated) {
        if (projectId == 0) {
            revert Errors.ProjectDoesNotExist();
        }

        IProject.Project memory project = projectModule.getProject(projectId);
        IProject.ProjectStatus currentStatus = project.status;
        IProject.ProjectStatus newStatus = currentStatus;

        // 检查项目状态转换
        if (currentStatus == IProject.ProjectStatus.Pending) {
            if (shouldProjectStart(projectId)) {
                newStatus = IProject.ProjectStatus.Active;
            }
        } else if (currentStatus == IProject.ProjectStatus.Active) {
            if (isProjectExpired(projectId)) {
                // 检查是否达到目标金额
                if (project.contributeAmount >= project.targetAmount) {
                    newStatus = IProject.ProjectStatus.Success;
                } else {
                    newStatus = IProject.ProjectStatus.Failed;
                }
            }
        }

        // 如果状态发生变化，更新项目状态
        if (newStatus != currentStatus) {
            projectModule.updateProjectStatus(projectId, newStatus);

            emit ProjectStatusAutoUpdated(
                projectId,
                currentStatus,
                newStatus,
                _getStatusChangeReason(currentStatus, newStatus)
            );

            updated = true;
        }

        return updated;
    }

    function batchCheckProjects(
        uint256[] calldata projectIds
    ) external override onlyOwner nonReentrant returns (uint256 updatedCount) {
        uint256 batchId = ++batchCheckCounter;
        uint256 totalProjects = projectIds.length;
        updatedCount = 0;

        for (uint256 i = 0; i < projectIds.length; i++) {
            try this.checkAndUpdateProjectStatus(projectIds[i]) returns (
                bool updated
            ) {
                if (updated) {
                    updatedCount++;
                }
            } catch {
                // 忽略单个项目检查失败，继续处理其他项目
                continue;
            }
        }

        emit BatchProjectsChecked(batchId, totalProjects, updatedCount);
        return updatedCount;
    }

    function getProjectsToCheck()
        external
        view
        override
        returns (uint256[] memory)
    {
        return projectsToCheck;
    }

    function isProjectExpired(
        uint256 projectId
    ) public view override returns (bool isExpired) {
        IProject.Project memory project = projectModule.getProject(projectId);
        return block.timestamp > project.endTime;
    }

    function shouldProjectStart(
        uint256 projectId
    ) public view override returns (bool shouldStart) {
        IProject.Project memory project = projectModule.getProject(projectId);
        return block.timestamp >= project.startTime;
    }

    // ==================== 项目管理接口 ====================

    function addProjectToCheckList(uint256 projectId) external onlyOwner {
        if (!isInCheckList[projectId]) {
            projectsToCheck.push(projectId);
            isInCheckList[projectId] = true;
        }
    }

    function removeProjectFromCheckList(uint256 projectId) external onlyOwner {
        if (isInCheckList[projectId]) {
            // 从数组中移除项目
            for (uint256 i = 0; i < projectsToCheck.length; i++) {
                if (projectsToCheck[i] == projectId) {
                    projectsToCheck[i] = projectsToCheck[
                        projectsToCheck.length - 1
                    ];
                    projectsToCheck.pop();
                    break;
                }
            }
            isInCheckList[projectId] = false;
        }
    }

    // ==================== 内部函数 ====================

    function _getStatusChangeReason(
        IProject.ProjectStatus oldStatus,
        IProject.ProjectStatus newStatus
    ) internal pure returns (string memory reason) {
        if (
            oldStatus == IProject.ProjectStatus.Pending &&
            newStatus == IProject.ProjectStatus.Active
        ) {
            return "Project start time reached";
        } else if (
            oldStatus == IProject.ProjectStatus.Active &&
            newStatus == IProject.ProjectStatus.Success
        ) {
            return "Project target reached and time expired";
        } else if (
            oldStatus == IProject.ProjectStatus.Active &&
            newStatus == IProject.ProjectStatus.Failed
        ) {
            return "Project time expired without reaching target";
        } else {
            return "Status updated by automation";
        }
    }
}
