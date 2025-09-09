// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Crowdfunding} from "../src/Crowdfunding.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title CrowdfundingTest
/// @notice 测试 Crowdfunding 合约的基本功能
contract CrowdfundingTest is Test {
    Crowdfunding crowdfunding;
    IERC20 usdtToken;
    address alice = address(1);
    address bob = address(2);

    /// @dev 每个测试运行前执行，部署新的合约实例
    function setUp() public {
        // 部署一个模拟的 USDT 代币合约用于测试
        usdtToken = IERC20(address(new MockUSDT()));
        crowdfunding = new Crowdfunding(address(this), address(usdtToken));

        // 给测试用户分配 USDT
        MockUSDT(address(usdtToken)).mint(alice, 1000 * 10 ** 6); // 1000 USDT
        MockUSDT(address(usdtToken)).mint(bob, 1000 * 10 ** 6); // 1000 USDT
    }

    /// @dev 测试创建新项目
    function testCreateProject() public {
        crowdfunding.createProject(
            1000 * 10 ** 6, // 目标金额：1000 USDT
            10 * 10 ** 6, // 最小投资：10 USDT
            100 * 10 ** 6, // 最大投资：100 USDT
            uint64(block.timestamp + 1),
            uint64(block.timestamp + 100)
        );
        (address creator,, uint256 pledged,, uint256 minPledge, uint256 maxPledge, uint256 investorCount,,) =
            crowdfunding.projects(1);

        // 验证创建者是当前合约
        assertEq(creator, address(this));
        // 初始资金为 0
        assertEq(pledged, 0);
        // 验证最小和最大投资金额
        assertEq(minPledge, 10 * 10 ** 6);
        assertEq(maxPledge, 100 * 10 ** 6);
        // 验证初始投资人数为 0
        assertEq(investorCount, 0);
    }

    /// @dev 测试出资功能
    function testPledge() public {
        crowdfunding.createProject(
            1000 * 10 ** 6, // 目标金额：1000 USDT
            10 * 10 ** 6, // 最小投资：10 USDT
            100 * 10 ** 6, // 最大投资：100 USDT
            uint64(block.timestamp),
            uint64(block.timestamp + 100)
        );

        // 以 alice 的身份调用 pledge，出资 50 USDT
        vm.prank(alice);
        usdtToken.approve(address(crowdfunding), 50 * 10 ** 6);
        vm.prank(alice);
        crowdfunding.pledge(1, 50 * 10 ** 6);

        // 检查项目筹款金额和投资人数
        (,, uint256 pledged,,,, uint256 investorCount,,) = crowdfunding.projects(1);
        assertEq(pledged, 50 * 10 ** 6);
        assertEq(investorCount, 1);
    }

    /// @dev 测试投资金额限制
    function testPledgeLimits() public {
        crowdfunding.createProject(
            1000 * 10 ** 6, // 目标金额：1000 USDT
            10 * 10 ** 6, // 最小投资：10 USDT
            100 * 10 ** 6, // 最大投资：100 USDT
            uint64(block.timestamp),
            uint64(block.timestamp + 100)
        );

        // 测试投资金额小于最小值
        vm.prank(alice);
        usdtToken.approve(address(crowdfunding), 5 * 10 ** 6);
        vm.prank(alice);
        vm.expectRevert("amount < minPledge");
        crowdfunding.pledge(1, 5 * 10 ** 6);

        // 测试投资金额大于最大值
        vm.prank(alice);
        usdtToken.approve(address(crowdfunding), 150 * 10 ** 6);
        vm.prank(alice);
        vm.expectRevert("amount > maxPledge");
        crowdfunding.pledge(1, 150 * 10 ** 6);

        // 测试正常投资
        vm.prank(alice);
        usdtToken.approve(address(crowdfunding), 50 * 10 ** 6);
        vm.prank(alice);
        crowdfunding.pledge(1, 50 * 10 ** 6);

        // 测试再次投资超过最大限制
        vm.prank(alice);
        usdtToken.approve(address(crowdfunding), 60 * 10 ** 6);
        vm.prank(alice);
        vm.expectRevert("total pledged > maxPledge");
        crowdfunding.pledge(1, 60 * 10 ** 6);
    }

    /// @dev 测试创建项目时的参数验证
    function testCreateProjectValidation() public {
        // 测试最大投资金额大于目标金额
        vm.expectRevert("maxPledge > goal");
        crowdfunding.createProject(
            100 * 10 ** 6, // 目标金额：100 USDT
            10 * 10 ** 6, // 最小投资：10 USDT
            150 * 10 ** 6, // 最大投资：150 USDT (大于目标金额)
            uint64(block.timestamp + 1),
            uint64(block.timestamp + 100)
        );

        // 测试最大投资金额等于目标金额（应该成功）
        crowdfunding.createProject(
            100 * 10 ** 6, // 目标金额：100 USDT
            10 * 10 ** 6, // 最小投资：10 USDT
            100 * 10 ** 6, // 最大投资：100 USDT (等于目标金额)
            uint64(block.timestamp + 1),
            uint64(block.timestamp + 100)
        );
    }

    /// @dev 测试投资人数统计
    function testInvestorCount() public {
        crowdfunding.createProject(
            1000 * 10 ** 6, // 目标金额：1000 USDT
            10 * 10 ** 6, // 最小投资：10 USDT
            100 * 10 ** 6, // 最大投资：100 USDT
            uint64(block.timestamp),
            uint64(block.timestamp + 100)
        );

        // 初始投资人数应该为 0
        (,,,,,, uint256 investorCount,,) = crowdfunding.projects(1);
        assertEq(investorCount, 0);

        // Alice 第一次投资
        vm.prank(alice);
        usdtToken.approve(address(crowdfunding), 50 * 10 ** 6);
        vm.prank(alice);
        crowdfunding.pledge(1, 50 * 10 ** 6);

        // 投资人数应该为 1
        (,,,,,, investorCount,,) = crowdfunding.projects(1);
        assertEq(investorCount, 1);

        // Bob 投资
        vm.prank(bob);
        usdtToken.approve(address(crowdfunding), 30 * 10 ** 6);
        vm.prank(bob);
        crowdfunding.pledge(1, 30 * 10 ** 6);

        // 投资人数应该为 2
        (,,,,,, investorCount,,) = crowdfunding.projects(1);
        assertEq(investorCount, 2);

        // Alice 再次投资（同一人，投资人数不变）
        vm.prank(alice);
        usdtToken.approve(address(crowdfunding), 20 * 10 ** 6);
        vm.prank(alice);
        crowdfunding.pledge(1, 20 * 10 ** 6);

        // 投资人数仍然为 2
        (,,,,,, investorCount,,) = crowdfunding.projects(1);
        assertEq(investorCount, 2);

        // Alice 完全取消出资
        vm.prank(alice);
        crowdfunding.unpledge(1, 70 * 10 ** 6);

        // 投资人数应该减少为 1
        (,,,,,, investorCount,,) = crowdfunding.projects(1);
        assertEq(investorCount, 1);
    }

    /// @dev 测试批量自动退款功能
    function testBatchRefund() public {
        crowdfunding.createProject(
            1000 * 10 ** 6, // 目标金额：1000 USDT
            10 * 10 ** 6, // 最小投资：10 USDT
            100 * 10 ** 6, // 最大投资：100 USDT
            uint64(block.timestamp),
            uint64(block.timestamp + 100)
        );

        // Alice 和 Bob 都投资
        vm.prank(alice);
        usdtToken.approve(address(crowdfunding), 50 * 10 ** 6);
        vm.prank(alice);
        crowdfunding.pledge(1, 50 * 10 ** 6);

        vm.prank(bob);
        usdtToken.approve(address(crowdfunding), 30 * 10 ** 6);
        vm.prank(bob);
        crowdfunding.pledge(1, 30 * 10 ** 6);

        // 验证投资人数（使用新的函数）
        address[] memory testAddresses = new address[](2);
        testAddresses[0] = alice;
        testAddresses[1] = bob;
        assertEq(crowdfunding.getInvestorCountFromList(1, testAddresses), 2);

        // 验证投资人信息
        assertTrue(crowdfunding.isProjectInvestor(1, alice));
        assertTrue(crowdfunding.isProjectInvestor(1, bob));

        // 时间推进到项目结束
        vm.warp(block.timestamp + 101);

        // 验证项目未达到目标
        (,, uint256 pledged,,,,,,) = crowdfunding.projects(1);
        assertLt(pledged, 1000 * 10 ** 6);

        // 记录退款前的余额
        uint256 aliceBalanceBefore = usdtToken.balanceOf(alice);
        uint256 bobBalanceBefore = usdtToken.balanceOf(bob);

        // 执行批量退款
        address[] memory investors = new address[](2);
        investors[0] = alice;
        investors[1] = bob;
        crowdfunding.batchRefund(1, investors);

        // 验证退款后的余额
        uint256 aliceBalanceAfter = usdtToken.balanceOf(alice);
        uint256 bobBalanceAfter = usdtToken.balanceOf(bob);

        assertEq(aliceBalanceAfter - aliceBalanceBefore, 50 * 10 ** 6);
        assertEq(bobBalanceAfter - bobBalanceBefore, 30 * 10 ** 6);

        // 验证投资人状态已清除
        assertEq(crowdfunding.investorAmounts(1, alice), 0);
        assertEq(crowdfunding.investorAmounts(1, bob), 0);
    }
}

/// @title MockUSDT
/// @notice 用于测试的模拟 USDT 代币合约
contract MockUSDT is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string public name = "Mock USDT";
    string public symbol = "USDT";
    uint8 public decimals = 6;

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
    }
}
