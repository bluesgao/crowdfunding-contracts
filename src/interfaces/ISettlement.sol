// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title 结算模块接口
/// @notice 负责费用计算、冻结、退款等结算相关功能
interface ISettlement {
    // ==================== 结构体定义 ====================

    struct SettlementRecord {
        uint256 projectId; // 项目ID
        uint256 projectAmount; // 项目金额
        address recipient; // 收款人
        uint8 recipientType; // 收款人类型 (0: 项目发起人, 1: 平台方)
        uint256 amount; // 金额
        uint256 timestamp; // 时间
    }

    struct FrozenRecord {
        uint256 projectId;
        uint256 amount;
        uint256 timestamp;
    }

    // ==================== 状态查询 ====================

    function feeRate() external view returns (uint256);
    function feePoolAddress() external view returns (address);
    function frozenPoolAddress() external view returns (address);

    // ==================== 结算管理 ====================

    // 获取项目结算记录
    function getProjectSettlementRecord(
        uint256 projectId
    ) external view returns (SettlementRecord[] memory);

    // 项目结算
    function settleProject(
        uint256 projectId,
        uint256 projectAmount,
        address projectCreator
    ) external;

    // ==================== 费用管理 ====================

    function updateFeeRate(uint256 newFeeRate) external;
}
