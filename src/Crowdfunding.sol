// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title 众筹合约 Crowdfunding
/// @notice 允许用户发起众筹项目，其他人可以出资 USDT，如果目标金额达成，项目发起人可以提取资金，否则支持者可以退款。
contract Crowdfunding is Ownable, ReentrancyGuard {
    /// @notice 众筹项目结构体
    struct Project {
        address creator;         // 发起人地址
        uint256 goal;            // 目标金额（USDT，6位小数）
        uint256 pledged;         // 当前已筹金额（USDT，6位小数）
        uint256 minPledge;       // 最小投资金额（USDT，6位小数）
        uint256 maxPledge;       // 最大投资金额（USDT，6位小数）
        uint256 investorCount;   // 投资人数
        uint64 start;            // 开始时间（Unix 时间戳）
        uint64 end;              // 结束时间（Unix 时间戳）
        bool claimed;            // 是否已提取资金
    }

    IERC20 public immutable USDT_TOKEN; // USDT 代币合约地址
    uint256 public projectCount; // 项目总数（自增 ID）
    mapping(uint256 => Project) public projects; // 项目 ID => 项目详情
    mapping(uint256 => mapping(address => uint256)) public investorAmounts; // 项目 ID => (投资人地址 => 投资金额)

    /// @notice 事件：创建新项目
    event ProjectCreated(
        uint256 indexed id, 
        address indexed creator, 
        uint256 goal, 
        uint256 minPledge, 
        uint256 maxPledge, 
        uint64 start, 
        uint64 end
    );
    /// @notice 事件：出资
    event Pledged(
        uint256 indexed id, 
        address indexed backer, 
        uint256 amount, 
        uint256 totalPledged, 
        uint256 userTotalPledged
    );
    /// @notice 事件：取消出资
    event Unpledged(
        uint256 indexed id, 
        address indexed backer, 
        uint256 amount, 
        uint256 remainingPledged, 
        uint256 userRemainingPledged
    );
    /// @notice 事件：项目资金已提取
    event Claimed(
        uint256 indexed id, 
        address indexed creator, 
        uint256 amount, 
        bool goalReached
    );
    /// @notice 事件：用户退款
    event Refunded(
        uint256 indexed id, 
        address indexed backer, 
        uint256 amount, 
        uint256 remainingPledged, 
        bool goalReached
    );

    /// @param initialOwner 合约所有者（通常为部署者）
    /// @param _usdtToken USDT 代币合约地址
    constructor(address initialOwner, address _usdtToken) Ownable(initialOwner) {
        USDT_TOKEN = IERC20(_usdtToken);
    }

    /// @notice 创建一个新的众筹项目
    /// @param _goal 目标金额（USDT，6位小数）
    /// @param _minPledge 最小投资金额（USDT，6位小数）
    /// @param _maxPledge 最大投资金额（USDT，6位小数）
    /// @param _start 开始时间
    /// @param _end 结束时间
    function createProject(uint256 _goal, uint256 _minPledge, uint256 _maxPledge, uint64 _start, uint64 _end) external {
        require(_start >= block.timestamp, "start < now");
        require(_end > _start, "end <= start");
        require(_goal > 0, "goal = 0");
        require(_minPledge > 0, "minPledge = 0");
        require(_maxPledge >= _minPledge, "maxPledge < minPledge");
        require(_maxPledge <= _goal, "maxPledge > goal");

        projectCount++;
        projects[projectCount] = Project({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            minPledge: _minPledge,
            maxPledge: _maxPledge,
            investorCount: 0,
            start: _start,
            end: _end,
            claimed: false
        });

        emit ProjectCreated(projectCount, msg.sender, _goal, _minPledge, _maxPledge, _start, _end);
    }

    /// @notice 出资到某个项目
    /// @param _id 项目 ID
    /// @param _amount 出资金额（USDT，6位小数）
    function pledge(uint256 _id, uint256 _amount) external nonReentrant {
        Project storage project = projects[_id];
        require(block.timestamp >= project.start, "not started");
        require(block.timestamp <= project.end, "ended");
        require(_amount >= project.minPledge, "amount < minPledge");
        require(_amount <= project.maxPledge, "amount > maxPledge");

        // 检查用户总出资额是否超过最大限制
        uint256 totalPledged = investorAmounts[_id][msg.sender] + _amount;
        require(totalPledged <= project.maxPledge, "total pledged > maxPledge");

        // 从用户账户转账 USDT 到合约
        require(USDT_TOKEN.transferFrom(msg.sender, address(this), _amount), "transfer failed");

        // 如果是新投资者，增加投资人数
        if (investorAmounts[_id][msg.sender] == 0) {
            project.investorCount++;
        }

        project.pledged += _amount;
        investorAmounts[_id][msg.sender] += _amount;

        emit Pledged(_id, msg.sender, _amount, project.pledged, investorAmounts[_id][msg.sender]);
    }

    /// @notice 取消出资（在项目截止前）
    /// @param _id 项目 ID
    /// @param _amount 取消的金额（USDT，6位小数）
    function unpledge(uint256 _id, uint256 _amount) external nonReentrant {
        Project storage project = projects[_id];
        require(block.timestamp <= project.end, "ended");

        uint256 bal = investorAmounts[_id][msg.sender];
        require(bal >= _amount, "not enough pledged");

        project.pledged -= _amount;
        investorAmounts[_id][msg.sender] -= _amount;
        
        // 如果用户完全取消出资，减少投资人数
        if (investorAmounts[_id][msg.sender] == 0) {
            project.investorCount--;
            // 注意：这里不直接从投资人列表中移除，因为数组操作成本较高
            // 在批量退款时会检查 investorAmounts 来确定是否真的需要退款
        }
        
        // 将 USDT 转回给用户
        require(USDT_TOKEN.transfer(msg.sender, _amount), "transfer failed");

        emit Unpledged(_id, msg.sender, _amount, project.pledged, investorAmounts[_id][msg.sender]);
    }

    /// @notice 项目发起人提取资金（目标达成 & 已结束）
    /// @param _id 项目 ID
    function claim(uint256 _id) external nonReentrant {
        Project storage project = projects[_id];
        require(msg.sender == project.creator, "not creator");
        require(block.timestamp > project.end, "not ended");
        require(project.pledged >= project.goal, "pledged < goal");
        require(!project.claimed, "already claimed");

        project.claimed = true;
        
        // 将 USDT 转给项目发起人
        require(USDT_TOKEN.transfer(project.creator, project.pledged), "transfer failed");

        emit Claimed(_id, project.creator, project.pledged, true);
    }

    /// @notice 支持者退款（目标未达成 & 已结束）
    /// @param _id 项目 ID
    function refund(uint256 _id) external nonReentrant {
        Project storage project = projects[_id];
        require(block.timestamp > project.end, "not ended");
        require(project.pledged < project.goal, "pledged >= goal");

        uint256 bal = investorAmounts[_id][msg.sender];
        require(bal > 0, "no pledge");

        investorAmounts[_id][msg.sender] = 0;
        
        // 将 USDT 转回给支持者
        require(USDT_TOKEN.transfer(msg.sender, bal), "transfer failed");

        emit Refunded(_id, msg.sender, bal, project.pledged, false);
    }

    /// @notice 批量自动退款（众筹失败时）
    /// @param _id 项目 ID
    /// @param _investors 投资人地址列表
    function batchRefund(uint256 _id, address[] calldata _investors) external nonReentrant {
        Project storage project = projects[_id];
        require(block.timestamp > project.end, "not ended");
        require(project.pledged < project.goal, "pledged >= goal");
        require(!project.claimed, "already claimed");

        for (uint256 i = 0; i < _investors.length; i++) {
            address investor = _investors[i];
            uint256 amount = investorAmounts[_id][investor];
            
            if (amount > 0) {
                investorAmounts[_id][investor] = 0;
                
                // 将 USDT 转回给投资人
                require(USDT_TOKEN.transfer(investor, amount), "transfer failed");
                
                emit Refunded(_id, investor, amount, project.pledged, false);
            }
        }
    }

    /// @notice 检查地址是否为项目的投资人
    /// @param _id 项目 ID
    /// @param _investor 投资人地址
    function isProjectInvestor(uint256 _id, address _investor) external view returns (bool) {
        return investorAmounts[_id][_investor] > 0;
    }

    /// @notice 获取项目的投资人数量（通过遍历所有可能的地址）
    /// @param _id 项目 ID
    /// @param _addresses 要检查的地址列表
    function getInvestorCountFromList(uint256 _id, address[] calldata _addresses) external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (investorAmounts[_id][_addresses[i]] > 0) {
                count++;
            }
        }
        return count;
    }

    /// @notice 获取项目的所有投资人地址（从已知地址列表中筛选）
    /// @param _id 项目 ID
    /// @param _addresses 要检查的地址列表
    function getInvestorAddresses(uint256 _id, address[] calldata _addresses) external view returns (address[] memory) {
        uint256 count = 0;
        
        // 先计算实际投资人数量
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (investorAmounts[_id][_addresses[i]] > 0) {
                count++;
            }
        }
        
        // 创建结果数组
        address[] memory investors = new address[](count);
        
        uint256 index = 0;
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (investorAmounts[_id][_addresses[i]] > 0) {
                investors[index] = _addresses[i];
                index++;
            }
        }
        
        return investors;
    }

    /// @notice 获取项目的投资记录
    /// @param _id 项目 ID
    /// @param _addresses 要检查的地址列表
    function getProjectInvestmentRecords(uint256 _id, address[] calldata _addresses) external view returns (
        address[] memory investors,
        uint256[] memory amounts
    ) {
        uint256 count = 0;
        
        // 先计算实际投资人数量
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (investorAmounts[_id][_addresses[i]] > 0) {
                count++;
            }
        }
        
        // 创建结果数组
        investors = new address[](count);
        amounts = new uint256[](count);
        
        uint256 index = 0;
        for (uint256 i = 0; i < _addresses.length; i++) {
            uint256 amount = investorAmounts[_id][_addresses[i]];
            if (amount > 0) {
                investors[index] = _addresses[i];
                amounts[index] = amount;
                index++;
            }
        }
        
        return (investors, amounts);
    }
}
