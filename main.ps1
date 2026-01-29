#requires -RunAsAdministrator
<#
黑客驰 | hackerchi.top
Win11 精简 / 备份 / 还原 / 预计节省 / 前后对比  一体化工具箱（菜单版）
© 黑客驰 | hackerchi.top All Rights Reserved

免责声明：
- 本脚本会修改系统应用/服务/计划任务。建议先创建还原点并导出备份清单。
- 默认不提供“关闭更新/关闭Defender”等高风险操作（容易造成安全/稳定问题）。

功能（一个界面数字选择）：
 1. 创建系统还原点
 2. 导出备份清单（Appx/Capabilities/Features/Services/Tasks + 保存当前配置）
 3. 预设精简（1保守/2中度/3激进）并一键执行
 4. 自定义卸载 Appx（手动输入包名）
 5. 禁用计划任务（使用预设列表）
 6. 禁用服务（使用预设列表）
 7. 卸载 OneDrive（切换开关并可立即执行）
 8. 恢复内置 Appx（重新注册）
 9. 打开系统还原界面（rstrui.exe）
10. 启动 CTT WinUtil（官方样本：irm https://christitus.com/win | iex）
11. 切换 DryRun（预演/执行）
12. 保存/加载 配置方案（JSON）
13. 查看当前配置预览
14. 显示【预计节省空间/性能】报告（基于本机目录估算）
15. 记录执行前基线 / 显示执行后对比（真实磁盘变化）
 0. 退出
#>

[CmdletBinding()]
param(
  [string]$WorkDir = "$env:SystemDrive\HackerChi-Win11Toolkit",
  [string]$LogPath = "$env:SystemDrive\HackerChi-Win11Toolkit\toolkit.log"
)

# -------------------------
# 版权标识
# -------------------------
$CopyrightLine = "黑客驰 | hackerchi.top  © All Rights Reserved"

# -------------------------
# 全局状态
# -------------------------
$Global:DryRun = $false
$Global:ConfigPath = Join-Path $WorkDir "config.json"
$Global:BaselineSpacePath = Join-Path $WorkDir "baseline_space.json"

# -------------------------
# 预设配置
# -------------------------
$Preset = [ordered]@{
  Appx_Baseline = @(
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.People",
    "Microsoft.Todos",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo"
  )

  Appx_Medium = @(
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.People",
    "Microsoft.Todos",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.PowerAutomateDesktop",
    "MicrosoftTeams",
    "MicrosoftCorporationII.QuickAssist"
  )

  Appx_Aggressive = @(
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.People",
    "Microsoft.Todos",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.PowerAutomateDesktop",
    "MicrosoftTeams",
    "MicrosoftCorporationII.QuickAssist",
    "Microsoft.WindowsCamera",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.YourPhone"
  )

  DisableTasks = @(
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
  )

  DisableServices = @(
    "DiagTrack"   # Connected User Experiences and Telemetry
  )
}

# 当前运行配置（默认=保守）
$Global:Config = [ordered]@{
  RemoveAppx = $Preset.Appx_Baseline
  DisableScheduledTasks = $Preset.DisableTasks
  DisableServices = $Preset.DisableServices
  RemoveOneDrive = $false
}

# -------------------------
# 基础工具函数
# -------------------------
function Ensure-WorkDir {
  if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null }
  if (-not (Test-Path (Split-Path $LogPath))) { New-Item -ItemType Directory -Force -Path (Split-Path $LogPath) | Out-Null }
}

function Write-Log([string]$msg) {
  Ensure-WorkDir
  $line = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
  $line | Tee-Object -FilePath $LogPath -Append | Out-Host
}

function Pause-AnyKey {
  Write-Host ""
  Read-Host "按回车返回菜单"
}

function Show-Header {
  Clear-Host
  Write-Host "============================================================"
  Write-Host " Win11 一体化工具箱：精简/备份/还原/预计节省/前后对比"
  Write-Host " $CopyrightLine"
  Write-Host " 工作目录：$WorkDir"
  Write-Host " 日志：$LogPath"
  Write-Host " DryRun（预演）：$($Global:DryRun)"
  Write-Host "============================================================"
}

