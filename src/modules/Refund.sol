// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IRefund} from "../interfaces/IRefund.sol";
import {Errors} from "../libs/Errors.sol";

/// @title 退款合约
/// @notice 独立管理项目退款的合约
contract Refund is IRefund, Ownable, ReentrancyGuard {
    // ==================== 状态变量 ====================

    // 项目退款记录 - projectId => contributor => amount
    mapping(uint256 => mapping(address => uint256)) public pendingRefunds;

    // 项目退款列表 - projectId => contributor[]
    mapping(uint256 => address[]) public projectRefundContributors;

    // 授权合约列表
    mapping(address => bool) public authorizedContracts;

    // ==================== 修饰符 ====================

    modifier onlyAuthorized() {
        if (!authorizedContracts[msg.sender] && msg.sender != owner()) {
            revert Errors.Unauthorized();
        }
        _;
    }

    // ==================== 构造函数 ====================

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ==================== 授权管理 ====================

    function setAuthorizedContract(
        address contractAddress,
        bool authorized
    ) external onlyOwner {
        authorizedContracts[contractAddress] = authorized;
    }

    // ==================== 退款管理接口 ====================

    function setRefund(
        uint256 projectId,
        address contributor,
        uint256 amount
    ) external override onlyAuthorized {
        if (contributor == address(0)) {
            revert Errors.InvalidAddress();
        }
        if (amount == 0) {
            revert Errors.InvalidAmount();
        }

        // 如果用户还没有退款记录，添加到列表
        if (pendingRefunds[projectId][contributor] == 0) {
            projectRefundContributors[projectId].push(contributor);
        }

        pendingRefunds[projectId][contributor] = amount;

        emit RefundSet(projectId, contributor, amount);
    }

    function setBatchRefunds(
        uint256 projectId,
        address[] calldata contributors,
        uint256[] calldata amounts
    ) external override onlyAuthorized {
        if (contributors.length != amounts.length) {
            revert Errors.InvalidAmount();
        }

        for (uint256 i = 0; i < contributors.length; i++) {
            if (contributors[i] == address(0)) {
                revert Errors.InvalidAddress();
            }
            if (amounts[i] > 0) {
                // 如果用户还没有退款记录，添加到列表
                if (pendingRefunds[projectId][contributors[i]] == 0) {
                    projectRefundContributors[projectId].push(contributors[i]);
                }

                pendingRefunds[projectId][contributors[i]] = amounts[i];
                emit RefundSet(projectId, contributors[i], amounts[i]);
            }
        }
    }

    function claimRefund(
        uint256 projectId
    ) external override nonReentrant returns (uint256 amount) {
        amount = pendingRefunds[projectId][msg.sender];
        if (amount == 0) {
            revert Errors.NoRefundAvailable();
        }

        // 清除退款记录
        pendingRefunds[projectId][msg.sender] = 0;

        // 直接转账给用户
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert Errors.TransferFailed();
        }

        emit RefundClaimed(projectId, msg.sender, amount);
        return amount;
    }

    function getPendingRefund(
        uint256 projectId,
        address contributor
    ) external view override returns (uint256 amount) {
        return pendingRefunds[projectId][contributor];
    }

    function getProjectRefunds(
        uint256 projectId
    )
        external
        view
        override
        returns (address[] memory contributors, uint256[] memory amounts)
    {
        address[] memory contributorsList = projectRefundContributors[
            projectId
        ];
        uint256 validCount = 0;

        // 计算有效的退款记录数量
        for (uint256 i = 0; i < contributorsList.length; i++) {
            if (pendingRefunds[projectId][contributorsList[i]] > 0) {
                validCount++;
            }
        }

        // 创建返回数组
        contributors = new address[](validCount);
        amounts = new uint256[](validCount);

        uint256 index = 0;
        for (uint256 i = 0; i < contributorsList.length; i++) {
            uint256 amount = pendingRefunds[projectId][contributorsList[i]];
            if (amount > 0) {
                contributors[index] = contributorsList[i];
                amounts[index] = amount;
                index++;
            }
        }
    }

    function clearProjectRefunds(
        uint256 projectId
    ) external override onlyAuthorized {
        address[] memory contributors = projectRefundContributors[projectId];

        for (uint256 i = 0; i < contributors.length; i++) {
            address contributor = contributors[i];
            if (pendingRefunds[projectId][contributor] > 0) {
                pendingRefunds[projectId][contributor] = 0;
                emit RefundCleared(projectId, contributor);
            }
        }

        // 清空贡献者列表
        delete projectRefundContributors[projectId];
    }

    // ==================== 接收ETH ====================

    receive() external payable {
        // 允许接收ETH用于退款
    }
}
