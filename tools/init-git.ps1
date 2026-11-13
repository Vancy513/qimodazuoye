<#
.SYNOPSIS
  一次性把工程初始化为 Git 仓库，并按「工程→模型→引擎→数据→界面→测试」的顺序生成 6 次提交。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tools\init-git.ps1 -Name "your-github-name" -Email "you@example.com"
#>
param(
  [Parameter(Mandatory = $true)][string]$Name,
  [Parameter(Mandatory = $true)][string]$Email,
  [string]$Repo = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

# 1. 找 git：优先 PATH，其次便携版
$gitCmd = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $gitCmd) {
  $portable = 'E:\deveco\tools\git\cmd\git.exe'
  if (Test-Path $portable) { $gitCmd = $portable }
}
if (-not $gitCmd) { throw '未找到 git，请先安装 Git for Windows 或把便携版放到 E:\deveco\tools\git' }

Push-Location $Repo
try {
  if (Test-Path (Join-Path $Repo '.git')) { throw '当前目录已经是 Git 仓库，请先确认，勿重复初始化' }

  & $gitCmd init -q
  & $gitCmd symbolic-ref HEAD refs/heads/main
  & $gitCmd config user.name $Name
  & $gitCmd config user.email $Email

  function Stage([string[]]$paths) {
    foreach ($p in $paths) {
      if (Test-Path (Join-Path $Repo $p)) { & $gitCmd add -- $p }
    }
  }
  function Commit([string]$msg) {
    & $gitCmd commit -q -m $msg
    if ($LASTEXITCODE -ne 0) { throw "提交失败：$msg" }
    Write-Host ("  [ok] " + $msg)
  }

  Write-Host '生成提交历史 ...'

  Stage @('build-profile.json5', 'oh-package.json5', 'oh-package-lock.json5', 'hvigorfile.ts', 'code-linter.json5',
          '.gitignore', 'hvigor', 'AppScope', 'entry/build-profile.json5', 'entry/hvigorfile.ts',
          'entry/oh-package.json5', 'entry/obfuscation-rules.txt', 'entry/.gitignore',
          'entry/src/main/module.json5', 'entry/src/main/ets/entryability',
          'entry/src/main/ets/entrybackupability', 'entry/src/main/resources', 'entry/src/mock')
  Commit 'chore: 初始化 Stage 模型工程与模块目录'

  Stage @('entry/src/main/ets/model', 'entry/src/main/ets/data/LabDefaults.ets')
  Commit 'feat(model): 定义环境、设备、规则与日志数据模型'

  Stage @('entry/src/main/ets/engine')
  Commit 'feat(engine): 实现规则求值、优先级排序与冲突裁决'

  Stage @('entry/src/main/ets/data/LabRepository.ets')
  Commit 'feat(data): 接入 Preferences 持久化'

  Stage @('entry/src/main/ets/pages')
  Commit 'feat(ui): 完成控制台、规则库、日志与场景四个工作区'

  Stage @('entry/src/test', 'entry/src/ohosTest', 'docs', 'README.md', 'tools')
  Commit 'test(engine): 新增 10 条单元测试并补充文档'

  Write-Host ''
  Write-Host '提交历史：'
  & $gitCmd log --oneline
  Write-Host ''
  Write-Host '下一步：在 GitHub 新建空仓库后执行'
  Write-Host ('  git remote add origin https://github.com/<你的用户名>/qimodazuoye.git')
  Write-Host '  git push -u origin main'
}
finally {
  Pop-Location
}
