# Tech Debt Tracker

记录已知但不阻塞当前 phase 的债务。每次 plan 收尾时清扫一次。

约定：已解决的条目用 `~~删除线~~` 标注 + `(resolved YYYY-MM-DD by ...)` 备注；3 个 phase 之后清理过期 resolved。

| Date | Area | Debt | Why It Exists | Planned Follow-Up |
| --- | --- | --- | --- | --- |
| ~~2026-05-18~~ | ~~repo~~ | ~~`~/.emacs.rc/ai/` 尚未 `git init`~~ | ~~历次推进都先去做工程改动，没腾出 2 分钟初始化~~ | ~~**resolved 2026-05-18 by Phase 00 M1**（commit 5ebcede + tag tests-phase-00-start）~~ |
| 2026-05-18 | defensive-load | ~70 处 `(when (fboundp ...))` 防御调用 | 早期对加载顺序无把握，先用 fboundp 兜底 | 测试体系稳定后转成 `require`；建独立 plan |
| 2026-05-18 | file-size | `ask-command.el` 555 行已达上线提示阈值 | 早期 ask 行为陆续叠加，未及时拆分 | 等到 ask 测试拆出后，按子域拆 ask-command |
| ~~2026-05-18~~ | ~~observe~~ | ~~`--plist-inc` 仍在 `observe.el`，与 core 的 `--alist-inc` 不对称~~ | ~~trigger 拆分时只搬了 `--alist-inc`，`--plist-inc` 漏搬~~ | ~~**resolved 2026-05-18 by Phase 02 M3**（迁到 `core/ai-core-rc.el:76` 并更名为 `rc/gptel--plist-inc`）~~ |
| ~~2026-05-18~~ | ~~doc-sync~~ | ~~顶层 `README.md` 与 `00-master-plan` 施工顺序不一致~~ | ~~README 第 10 节给了「helper 先动手」的旧建议~~ | ~~**resolved 2026-05-18 by Phase 00 M3**（README 第 10 节改为指向 master-plan）~~ |
| ~~2026-05-18~~ | ~~doc-priority~~ | ~~README P1-P4 与 master-plan 04.1-4 维度交错~~ | ~~两份文档各自演进，未做映射~~ | ~~**resolved 2026-05-18 by Phase 00 M3**（README 第 5 节加映射表）~~ |
| 2026-05-18 | tag-coverage | weakness-map 仍含 tag-missing 假缺口（ask 9 个、action-request 5 个、context 4 个测试缺 risk tag） | Phase 04 优先聚焦真实补 ERT；retag 需要一次性扫描 + 推断 | Phase 04.5 micro-plan 或 Phase 05 顺手做（预估 30 分钟） |
| 2026-05-18 | matrix-coverage | Phase 04 仅完成 3 条 ⭐⭐⭐ 新 ERT，原计划 ~16+ 条 | 每条新 ERT 需要读 runtime + 设计 mock，耗时被低估 | 留给 Phase 06 calibration SOP 触发后按真实 bug 反推补 |
