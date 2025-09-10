# 部署到以太坊 Sepolia 测试网络指南

## 准备工作

### 1. 设置环境变量

创建 `.env` 文件（不要提交到版本控制）：

```bash
# 部署者私钥（64位十六进制字符串，不需要 0x 前缀）
# 例如：PRIVATE_KEY=1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
PRIVATE_KEY=your_private_key_here

# Etherscan API Key（用于合约验证）
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

**注意**: 私钥应该是64位十六进制字符串，不需要 "0x" 前缀。例如：
- ✅ 正确: `PRIVATE_KEY=1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`
- ❌ 错误: `PRIVATE_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`

### 2. 获取测试 ETH

1. 访问 [Sepolia 水龙头](https://faucet.sepolia.dev/)
2. 输入您的钱包地址
3. 领取测试 ETH

### 3. 配置 MetaMask

添加以太坊 Sepolia 测试网络到 MetaMask：

- **网络名称**: Sepolia Testnet
- **RPC URL**: `https://rpc.sepolia.org`
- **链 ID**: 11155111
- **货币符号**: ETH
- **区块浏览器**: `https://sepolia.etherscan.io`

## 部署步骤

### 1. 编译合约

```bash
forge build
```

### 2. 运行测试

```bash
forge test
```

### 3. 部署到以太坊 Sepolia

```bash
forge script script/DeployToEthSepolia.sol --rpc-url eth_sepolia --broadcast --verify
```

### 4. 验证部署

部署成功后，您将看到：

- 测试 USDT 代币地址
- 众筹合约地址
- 合约所有者信息

## 使用说明

### 1. 添加测试代币到 MetaMask

1. 在 MetaMask 中点击"导入代币"
2. 输入测试 USDT 代币地址
3. 代币符号：TUSDT
4. 小数位数：6

### 2. 测试合约功能

1. 创建众筹项目
2. 投资到项目
3. 测试提取和退款功能

## 网络信息

- **网络名称**: Sepolia Testnet
- **链 ID**: 11155111
- **RPC URL**: `https://rpc.sepolia.org`
- **区块浏览器**: `https://sepolia.etherscan.io`
- **水龙头**: `https://faucet.sepolia.dev/`

## 注意事项

1. 以太坊 Sepolia 测试网络没有官方的 USDT 代币，因此我们部署了测试代币
2. 测试代币会自动铸造 1,000,000 个给部署者
3. 确保您有足够的测试 ETH 来支付 gas 费用
4. 合约验证需要 Etherscan API Key

## 故障排除

### 常见问题

1. **Gas 费用不足**: 确保钱包中有足够的测试 ETH
2. **网络连接问题**: 尝试使用备用的 RPC URL
3. **合约验证失败**: 检查 Etherscan API Key 是否正确

### 备用 RPC URL

如果主 RPC 不可用，可以在 `foundry.toml` 中使用备用 URL：

```toml
eth_sepolia_alt = "https://sepolia.infura.io/v3/${INFURA_API_KEY}"
```
