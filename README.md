# ETH 众筹合约

一个支持 ETH 的智能合约众筹平台，允许用户发起众筹项目，其他人可以直接发送 ETH 进行投资。

## 🚀 特性

- **直接 ETH 支持**：用户可以直接发送 ETH，无需代币批准
- **平台费用机制**：自动收取 2.5% 平台费用
- **完整的众筹功能**：创建项目、投资、提取、退款
- **安全保护**：重入保护、权限控制、参数验证
- **批量操作**：支持批量退款功能

## 📁 项目结构

```
├── src/
│   └── CrowdfundingETH.sol          # ETH 众筹合约
├── script/
│   └── DeployETH.sol                # 部署脚本
├── test/
│   └── CrowdfundingETH.t.sol        # 测试文件
├── foundry.toml                     # Foundry 配置
└── README.md                        # 项目说明
```

## 🛠️ 开发环境

### 依赖

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)

### 安装

```bash
# 克隆项目
git clone <repository-url>
cd crowdfunding-contracts

# 安装依赖
forge install
```

## 🧪 测试

```bash
# 运行所有测试
forge test

# 运行特定测试
forge test --match-contract CrowdfundingETHTest

# 运行测试并显示详细输出
forge test -vvv
```

## 🚀 部署

### 1. 设置环境变量

```bash
# 设置私钥（64位十六进制字符串，不需要 0x 前缀）
export PRIVATE_KEY=your_64_character_hex_private_key_without_0x_prefix

# 设置 Etherscan API Key（用于合约验证）
export ETHERSCAN_API_KEY=your_etherscan_api_key
```

### 2. 获取测试 ETH

访问 [Sepolia 水龙头](https://faucet.sepolia.dev/) 获取测试 ETH。

### 3. 部署到以太坊 Sepolia

```bash
# 部署合约
forge script script/DeployETH.sol --rpc-url eth_sepolia_alt2 --broadcast --verify
```

### 4. 配置 MetaMask

添加以太坊 Sepolia 测试网络：
- **网络名称**: Sepolia Testnet
- **RPC URL**: `https://rpc.sepolia.org`
- **链 ID**: 11155111
- **货币符号**: ETH
- **区块浏览器**: `https://sepolia.etherscan.io`

## 📋 合约功能

### 创建项目

```solidity
crowdfunding.createProject(
    1 ether,                    // 目标金额：1 ETH
    0.01 ether,                 // 最小投资：0.01 ETH
    0.1 ether,                  // 最大投资：0.1 ETH
    uint64(block.timestamp + 1), // 开始时间
    uint64(block.timestamp + 86400) // 结束时间（24小时）
);
```

### 投资 ETH

```solidity
// 直接发送 ETH 进行投资
crowdfunding.pledge{value: 0.05 ether}(1);
```

### 提取资金（成功众筹）

```solidity
// 项目发起人提取资金（扣除平台费用）
crowdfunding.claim(1);
```

### 申请退款（失败众筹）

```solidity
// 支持者申请退款
crowdfunding.refund(1);
```

### 批量退款

```solidity
// 批量退款给多个投资人
address[] memory investors = [alice, bob, charlie];
crowdfunding.batchRefund(1, investors);
```

## 🔧 管理功能

### 更新平台费用

```solidity
// 更新平台费用率（仅所有者）
crowdfunding.updatePlatformFee(500, newFeeRecipient); // 5%
```

### 紧急提取

```solidity
// 紧急提取合约中的所有 ETH（仅所有者）
crowdfunding.emergencyWithdraw();
```

## 📊 费用结构

- **平台费用**：默认 2.5%（250 基点）
- **费用接收**：可配置费用接收地址
- **最大费用**：限制为 10%（1000 基点）

## 🔐 安全特性

1. **重入保护**：所有外部调用都有重入保护
2. **权限控制**：关键功能只有所有者可以执行
3. **参数验证**：所有输入参数都有严格验证
4. **时间控制**：项目有明确的开始和结束时间
5. **金额限制**：投资金额有最小和最大限制

## 📈 已部署合约

- **合约地址**: `0x1a21d1b9A3346Ff7DeB0917423716e2c3af05a8C`
- **网络**: 以太坊 Sepolia 测试网络
- **区块浏览器**: https://sepolia.etherscan.io/address/0x1a21d1b9a3346ff7deb0917423716e2c3af05a8c

## 📝 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## ⚠️ 免责声明

这是一个测试项目，仅供学习和开发使用。在生产环境中使用前，请进行充分的安全审计。