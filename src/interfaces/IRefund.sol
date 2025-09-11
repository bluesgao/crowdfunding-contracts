// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title 退款合约接口
/// @notice 负责管理项目退款的独立合约
interface IRefund {
    // ==================== 事件定义 ====================

    event RefundSet(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 amount
    );

    event RefundClaimed(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 amount
    );

    event RefundCleared(uint256 indexed projectId, address indexed contributor);

    // ==================== 退款管理接口 ====================

    /// @notice 设置用户可提取的退款金额
    /// @param projectId 项目ID
    /// @param contributor 出资人地址
    /// @param amount 退款金额
    function setRefund(
        uint256 projectId,
        address contributor,
        uint256 amount
    ) external;

    /// @notice 批量设置退款
    /// @param projectId 项目ID
    /// @param contributors 出资人地址数组
    /// @param amounts 退款金额数组
    function setBatchRefunds(
        uint256 projectId,
        address[] calldata contributors,
        uint256[] calldata amounts
    ) external;

    /// @notice 用户提取退款
    /// @param projectId 项目ID
    /// @return amount 提取的金额
    function claimRefund(uint256 projectId) external returns (uint256 amount);

    /// @notice 获取用户可提取的退款金额
    /// @param projectId 项目ID
    /// @param contributor 出资人地址
    /// @return amount 可提取金额
    function getPendingRefund(
        uint256 projectId,
        address contributor
    ) external view returns (uint256 amount);

    /// @notice 获取项目的所有待退款记录
    /// @param projectId 项目ID
    /// @return contributors 出资人地址数组
    /// @return amounts 退款金额数组
    function getProjectRefunds(
        uint256 projectId
    )
        external
        view
        returns (address[] memory contributors, uint256[] memory amounts);

    /// @notice 清除项目的所有退款记录
    /// @param projectId 项目ID
    function clearProjectRefunds(uint256 projectId) external;
}
