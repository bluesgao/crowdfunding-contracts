// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title 错误定义
/// @notice 集中管理所有自定义错误
library Errors {
    // ==================== 通用错误 ====================

    error InvalidAddress();
    error InvalidAmount();
    error TransferFailed();
    error Unauthorized();
    error IndexOutOfBounds();

    // ==================== 项目相关错误 ====================

    error ProjectDoesNotExist();
    error ProjectAlreadyFrozen();
    error ProjectAlreadyClaimed();
    error ProjectNotFailed();
    error ProjectNotActive();
    error ProjectNotAvailableForContribution();
    error ProjectNotSettled();
    error ProjectNotSuccess();

    // ==================== 项目参数错误 ====================

    error InvalidTargetAmount();
    error InvalidStartTime();
    error InvalidEndTime();
    error InvalidMinAmount();
    error InvalidMaxAmount();
    error MaxAmountExceedsTarget();
    error MaxAmountLessThanMin();

    // ==================== 赞助相关错误 ====================

    error ETHAmountMismatch();
    error AmountMustBePositive();
    error AmountLessThanMin();
    error AmountExceedsMax();
    error TotalPledgedExceedsMax();
    error NotEnoughPledged();
    error NoRefundAmount();
    error NoRefundAvailable();
    error NoRefundsAvailable();
    error ContributionRecordDoesNotExist();

    // ==================== 结算相关错误 ====================

    error InvalidFeeRate();
    error FeeRateExceedsLimit(); // 费率超过上限
    error InsufficientBalance();
    error FeeRateTooHigh();
    error InvalidFeePool();
    error InvalidFrozenPool();
    error NoFundsToFreeze();

    // ==================== 模块相关错误 ====================

    error InvalidModuleAddress();
    error ContributionFailed();
    error CancelContributionFailed();
    error FreezeProjectFailed();
    error TransferToFrozenPoolFailed();
}
