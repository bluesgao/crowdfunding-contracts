// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IProject} from "../interfaces/IProject.sol";
import {ISettlement} from "../interfaces/ISettlement.sol";
import {Errors} from "../libs/Errors.sol";
import {Events} from "../libs/Events.sol";

/// @title 项目管理模块
/// @notice 负责项目的创建、状态管理、查询和结算
contract Project is IProject, Ownable, ReentrancyGuard {
    // ==================== 状态变量 ====================

    uint256 private projectIdx;
    mapping(uint256 => Project) public projects;

    // 项目出资记录存储 - 按projectId存储
    mapping(uint256 => ContributionRecord[]) public projectContributionRecords;

    // Pull payment退款存储 - 用户可提取的退款金额
    mapping(uint256 => mapping(address => uint256)) public pendingRefunds;

    // 模块引用
    ISettlement public settlementModule;

    // ==================== 构造函数 ====================

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ==================== 创建项目接口 ====================

    function createProject(
        address owner,
        uint256 targetAmount,
        uint256 minAmount,
        uint256 maxAmount,
        uint64 startTime,
        uint64 endTime
    ) external override onlyOwner returns (uint256 projectId) {
        if (owner == address(0)) {
            revert Errors.InvalidAddress();
        }
        if (targetAmount == 0) {
            revert Errors.InvalidTargetAmount();
        }
        if (startTime >= endTime) {
            revert Errors.InvalidEndTime();
        }
        if (minAmount > maxAmount) {
            revert Errors.MaxAmountLessThanMin();
        }
        if (maxAmount > targetAmount) {
            revert Errors.MaxAmountExceedsTarget();
        }

        projectId = ++projectIdx;
        projects[projectId] = Project({
            id: projectId,
            owner: owner,
            targetAmount: targetAmount,
            contributeAmount: 0,
            minAmount: minAmount,
            maxAmount: maxAmount,
            contributeCount: 0,
            startTime: startTime,
            endTime: endTime,
            settled: false,
            status: ProjectStatus.Pending
        });

        emit Events.ProjectCreated(
            projectId,
            owner,
            targetAmount,
            minAmount,
            maxAmount,
            startTime,
            endTime
        );
    }

    // ==================== 更新项目状态接口 ====================

    function updateProjectStatus(
        uint256 projectId,
        ProjectStatus newStatus
    ) external override onlyOwner {
        _updateProjectStatus(projectId, newStatus);
    }

    function _updateProjectStatus(
        uint256 projectId,
        ProjectStatus newStatus
    ) internal {
        if (projectId == 0 || projectId > projectIdx) {
            revert Errors.ProjectDoesNotExist();
        }

        Project storage project = projects[projectId];
        ProjectStatus oldStatus = project.status;

        if (oldStatus == newStatus) {
            return;
        }

        project.status = newStatus;
        emit Events.ProjectStatusChanged(
            projectId,
            uint8(oldStatus),
            uint8(newStatus)
        );
    }

    // ==================== 查询项目接口 ====================

    function getProject(
        uint256 projectId
    ) external view override returns (Project memory) {
        if (projectId == 0 || projectId > projectIdx) {
            revert Errors.ProjectDoesNotExist();
        }
        return projects[projectId];
    }

    // ==================== 赞助项目接口 ====================

    function contributeProject(
        uint256 projectId,
        address contributor,
        uint256 amount
    ) external override onlyOwner nonReentrant {
        if (projectId == 0 || projectId > projectIdx) {
            revert Errors.ProjectDoesNotExist();
        }
        if (contributor == address(0)) {
            revert Errors.InvalidAddress();
        }
        if (amount == 0) {
            revert Errors.AmountMustBePositive();
        }

        Project storage project = projects[projectId];

        // 检查项目状态
        if (project.status != ProjectStatus.Active) {
            revert Errors.ProjectNotAvailableForContribution();
        }

        // 检查时间
        if (
            block.timestamp < project.startTime ||
            block.timestamp > project.endTime
        ) {
            revert Errors.ProjectNotAvailableForContribution();
        }

        // 检查金额限制
        if (amount < project.minAmount) {
            revert Errors.AmountLessThanMin();
        }
        if (amount > project.maxAmount) {
            revert Errors.AmountExceedsMax();
        }

        // 记录出资记录
        ContributionRecord memory newRecord = ContributionRecord({
            contributor: contributor,
            amount: amount,
            timestamp: block.timestamp,
            status: ContributionStatus.Active
        });

        projectContributionRecords[projectId].push(newRecord);

        // 更新项目统计信息
        project.contributeAmount += amount;
        project.contributeCount++;

        emit Events.ContributionRecordCreated(
            projectId,
            contributor,
            amount,
            block.timestamp
        );
    }

    // ==================== 取消赞助项目接口 ====================

    function cancelContributeProject(
        uint256 projectId,
        address contributor
    ) external override onlyOwner nonReentrant returns (uint256 refundAmount) {
        if (projectId == 0 || projectId > projectIdx) {
            revert Errors.ProjectDoesNotExist();
        }
        if (contributor == address(0)) {
            revert Errors.InvalidAddress();
        }

        Project storage project = projects[projectId];

        // 检查项目状态，只有进行中的项目才能取消赞助
        if (project.status != ProjectStatus.Active) {
            revert Errors.ProjectNotActive();
        }

        // 计算该用户的总出资额
        refundAmount = 0;

        // 将该用户在该项目的所有出资记录状态改为已取消
        ContributionRecord[] storage records = projectContributionRecords[
            projectId
        ];
        for (uint256 i = 0; i < records.length; i++) {
            if (
                records[i].contributor == contributor &&
                records[i].status == ContributionStatus.Active
            ) {
                refundAmount += records[i].amount;
                records[i].status = ContributionStatus.Cancelled;
            }
        }

        if (refundAmount == 0) {
            revert Errors.NoRefundAmount();
        }

        // 更新项目统计信息，减少项目筹集金额，同时减少投资人计数
        project.contributeAmount -= refundAmount;

        // 减少投资人计数
        project.contributeCount--;

        // 触发取消赞助事件
        emit Events.ContributionCancelled(projectId, contributor, refundAmount);

        // 返回退款金额（由主合约处理退款）
        return refundAmount;
    }

    // ==================== 冻结项目接口 ====================

    function freezeProject(
        uint256 projectId
    ) external override onlyOwner nonReentrant {
        if (projectId == 0 || projectId > projectIdx) {
            revert Errors.ProjectDoesNotExist();
        }

        Project storage project = projects[projectId];

        // 检查项目状态，只有进行中的项目才能被冻结
        if (project.status != ProjectStatus.Active) {
            revert Errors.ProjectNotActive();
        }

        // 更新项目状态为冻结
        _updateProjectStatus(projectId, ProjectStatus.Frozen);

        emit Events.ProjectFrozen(
            projectId,
            project.contributeAmount,
            project.contributeCount
        );
    }

    // ==================== 出资记录管理 ====================

    function getProjectContributionRecord(
        uint256 projectId
    ) external view override returns (ContributionRecord[] memory) {
        if (projectId == 0 || projectId > projectIdx) {
            revert Errors.ProjectDoesNotExist();
        }

        return projectContributionRecords[projectId];
    }

    function getProjectRefundDetails(
        uint256 projectId
    )
        external
        override
        onlyOwner
        nonReentrant
        returns (RefundDetail[] memory refundDetails)
    {
        if (projectId == 0 || projectId > projectIdx) {
            revert Errors.ProjectDoesNotExist();
        }

        Project storage project = projects[projectId];

        // 检查项目状态
        if (project.status != ProjectStatus.Failed) {
            revert Errors.ProjectNotFailed();
        }

        ContributionRecord[] storage records = projectContributionRecords[
            projectId
        ];

        // 计算需要退款的记录数量
        uint256 refundCount = 0;
        for (uint256 i = 0; i < records.length; i++) {
            if (records[i].status == ContributionStatus.Active) {
                refundCount++;
            }
        }

        // 创建返回数组
        refundDetails = new RefundDetail[](refundCount);

        // 填充退款明细并更新状态
        uint256 index = 0;
        for (uint256 i = 0; i < records.length; i++) {
            if (records[i].status == ContributionStatus.Active) {
                // 记录退款明细
                refundDetails[index] = RefundDetail({
                    contributor: records[i].contributor,
                    amount: records[i].amount
                });

                // 更新记录状态为已取消
                records[i].status = ContributionStatus.Cancelled;

                // 触发退款事件
                emit Events.Refunded(
                    projectId,
                    records[i].contributor,
                    records[i].amount
                );

                index++;
            }
        }

        // 更新项目统计信息
        project.contributeAmount = 0;
        project.contributeCount = 0;

        // 触发项目退款完成事件
        emit Events.FailedProjectRefunded(
            projectId,
            project.contributeAmount,
            project.contributeCount
        );
    }

    // ==================== Pull Payment退款接口 ====================

    function setPendingRefunds(
        uint256 projectId,
        address[] calldata contributors,
        uint256[] calldata amounts
    ) external override onlyOwner {
        if (contributors.length != amounts.length) {
            revert Errors.InvalidAmount();
        }

        for (uint256 i = 0; i < contributors.length; i++) {
            if (contributors[i] == address(0)) {
                revert Errors.InvalidAddress();
            }
            if (amounts[i] > 0) {
                pendingRefunds[projectId][contributors[i]] = amounts[i];
            }
        }
    }

    function getPendingRefund(
        uint256 projectId,
        address contributor
    ) external view override returns (uint256 amount) {
        return pendingRefunds[projectId][contributor];
    }

    function updateContributionStatus(
        uint256 projectId,
        address contributor,
        ContributionStatus newStatus
    ) external override onlyOwner {
        ContributionRecord[] storage records = projectContributionRecords[
            projectId
        ];
        for (uint256 i = 0; i < records.length; i++) {
            if (records[i].contributor == contributor) {
                records[i].status = newStatus;
            }
        }
    }

    // ==================== 内部函数 ====================

    function _getUserContribution(
        uint256 projectId,
        address contributor
    ) internal view returns (uint256) {
        uint256 totalContribution = 0;

        // 从项目出资记录中计算总出资额
        ContributionRecord[] memory records = projectContributionRecords[
            projectId
        ];
        for (uint256 i = 0; i < records.length; i++) {
            if (
                records[i].contributor == contributor &&
                records[i].status == ContributionStatus.Active
            ) {
                totalContribution += records[i].amount;
            }
        }

        return totalContribution;
    }

    function _getProjectContributors(
        uint256 projectId
    ) internal view returns (address[] memory) {
        // 从项目出资记录中收集所有投资人地址
        ContributionRecord[] memory records = projectContributionRecords[
            projectId
        ];
        address[] memory tempContributors = new address[](records.length);
        uint256 uniqueCount = 0;

        for (uint256 i = 0; i < records.length; i++) {
            ContributionRecord memory record = records[i];
            // 只处理状态为有效的记录
            if (
                record.contributor != address(0) &&
                record.status == ContributionStatus.Active
            ) {
                // 检查这个地址是否已经存在
                bool exists = false;
                for (uint256 j = 0; j < uniqueCount; j++) {
                    if (tempContributors[j] == record.contributor) {
                        exists = true;
                        break;
                    }
                }
                if (!exists) {
                    tempContributors[uniqueCount] = record.contributor;
                    uniqueCount++;
                }
            }
        }

        // 创建最终的结果数组
        address[] memory contributors = new address[](uniqueCount);
        for (uint256 i = 0; i < uniqueCount; i++) {
            contributors[i] = tempContributors[i];
        }

        return contributors;
    }

    function _clearUserContributions(
        uint256 projectId,
        address contributor
    ) internal {
        // 将该用户在该项目的所有出资记录状态改为已取消
        ContributionRecord[] storage records = projectContributionRecords[
            projectId
        ];
        for (uint256 i = 0; i < records.length; i++) {
            if (
                records[i].contributor == contributor &&
                records[i].status == ContributionStatus.Active
            ) {
                records[i].status = ContributionStatus.Cancelled;
            }
        }
    }

    // ==================== 模块管理 ====================

    function setSettlementModule(address _settlementModule) external onlyOwner {
        if (_settlementModule == address(0)) {
            revert Errors.InvalidAddress();
        }
        settlementModule = ISettlement(_settlementModule);
    }
}