# -------------------------
# 备份/还原点
# -------------------------
function Try-RestorePoint {
  try {
    if ($Global:DryRun) { Write-Log "[DryRun] 创建系统还原点：Before HackerChi Toolkit"; return }
    Checkpoint-Computer -Description "Before HackerChi Toolkit" -RestorePointType "MODIFY_SETTINGS" | Out-Null
    Write-Log "已创建系统还原点：Before HackerChi Toolkit"
  } catch {
    Write-Log "未能创建还原点（可能未开启系统保护）。你仍可继续，但风险更高。"
  }
}

function Export-BackupInventory {
  Ensure-WorkDir
  $outDir = Join-Path $WorkDir ("backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null

  Write-Log "导出备份清单到：$outDir"

  Get-AppxPackage -AllUsers | Select-Object Name, PackageFullName, Publisher |
    Sort-Object Name | Export-Csv (Join-Path $outDir "appx_allusers.csv") -NoTypeInformation -Encoding UTF8

  Get-WindowsOptionalFeature -Online | Select-Object FeatureName, State |
    Sort-Object FeatureName | Export-Csv (Join-Path $outDir "optional_features.csv") -NoTypeInformation -Encoding UTF8

  Get-WindowsCapability -Online | Select-Object Name, State |
    Sort-Object Name | Export-Csv (Join-Path $outDir "capabilities.csv") -NoTypeInformation -Encoding UTF8

  Get-Service | Select-Object Name, DisplayName, Status, StartType |
    Sort-Object Name | Export-Csv (Join-Path $outDir "services.csv") -NoTypeInformation -Encoding UTF8

  try {
    Get-ScheduledTask | Select-Object TaskName, TaskPath, State |
      Export-Csv (Join-Path $outDir "scheduled_tasks.csv") -NoTypeInformation -Encoding UTF8
  } catch {
    Write-Log "导出计划任务清单失败（部分系统权限限制）：$($_.Exception.Message)"
  }

  ($Global:Config | ConvertTo-Json -Depth 6) | Out-File (Join-Path $outDir "config_used.json") -Encoding UTF8
  Write-Log "备份导出完成。"
}

# -------------------------
# 精简动作：Appx/任务/服务/OneDrive
# -------------------------
function Remove-AppxByName([string[]]$names) {
  foreach ($n in $names) {
    if ([string]::IsNullOrWhiteSpace($n)) { continue }
    Write-Log "处理 Appx：$n"
    $pkgs = Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue
    if (-not $pkgs) {
      Write-Log "  未找到：$n"
      continue
    }
    foreach ($p in $pkgs) {
      $full = $p.PackageFullName
      if ($Global:DryRun) {
        Write-Log "[DryRun] Remove-AppxPackage -AllUsers -Package $full"
        continue
      }
      try {
        Remove-AppxPackage -AllUsers -Package $full -ErrorAction Stop
        Write-Log "  已移除：$full"
      } catch {
        Write-Log "  失败：$full => $($_.Exception.Message)"
      }
    }
  }
}

function Disable-Tasks([string[]]$taskPaths) {
  foreach ($t in $taskPaths) {
    if ([string]::IsNullOrWhiteSpace($t)) { continue }
    Write-Log "处理计划任务：$t"
    if ($Global:DryRun) { Write-Log "[DryRun] Disable-ScheduledTask: $t"; continue }

    try {
      $path = ([IO.Path]::GetDirectoryName($t) + "\")
      $name = ([IO.Path]::GetFileName($t))
      $taskObj = Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop
      Disable-ScheduledTask -InputObject $taskObj | Out-Null
      Write-Log "  已禁用：$t"
    } catch {
      Write-Log "  未找到或失败：$t => $($_.Exception.Message)"
    }
  }
}

function Disable-Services([string[]]$services) {
  foreach ($s in $services) {
    if ([string]::IsNullOrWhiteSpace($s)) { continue }
    Write-Log "处理服务：$s"
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Log "  未找到：$s"; continue }

    if ($Global:DryRun) {
      Write-Log "[DryRun] Stop-Service $s; Set-Service $s -StartupType Disabled"
      continue
    }
    try {
      if ($svc.Status -ne "Stopped") { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
      Set-Service -Name $s -StartupType Disabled -ErrorAction Stop
      Write-Log "  已禁用：$s"
    } catch {
      Write-Log "  失败：$s => $($_.Exception.Message)"
    }
  }
}

function Uninstall-OneDrive {
  Write-Log "卸载 OneDrive（可选）"
  $setup = Join-Path $env:SystemRoot "SysWOW64\OneDriveSetup.exe"
  if (-not (Test-Path $setup)) { $setup = Join-Path $env:SystemRoot "System32\OneDriveSetup.exe" }
  if (-not (Test-Path $setup)) { Write-Log "  未找到 OneDriveSetup.exe，跳过。"; return }

  if ($Global:DryRun) { Write-Log "[DryRun] & `"$setup`" /uninstall"; return }
  try {
    & $setup /uninstall | Out-Null
    Write-Log "  已执行卸载命令（可能需要重启）。"
  } catch {
    Write-Log "  卸载失败：$($_.Exception.Message)"
  }
}

function Restore-BuiltInAppx {
  Write-Log "恢复内置 Appx（重新注册）"
  Write-Log "提示：这会尝试为系统中现存 Appx 重新注册，不等同于从商店重装全部预装包。"

  if ($Global:DryRun) {
    Write-Log "[DryRun] Get-AppxPackage -AllUsers | ForEach Add-AppxPackage -Register AppxManifest.xml"
    return
  }
  try {
    Get-AppxPackage -AllUsers | ForEach-Object {
      $manifest = Join-Path $_.InstallLocation "AppxManifest.xml"
      if (Test-Path $manifest) {
        Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction SilentlyContinue | Out-Null
      }
    }
    Write-Log "恢复（重新注册）完成。"
  } catch {
    Write-Log "恢复失败：$($_.Exception.Message)"
  }
}

function Open-SystemRestoreUI {
  Write-Log "打开系统还原界面（rstrui.exe）"
  if ($Global:DryRun) { Write-Log "[DryRun] Start-Process rstrui.exe"; return }
  try { Start-Process "rstrui.exe" } catch { Write-Log "启动失败：$($_.Exception.Message)" }
}

function Launch-CTTWinUtil {
  Write-Log "启动 CTT WinUtil（官方样本命令）"
  Write-Log '命令：irm "https://christitus.com/win" | iex'
  if ($Global:DryRun) { Write-Log '[DryRun] irm "https://christitus.com/win" | iex'; return }
  try { irm "https://christitus.com/win" | iex } catch { Write-Log "启动失败：$($_.Exception.Message)" }
}

# -------------------------
# 配置/预设/DryRun
# -------------------------
function Toggle-DryRun {
  $Global:DryRun = -not $Global:DryRun
  Write-Log "DryRun 已切换为：$($Global:DryRun)"
}

function Save-Config {
  Ensure-WorkDir
  ($Global:Config | ConvertTo-Json -Depth 6) | Out-File $Global:ConfigPath -Encoding UTF8
  Write-Log "已保存配置到：$($Global:ConfigPath)"
}

function Load-Config {
  if (-not (Test-Path $Global:ConfigPath)) {
    Write-Log "未找到配置文件：$($Global:ConfigPath)"
    return
  }
  try {
    $json = Get-Content $Global:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $Global:Config = [ordered]@{
      RemoveAppx = @($json.RemoveAppx)
      DisableScheduledTasks = @($json.DisableScheduledTasks)
      DisableServices = @($json.DisableServices)
      RemoveOneDrive = [bool]$json.RemoveOneDrive
    }
    Write-Log "已加载配置：$($Global:ConfigPath)"
  } catch {
    Write-Log "加载配置失败：$($_.Exception.Message)"
  }
}

function Set-Preset([ValidateSet("1","2","3")]$level) {
  switch ($level) {
    "1" { $Global:Config.RemoveAppx = $Preset.Appx_Baseline; Write-Log "已选择预设：保守"; }
    "2" { $Global:Config.RemoveAppx = $Preset.Appx_Medium; Write-Log "已选择预设：中度"; }
    "3" { $Global:Config.RemoveAppx = $Preset.Appx_Aggressive; Write-Log "已选择预设：激进"; }
  }
}

function Show-CurrentConfig {
  Write-Host ""
  Write-Host "---------------- 当前配置预览 ----------------"
  Write-Host "RemoveAppx（将卸载的内置Appx）："
  $Global:Config.RemoveAppx | ForEach-Object { Write-Host "  - $_" }
  Write-Host ""
  Write-Host "DisableScheduledTasks（将禁用的计划任务）："
  $Global:Config.DisableScheduledTasks | ForEach-Object { Write-Host "  - $_" }
  Write-Host ""
  Write-Host "DisableServices（将禁用的服务）："
  $Global:Config.DisableServices | ForEach-Object { Write-Host "  - $_" }
  Write-Host ""
  Write-Host "RemoveOneDrive（卸载OneDrive）：$($Global:Config.RemoveOneDrive)"
  Write-Host "------------------------------------------------"
}

function Custom-RemoveAppx {
  Write-Host ""
  Write-Host "请输入要卸载的 Appx 名称（Name 字段），多个用英文逗号分隔。"
  Write-Host "示例：Microsoft.YourPhone,MicrosoftTeams"
  $input = Read-Host "输入"
  if ([string]::IsNullOrWhiteSpace($input)) { return }

  $items = $input.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
  if ($items.Count -eq 0) { return }
  Remove-AppxByName -names $items
}

function Apply-DebloatPresetFlow {
  Show-CurrentConfig
  Write-Host ""
  Write-Host "建议流程：1创建还原点 -> 2导出备份 -> 15-1记录基线 -> 14预计报告 -> 再执行精简"
  $go = Read-Host "确认执行当前配置的精简？(y/n)"
  if ($go -ne "y" -and $go -ne "Y") { Write-Log "用户取消精简执行。"; return }

  Remove-AppxByName -names $Global:Config.RemoveAppx
  Disable-Tasks -taskPaths $Global:Config.DisableScheduledTasks
  Disable-Services -services $Global:Config.DisableServices

  if ($Global:Config.RemoveOneDrive) { Uninstall-OneDrive }

  Write-Log "精简流程执行完成。建议重启一次。"
}

# -------------------------
# 空间估算 & 前后对比
# -------------------------
function Get-FreeSpaceGB {
  $c = Get-PSDrive -Name C
  [math]::Round($c.Free/1GB, 2)
}

function Get-UsedSpaceGB {
  $c = Get-PSDrive -Name C
  [math]::Round(($c.Used)/1GB, 2)
}

function Get-FolderSizeBytes([string]$path) {
  if (-not (Test-Path $path)) { return 0 }
  try {
    (Get-ChildItem -LiteralPath $path -Force -Recurse -ErrorAction SilentlyContinue |
      Measure-Object -Property Length -Sum).Sum
  } catch { 0 }
}

function Estimate-AppxSavingsGB([string[]]$appxNames) {
  $total = 0
  foreach ($n in $appxNames) {
    $pkgs = Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue
    foreach ($p in $pkgs) {
      if ($p.InstallLocation) { $total += (Get-FolderSizeBytes $p.InstallLocation) }
    }
  }
  [math]::Round($total/1GB, 2)
}

function Estimate-OneDriveSavingsGB {
  # 仅估程序本体（不含同步文件/缓存）
  $paths = @(
    "$env:ProgramFiles\Microsoft OneDrive",
    "$env:LOCALAPPDATA\Microsoft\OneDrive"
  )
  $sum = 0
  foreach ($p in $paths) { $sum += (Get-FolderSizeBytes $p) }
  [math]::Round($sum/1GB, 2)
}

function Save-BaselineSpace {
  Ensure-WorkDir
  $obj = [ordered]@{
    time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    free_gb = Get-FreeSpaceGB
    used_gb = Get-UsedSpaceGB
    dryrun = $Global:DryRun
    config = $Global:Config
  }
  ($obj | ConvertTo-Json -Depth 6) | Out-File $Global:BaselineSpacePath -Encoding UTF8
  Write-Log "已记录执行前空间基线：$Global:BaselineSpacePath（C盘Free=$($obj.free_gb)GB）"
}

function Show-SpaceDelta {
  $nowFree = Get-FreeSpaceGB
  if (-not (Test-Path $Global:BaselineSpacePath)) {
    Write-Log "未找到基线文件：$Global:BaselineSpacePath（请先执行 15-1 记录基线）"
    Write-Log "当前 C盘 Free：$nowFree GB"
    return
  }
  $base = Get-Content $Global:BaselineSpacePath -Raw -Encoding UTF8 | ConvertFrom-Json
  $delta = [math]::Round(($nowFree - [double]$base.free_gb), 2)

  Write-Host ""
  Write-Host "============= 空间前后对比（C盘） ============="
  Write-Host "基线时间：$($base.time)"
  Write-Host "执行前 Free：$($base.free_gb) GB"
  Write-Host "当前   Free：$nowFree GB"
  Write-Host "变化（当前-基线）：$delta GB"
  Write-Host "=============================================="
  Write-Log "空间对比：基线Free=$($base.free_gb)GB -> 当前Free=$nowFree GB，变化=$delta GB"
}

function Show-EstimateReport {
  $free = Get-FreeSpaceGB
  $appxGB = Estimate-AppxSavingsGB $Global:Config.RemoveAppx
  $odGB = 0
  if ($Global:Config.RemoveOneDrive) { $odGB = Estimate-OneDriveSavingsGB }
  $sum = [math]::Round($appxGB + $odGB, 2)

  Write-Host ""
  Write-Host "================ 预计节省报告 ================"
  Write-Host "当前 C盘可用：$free GB"
  Write-Host ""
  Write-Host "按【当前配置】估算："
  Write-Host " - 预计卸载 Appx 可释放：$appxGB GB（近似值）"
  if ($Global:Config.RemoveOneDrive) {
    Write-Host " - 预计卸载 OneDrive 程序本体：$odGB GB（不含你的同步文件）"
  } else {
    Write-Host " - OneDrive：未开启卸载（不计入）"
  }
  Write-Host "------------------------------------------------"
  Write-Host "预计合计可释放：$sum GB（真实值以 15-2 前后对比为准）"
  Write-Host ""
  Write-Host "性能预期（经验范围，适合视频口播）："
  Write-Host " - 磁盘收益主要来自 Appx/OneDrive；服务/任务禁用几乎不省空间"
  Write-Host " - 体感更“安静”、后台占用下降：通常 0~3% 级别；内存可能减少 20~150MB"
  Write-Host "================================================"
  Write-Log "预计报告：Appx≈$appxGB GB，OneDrive≈$odGB GB，合计≈$sum GB"
}

# -------------------------
# 菜单
# -------------------------
function Show-Menu {
  Show-Header
  Write-Host "【推荐顺序】1 创建还原点  -> 2 导出备份  -> 15-1 记录基线  -> 14 预计报告  -> 3 精简执行"
  Write-Host ""
  Write-Host " 1. 创建系统还原点"
  Write-Host " 2. 导出备份清单（Appx/Capabilities/Features/Services/Tasks + 保存当前配置）"
  Write-Host " 3. 预设精简（选择等级：1保守 / 2中度 / 3激进）并执行"
  Write-Host " 4. 自定义卸载 Appx（手动输入包名）"
  Write-Host " 5. 禁用计划任务（使用预设列表）"
  Write-Host " 6. 禁用服务（使用预设列表）"
  Write-Host " 7. 卸载 OneDrive（切换开关并执行）"
  Write-Host " 8. 恢复内置 Appx（重新注册）"
  Write-Host " 9. 打开系统还原界面（rstrui.exe）"
  Write-Host "10. 启动 CTT WinUtil（官方样本命令）"
  Write-Host "11. 切换 DryRun（预演/执行）"
  Write-Host "12. 保存/加载 配置方案（JSON）"
  Write-Host "13. 查看当前配置"
  Write-Host "14. 显示【预计节省空间/性能】报告（本机估算）"
  Write-Host "15. 记录执行前基线 / 显示执行后对比（真实变化）"
  Write-Host " 0. 退出"
  Write-Host ""
}

# -------------------------
# 主循环
# -------------------------
Ensure-WorkDir
Write-Log "启动工具箱：$CopyrightLine"

while ($true) {
  Show-Menu
  $choice = Read-Host "请输入数字选择"

  switch ($choice) {
    "1" { Try-RestorePoint; Pause-AnyKey }
    "2" { Export-BackupInventory; Pause-AnyKey }
    "3" {
      Write-Host ""
      Write-Host "选择精简等级："
      Write-Host " 1 = 保守（推荐）"
      Write-Host " 2 = 中度"
      Write-Host " 3 = 激进（更可能误删你需要的应用）"
      $lvl = Read-Host "输入 1/2/3"
      if ($lvl -in @("1","2","3")) {
        Set-Preset -level $lvl
        Apply-DebloatPresetFlow
      } else {
        Write-Log "无效输入：$lvl"
      }
      Pause-AnyKey
    }
    "4" { Custom-RemoveAppx; Pause-AnyKey }
    "5" {
      Write-Host ""
      Write-Host "将禁用以下计划任务："
      $Global:Config.DisableScheduledTasks | ForEach-Object { Write-Host "  - $_" }
      $go = Read-Host "确认执行？(y/n)"
      if ($go -eq "y" -or $go -eq "Y") { Disable-Tasks -taskPaths $Global:Config.DisableScheduledTasks }
      Pause-AnyKey
    }
    "6" {
      Write-Host ""
      Write-Host "将禁用以下服务："
      $Global:Config.DisableServices | ForEach-Object { Write-Host "  - $_" }
      $go = Read-Host "确认执行？(y/n)"
      if ($go -eq "y" -or $go -eq "Y") { Disable-Services -services $Global:Config.DisableServices }
      Pause-AnyKey
    }
    "7" {
      $Global:Config.RemoveOneDrive = -not $Global:Config.RemoveOneDrive
      Write-Log "RemoveOneDrive 开关已切换为：$($Global:Config.RemoveOneDrive)"
      if ($Global:Config.RemoveOneDrive) {
        $go = Read-Host "已开启卸载 OneDrive，是否立即执行卸载？(y/n)"
        if ($go -eq "y" -or $go -eq "Y") { Uninstall-OneDrive }
      }
      Pause-AnyKey
    }
    "8" { Restore-BuiltInAppx; Pause-AnyKey }
    "9" { Open-SystemRestoreUI; Pause-AnyKey }
    "10" { Launch-CTTWinUtil; Pause-AnyKey }
    "11" { Toggle-DryRun; Pause-AnyKey }
    "12" {
      Write-Host ""
      Write-Host "1 = 保存当前配置"
      Write-Host "2 = 加载配置"
      $op = Read-Host "输入 1/2"
      if ($op -eq "1") { Save-Config }
      elseif ($op -eq "2") { Load-Config }
      else { Write-Log "无效输入：$op" }
      Pause-AnyKey
    }
    "13" { Show-CurrentConfig; Pause-AnyKey }
    "14" { Show-EstimateReport; Pause-AnyKey }
    "15" {
      Write-Host ""
      Write-Host "1 = 记录执行前空间基线（建议精简前做）"
      Write-Host "2 = 显示当前与基线的空间变化（建议精简后/重启后做）"
      $op = Read-Host "输入 1/2"
      if ($op -eq "1") { Save-BaselineSpace }
      elseif ($op -eq "2") { Show-SpaceDelta }
      else { Write-Log "无效输入：$op" }
      Pause-AnyKey
    }
    "0" { Write-Log "退出工具箱。"; break }
    default { Write-Log "无效选择：$choice"; Pause-AnyKey }
  }
}
