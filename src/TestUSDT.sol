// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title 测试 USDT 代币
/// @notice 用于测试环境的 USDT 代币，模拟 USDT 的 6 位小数
contract TestUSDT is ERC20, Ownable {
    uint8 private constant _DECIMALS = 6;

    constructor(
        address initialOwner
    ) ERC20("Test USDT", "TUSDT") Ownable(initialOwner) {
        // 铸造 1,000,000 个测试 USDT 给部署者
        _mint(initialOwner, 1000000 * 10 ** _DECIMALS);
    }

    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }

    /// @notice 铸造代币（仅所有者）
    /// @param to 接收地址
    /// @param amount 铸造数量
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice 销毁代币（仅所有者）
    /// @param from 销毁地址
    /// @param amount 销毁数量
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
