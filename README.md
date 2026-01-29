# Win11 精简工具箱 (CTT)

一个功能强大的 Windows 11 系统精简、备份、还原一体化工具箱，提供菜单式操作界面，支持预设精简方案和自定义配置。

## ✨ 功能特性

### 核心功能
- **系统还原点管理** - 创建系统还原点，确保操作安全
- **备份清单导出** - 导出 Appx、Capabilities、Features、Services、Tasks 等完整清单
- **预设精简方案** - 提供保守、中度、激进三种预设方案
- **自定义卸载** - 支持手动输入 Appx 包名进行卸载
- **服务与任务管理** - 禁用不必要的系统服务和计划任务
- **OneDrive 管理** - 一键卸载 OneDrive
- **配置管理** - 保存/加载 JSON 格式的配置方案
- **DryRun 模式** - 预演模式，安全测试操作流程
- **空间估算** - 预计节省空间和性能提升报告
- **前后对比** - 记录执行前后真实磁盘空间变化

### 预设精简方案

#### 保守方案（推荐）
卸载以下应用：
- Microsoft.BingNews
- Microsoft.BingWeather
- Microsoft.GetHelp
- Microsoft.Getstarted
- Microsoft.MicrosoftSolitaireCollection
- Microsoft.People
- Microsoft.Todos
- Microsoft.WindowsFeedbackHub
- Microsoft.WindowsMaps
- Microsoft.ZuneMusic
- Microsoft.ZuneVideo

#### 中度方案
在保守方案基础上，额外卸载：
- Microsoft.PowerAutomateDesktop
- MicrosoftTeams
- MicrosoftCorporationII.QuickAssist

#### 激进方案
在中度方案基础上，额外卸载：
- Microsoft.WindowsCamera
- Microsoft.WindowsSoundRecorder
- Microsoft.YourPhone

## 📋 系统要求

- Windows 11
- PowerShell 5.1 或更高版本
- 管理员权限（脚本需要以管理员身份运行）

## 🚀 使用方法

### 1. 下载脚本

```powershell
# 克隆仓库或直接下载 main.ps1 文件
git clone https://github.com/HackerChi-Hub/CTT.git
cd CTT
```

### 2. 运行脚本

**重要：必须以管理员身份运行 PowerShell**

```powershell
# 方法1：右键 PowerShell，选择"以管理员身份运行"，然后执行
.\main.ps1

# 方法2：在普通 PowerShell 中执行（会自动请求管理员权限）
Start-Process powershell -Verb RunAs -ArgumentList "-File `"$PSScriptRoot\main.ps1`""
```

### 3. 推荐操作流程

```
1. 创建系统还原点
   ↓
2. 导出备份清单
   ↓
3. 记录执行前空间基线（菜单 15-1）
   ↓
4. 查看预计节省报告（菜单 14）
   ↓
5. 选择预设精简方案并执行（菜单 3）
   ↓
6. 重启系统
   ↓
7. 查看执行后空间对比（菜单 15-2）
```

## 📖 菜单说明

| 选项 | 功能 |
|------|------|
| 1 | 创建系统还原点 |
| 2 | 导出备份清单 |
| 3 | 预设精简（选择等级：1保守/2中度/3激进）并执行 |
| 4 | 自定义卸载 Appx（手动输入包名） |
| 5 | 禁用计划任务（使用预设列表） |
| 6 | 禁用服务（使用预设列表） |
| 7 | 卸载 OneDrive（切换开关并执行） |
| 8 | 恢复内置 Appx（重新注册） |
| 9 | 打开系统还原界面 |
| 10 | 启动 CTT WinUtil（官方工具） |
| 11 | 切换 DryRun（预演/执行） |
| 12 | 保存/加载配置方案（JSON） |
| 13 | 查看当前配置 |
| 14 | 显示预计节省空间/性能报告 |
| 15 | 记录执行前基线 / 显示执行后对比 |
| 0 | 退出 |

## ⚙️ 配置说明

### 工作目录
默认工作目录：`C:\HackerChi-Win11Toolkit`

包含以下内容：
- `toolkit.log` - 操作日志
- `config.json` - 保存的配置方案
- `baseline_space.json` - 空间基线记录
- `backup_YYYYMMDD_HHMMSS/` - 备份清单目录

### 自定义配置

可以通过菜单 12 保存当前配置，或直接编辑 `config.json`：

```json
{
  "RemoveAppx": [
    "Microsoft.BingNews",
    "Microsoft.BingWeather"
  ],
  "DisableScheduledTasks": [
    "\\Microsoft\\Windows\\Application Experience\\ProgramDataUpdater"
  ],
  "DisableServices": [
    "DiagTrack"
  ],
  "RemoveOneDrive": false
}
```

## ⚠️ 注意事项

1. **必须创建还原点**：在执行精简操作前，强烈建议先创建系统还原点
2. **备份清单**：建议先导出备份清单，以便后续恢复
3. **DryRun 模式**：首次使用建议开启 DryRun 模式，查看将要执行的操作
4. **重启建议**：执行精简操作后，建议重启系统以确保更改生效
5. **风险提示**：
   - 本脚本会修改系统应用/服务/计划任务
   - 默认不提供"关闭更新/关闭Defender"等高风险操作
   - 某些应用卸载后可能影响系统功能，请谨慎选择

## 🔧 高级用法

### 自定义 Appx 卸载

使用菜单 4，输入要卸载的 Appx 包名，多个用英文逗号分隔：

```
示例：Microsoft.YourPhone,MicrosoftTeams
```

### 查看已安装的 Appx

```powershell
Get-AppxPackage -AllUsers | Select-Object Name, PackageFullName | Format-Table
```

### 恢复已卸载的 Appx

如果误删了应用，可以通过以下方式恢复：

1. 使用菜单 8 恢复内置 Appx（重新注册）
2. 从 Microsoft Store 重新安装
3. 使用系统还原点恢复

## 📊 空间估算说明

- **预计报告**：基于当前配置，估算可能释放的空间（近似值）
- **前后对比**：记录执行前后的真实磁盘空间变化（更准确）
- 空间释放主要来自 Appx 和 OneDrive 卸载
- 服务/任务禁用几乎不省空间，但能减少后台占用

## 🐛 故障排除

### 无法创建还原点
- 检查系统保护是否已启用
- 确保有足够的磁盘空间
- 检查系统还原服务是否运行

### Appx 卸载失败
- 某些系统核心应用无法卸载
- 检查应用是否正在运行
- 尝试以管理员身份运行

### 权限不足
- 确保以管理员身份运行 PowerShell
- 检查 UAC 设置

## 📝 日志

所有操作都会记录到日志文件：`C:\HackerChi-Win11Toolkit\toolkit.log`

## 📄 许可证

© 黑客驰 | hackerchi.top All Rights Reserved

## 🙏 致谢

- 参考了 CTT WinUtil 的设计理念
- 感谢所有贡献者和测试用户

## 📞 支持

如有问题或建议，请通过以下方式联系：
- 网站：hackerchi.top
- GitHub Issues：https://github.com/HackerChi-Hub/CTT/issues

---

**免责声明**：本脚本会修改系统应用/服务/计划任务。建议先创建还原点并导出备份清单。使用本脚本产生的任何后果由用户自行承担。
