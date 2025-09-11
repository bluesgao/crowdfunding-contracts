// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ISettlement} from "../interfaces/ISettlement.sol";
import {Errors} from "../libs/Errors.sol";
import {Events} from "../libs/Events.sol";

/// @title 结算模块
/// @notice 负责费用计算、冻结、退款等结算相关功能
contract Settlement is ISettlement, Ownable, ReentrancyGuard {
    // ==================== 状态变量 ====================

    uint256 public feeRate; // 费用率，以基点为单位 (10000 = 100%)
    address public feePoolAddress; // 费用池地址
    address public frozenPoolAddress; // 冻结池地址

    // 结算记录
    mapping(uint256 => SettlementRecord[]) public projectSettlementRecords; // 项目ID => 结算记录

    // 冻结记录
    mapping(uint256 => FrozenRecord[]) public projectFrozenRecords; // 项目ID => 冻结记录

    // ==================== 构造函数 ====================

    constructor(address initialOwner) Ownable(initialOwner) {
        feeRate = 250; // 默认2.5% (250/10000)
        feePoolAddress = owner();
        frozenPoolAddress = owner();
    }

    // ==================== 费用管理 ====================

    function updateFeeRate(uint256 newFeeRate) external override onlyOwner {
        if (newFeeRate > 1000 || newFeeRate < 0) {
            // 最大10% (1000/10000)
            revert Errors.FeeRateExceedsLimit();
        }

        uint256 oldFeeRate = feeRate;
        feeRate = newFeeRate;

        emit Events.FeeRateUpdated(oldFeeRate, newFeeRate);
    }

    // ==================== 结算管理 ====================

    function getProjectSettlementRecord(
        uint256 projectId
    ) external view override returns (SettlementRecord[] memory) {
        return projectSettlementRecords[projectId];
    }

    function settleProject(
        uint256 projectId,
        uint256 projectAmount,
        address projectCreator
    ) external override onlyOwner nonReentrant {
        // 直接进行成功项目结算（收取费用并转账给项目创建者）
        _settleSuccessfulProject(projectId, projectAmount, projectCreator);
    }

    // ==================== 内部结算函数 ====================

    function _settleSuccessfulProject(
        uint256 projectId,
        uint256 projectAmount,
        address projectCreator
    ) internal {
        uint256 totalAmount = projectAmount;

        // 计算平台费用
        uint256 platformFee = (totalAmount * feeRate) / 10000;
        // 计算项目发起人费用
        uint256 creatorAmount = totalAmount - platformFee;

        // 费用池地址已设置，不需要更新

        // 记录结算信息
        _recordSettlement(projectId, totalAmount, owner(), 1, platformFee); // 平台方
        _recordSettlement(
            projectId,
            totalAmount,
            projectCreator,
            0,
            creatorAmount
        ); // 项目发起人

        // 转账给项目发起人
        if (creatorAmount > 0) {
            (bool success, ) = payable(projectCreator).call{
                value: creatorAmount
            }("");
            if (!success) {
                revert Errors.TransferFailed();
            }
        }
        // 转账给平台方
        if (platformFee > 0) {
            (bool success, ) = payable(feePoolAddress).call{value: platformFee}(
                ""
            );
            if (!success) {
                revert Errors.TransferFailed();
            }
        }

        emit Events.ProjectSettled(projectId, totalAmount);
    }

    function _recordSettlement(
        uint256 projectId,
        uint256 projectAmount,
        address recipient,
        uint8 recipientType,
        uint256 amount
    ) internal {
        SettlementRecord memory record = SettlementRecord({
            projectId: projectId,
            projectAmount: projectAmount,
            recipient: recipient,
            recipientType: recipientType,
            amount: amount,
            timestamp: block.timestamp
        });

        projectSettlementRecords[projectId].push(record);

        emit Events.SettlementRecordCreated(
            projectId,
            projectAmount,
            recipient,
            recipientType,
            amount,
            block.timestamp
        );
    }

    // ==================== 接收ETH ====================

    receive() external payable {
        // 允许接收ETH
    }
}
