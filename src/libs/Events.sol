// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title 事件定义
/// @notice 集中管理所有事件
library Events {
    // ==================== 项目相关事件 ====================

    event ProjectCreated(
        uint256 indexed projectId,
        address indexed owner,
        uint256 targetAmount,
        uint256 minAmount,
        uint256 maxAmount,
        uint64 startTime,
        uint64 endTime
    );

    event ProjectStatusChanged(
        uint256 indexed projectId,
        uint8 oldStatus,
        uint8 newStatus
    );

    // ==================== 赞助相关事件 ====================

    event Contributed(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 amount
    );

    event ContributionCancelled(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 amount
    );

    event Refunded(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 amount
    );

    event ContributionRecordCreated(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 amount,
        uint256 timestamp
    );

    // ==================== 结算相关事件 ====================

    event ProjectFrozen(
        uint256 indexed projectId,
        uint256 amount,
        uint256 recordId
    );

    event ProjectSettled(uint256 indexed projectId, uint256 contributeAmount);

    event SettlementRecordCreated(
        uint256 indexed projectId,
        uint256 projectAmount,
        address indexed recipient,
        uint8 recipientType,
        uint256 amount,
        uint256 recordId
    );

    event FeeRateUpdated(uint256 oldFeeRate, uint256 newFeeRate);

    event FeesWithdrawn(uint256 amount);
    event FrozenWithdrawn(uint256 amount);

    // ==================== 自动化相关事件 ====================

    event ProjectAddedToCheckList(uint256 indexed projectId);
    event ProjectRemovedFromCheckList(uint256 indexed projectId);

    // ==================== 模块管理事件 ====================

    event ModulesInitialized(
        address projectModule,
        address contributionModule,
        address automationModule,
        address feeModule
    );

    event FailedProjectRefunded(
        uint256 indexed projectId,
        uint256 contributeAmount,
        uint256 contributeCount
    );
}
