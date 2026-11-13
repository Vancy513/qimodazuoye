# GitHub 留痕操作指南

> 工程已写好，只差「有提交历史、可核验」的仓库。
> **便携版 Git 已经放好**：`E:\deveco\tools\git\cmd\git.exe`（2.56.1），不装 Git 也能用。

## 1. 一条命令生成 6 次提交

在工程根目录打开 PowerShell，执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\init-git.ps1 -Name "你的GitHub用户名" -Email "你的GitHub注册邮箱"
```

脚本会：初始化仓库 → 分支改为 `main` → 按「工程→模型→引擎→数据→界面→测试」分 6 次提交 →
打印 `git log --oneline`。

**Name 和 Email 必须与你 GitHub 账号一致**，否则提交不会挂到你头像上，老师核验不到。

> 如果提示「当前目录已经是 Git 仓库」，说明已经初始化过，直接跳到第 3 步。

## 2. 手工方式（等同脚本，想自己敲时用）

```bash
cd E:\deveco\qimodazuoye
git init
git branch -M main
git config user.name "你的GitHub用户名"
git config user.email "你的注册邮箱"
```

然后按功能分批 `git add` + `git commit -m "..."`，信息格式见第 4 步。

## 3. 推到 GitHub

1. 网页端新建仓库，名称 `qimodazuoye`，**不要**勾选 Add a README（否则要处理冲突）。
2. 本地执行（用便携版 Git 就写完整路径）：

```bash
E:\deveco\tools\git\cmd\git.exe remote add origin https://github.com/你的用户名/qimodazuoye.git
E:\deveco\tools\git\cmd\git.exe push -u origin main
```

3. 之后每次改完：

```bash
git add .
git commit -m "feat(rule): 支持规则条件从两条扩展到三条"
git push
```

## 4. 提交信息规范（报告表 4.1 用的就是这 6 条）

```text
chore: 初始化 Stage 模型工程与模块目录
feat(model): 定义环境、设备、规则与日志数据模型
feat(engine): 实现规则求值、优先级排序与冲突裁决
feat(data): 接入 Preferences 持久化
feat(ui): 完成控制台、规则库、日志与场景四个工作区
test(engine): 新增 10 条单元测试并补充文档
```

**推完之后**，把 `git log --oneline` 的 6 个短哈希，从下往上填进报告表 4.1
（最上面一行对应最早的 `chore`）。

## 5. 留痕检查清单

- [ ] 仓库是 **Public**（私有仓库老师点不开）
- [ ] 提交者姓名/邮箱与 GitHub 账号一致（提交记录里点得开头像）
- [ ] 至少 6 次有意义提交，信息不是 `update`、`111`
- [ ] README 有功能说明、环境、截图、运行方法
- [ ] `docs/images/` 已换成真实运行截图
- [ ] 报告表 4.1 的哈希已按 `git log --oneline` 填入
- [ ] 录屏 `演示录屏.mp4` 已上传（或 README 给出链接）

## 6. 常见问题

| 问题 | 处理 |
| --- | --- |
| `git: 无法将"git"项识别为...` | 用便携版完整路径 `E:\deveco\tools\git\cmd\git.exe`，或安装 Git for Windows 后重开终端 |
| push 要求输入密码 | GitHub 已不支持密码，用 Personal Access Token（Settings → Developer settings）或 GitHub Desktop 登录 |
| 误提交了 build 目录 | `git rm -r --cached build` 后再提交（.gitignore 已排除，正常不会发生） |
| 想改提交信息 | 未 push 时 `git commit --amend -m "新信息"`；已 push 后需 force push，慎用 |
| 身份填错了 | 先 `git config user.name/email` 改正，再执行 `git rebase --root --exec "git commit --amend --no-edit --reset-author"` 重写历史 |
