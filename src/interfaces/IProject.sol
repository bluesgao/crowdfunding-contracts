// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title 项目接口
/// @notice 项目相关功能的接口定义
interface IProject {
    // ==================== 枚举定义 ====================

    // ==================== 项目状态枚举 ====================
    // pending->active->success
    // pending->active->failed
    // pending->active->frozen

    enum ProjectStatus {
        Pending, // 待开始
        Active, // 进行中
        Success, // 成功
        Failed, // 失败
        Frozen // 冻结
    }

    // ==================== 结构体定义 ====================

    // ==================== 项目结构体 ====================
    struct Project {
        uint256 id;
        address owner;
        uint256 targetAmount;
        uint256 minAmount;
        uint256 maxAmount;
        uint256 contributeCount;
        uint256 contributeAmount;
        uint64 startTime;
        uint64 endTime;
        bool settled;
        ProjectStatus status;
    }

    // ==================== 出资记录状态枚举 ====================
    enum ContributionStatus {
        Active, // 有效
        Cancelled // 已取消
    }

    // ==================== 出资记录结构体 ====================
    struct ContributionRecord {
        address contributor;
        uint256 amount;
        uint256 timestamp;
        ContributionStatus status;
    }

    // ==================== 退款明细结构体 ====================
    struct RefundDetail {
        address contributor;
        uint256 amount;
    }

    // ==================== 创建项目接口 ====================
    function createProject(
        address owner,
        uint256 targetAmount,
        uint256 minAmount,
        uint256 maxAmount,
        uint64 startTime,
        uint64 endTime
    ) external returns (uint256 projectId);

    // ==================== 更新项目状态接口 ====================
    function updateProjectStatus(
        uint256 projectId,
        ProjectStatus newStatus
    ) external;

    // ==================== 查询项目接口 ====================
    function getProject(
        uint256 projectId
    ) external view returns (Project memory);

    // ==================== 赞助项目接口 ====================
    function contributeProject(
        uint256 projectId,
        address contributor,
        uint256 amount
    ) external;

    // ==================== 取消赞助项目接口 ====================
    function cancelContributeProject(
        uint256 projectId,
        address contributor
    ) external returns (uint256 refundAmount);

    // ==================== 冻结项目接口 ====================
    function freezeProject(uint256 projectId) external;

    // ==================== 项目失败退款接口 ====================
    // 获取项目的退款明细并更新状态（用于批量退款）
    function getProjectRefundDetails(
        uint256 projectId
    ) external returns (RefundDetail[] memory refundDetails);

    // 设置用户可提取的退款金额（pull payment模式）
    function setPendingRefunds(
        uint256 projectId,
        address[] calldata contributors,
        uint256[] calldata amounts
    ) external;

    // 获取用户可提取的退款金额
    function getPendingRefund(
        uint256 projectId,
        address contributor
    ) external view returns (uint256 amount);

    // ==================== 出资记录管理 ====================
    function getProjectContributionRecord(
        uint256 projectId
    ) external view returns (ContributionRecord[] memory);

    // 修改投资记录状态（用于退款）
    function updateContributionStatus(
        uint256 projectId,
        address contributor,
        ContributionStatus newStatus
    ) external;
}
