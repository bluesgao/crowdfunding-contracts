#!/bin/bash

# 部署到 Arbitrum Sepolia 测试网络的脚本

echo "🚀 开始部署到 Arbitrum Sepolia 测试网络..."

# 检查环境变量
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ 错误: 请设置 PRIVATE_KEY 环境变量"
    echo "例如: export PRIVATE_KEY=1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    echo "注意: 私钥应该是64位十六进制字符串，不需要 0x 前缀"
    exit 1
fi

# 检查私钥格式
if [[ ! "$PRIVATE_KEY" =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "❌ 错误: PRIVATE_KEY 格式不正确"
    echo "私钥应该是64位十六进制字符串，不需要 0x 前缀"
    echo "例如: export PRIVATE_KEY=1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    exit 1
fi

# 编译合约
echo "📦 编译合约..."
forge build

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi

echo "✅ 编译成功"

# 运行测试
echo "🧪 运行测试..."
forge test

if [ $? -ne 0 ]; then
    echo "❌ 测试失败"
    exit 1
fi

echo "✅ 测试通过"

# 部署合约
echo "🚀 部署合约到 Arbitrum Sepolia..."
forge script script/DeployToArbitrumSepolia.sol --rpc-url arbitrum_sepolia --broadcast --verify

if [ $? -eq 0 ]; then
    echo "🎉 部署成功！"
    echo ""
    echo "📋 下一步操作："
    echo "1. 在 MetaMask 中添加测试 USDT 代币"
    echo "2. 在区块浏览器中查看合约"
    echo "3. 测试合约功能"
else
    echo "❌ 部署失败"
    exit 1
fi
