// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IProject} from "./IProject.sol";

/// @title 自动化模块接口
/// @notice 负责项目状态自动检查和更新
interface IAutomation {
    // ==================== 事件定义 ====================

    event ProjectStatusAutoUpdated(
        uint256 indexed projectId,
        IProject.ProjectStatus oldStatus,
        IProject.ProjectStatus newStatus,
        string reason
    );

    event BatchProjectsChecked(
        uint256 indexed batchId,
        uint256 totalProjects,
        uint256 updatedProjects
    );

    // ==================== 自动化检查接口 ====================

    /// @notice 检查并更新单个项目状态
    /// @param projectId 项目ID
    /// @return updated 是否更新了状态
    function checkAndUpdateProjectStatus(
        uint256 projectId
    ) external returns (bool updated);

    /// @notice 批量检查项目状态
    /// @param projectIds 项目ID数组
    /// @return updatedCount 更新的项目数量
    function batchCheckProjects(
        uint256[] calldata projectIds
    ) external returns (uint256 updatedCount);

    /// @notice 获取需要检查的项目列表
    /// @return projectIds 需要检查的项目ID数组
    function getProjectsToCheck()
        external
        view
        returns (uint256[] memory projectIds);

    /// @notice 检查项目是否到期
    /// @param projectId 项目ID
    /// @return isExpired 是否到期
    function isProjectExpired(
        uint256 projectId
    ) external view returns (bool isExpired);

    /// @notice 检查项目是否应该开始
    /// @param projectId 项目ID
    /// @return shouldStart 是否应该开始
    function shouldProjectStart(
        uint256 projectId
    ) external view returns (bool shouldStart);

    // ==================== 项目管理接口 ====================

    /// @notice 添加项目到检查列表
    /// @param projectId 项目ID
    function addProjectToCheckList(uint256 projectId) external;

    /// @notice 从检查列表移除项目
    /// @param projectId 项目ID
    function removeProjectFromCheckList(uint256 projectId) external;
}
