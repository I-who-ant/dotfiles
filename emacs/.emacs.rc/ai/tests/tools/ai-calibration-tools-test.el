;;; ai-calibration-tools-test.el --- Tests for calibration scaffolds -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'subr-x)

(load "/home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/tools/fill-calibration-summaries.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/tools/live-calibration-driver.el" nil t)

(ert-deftest rc/test-create-calibration-run-writes-summary-stats-and-trace ()
  :tags '(domain/meta risk/observability prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-history-" t))
         (template-root (make-temp-file "ai-calibration-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root)))
    (with-temp-file (expand-file-name "language-run-summary.md" template-root)
      (insert "# summary template\n"))
    (with-temp-file (expand-file-name "stats.txt" template-root)
      (insert "Stats snapshot:\n"))
    (let* ((result (rc/test-create-calibration-run "2026-05-20" "cpp" "full-accept"))
           (summary (plist-get result :summary))
           (stats (plist-get result :stats))
           (trace (plist-get result :trace)))
      (should (file-exists-p summary))
      (should (file-exists-p stats))
      (should (file-exists-p trace))
      (should (string-match-p "summary template"
                              (with-temp-buffer
                                (insert-file-contents summary)
                                (buffer-string))))
      (should (string-match-p "\"scenario\": \"full-accept\""
                              (with-temp-buffer
                                (insert-file-contents trace)
                                (buffer-string)))))))

(ert-deftest rc/test-create-calibration-run-refuses-live-root-without-explicit-allow ()
  :tags '(domain/meta risk/protocol prio/1)
  (let* ((history-root (make-temp-file "ai-calibration-live-root-" t))
         (template-root (make-temp-file "ai-calibration-template-" t))
         (rc/test-calibration-default-history-root (file-name-as-directory history-root))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (rc/test-calibration-allow-real-history-write nil))
    (with-temp-file (expand-file-name "language-run-summary.md" template-root)
      (insert "# summary template\n"))
    (with-temp-file (expand-file-name "stats.txt" template-root)
      (insert "Stats snapshot:\n"))
    (should-error
     (rc/test-create-calibration-run "2026-05-20" "cpp" "full-accept")
     :type 'user-error)))

(ert-deftest rc/test-create-calibration-wave-creates-index-weekly-and-common-pack ()
  :tags '(domain/meta risk/observability prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-wave-history-" t))
         (template-root (make-temp-file "ai-calibration-wave-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (rc/test-calibration-default-languages '("cpp" "python"))
         (rc/test-calibration-default-common-scenarios '("full-accept" "coordination"))
         (rc/test-calibration-default-specialized-scenarios
          '(("cpp" . "cpp-tight-loop")
            ("python" . "python-indent-block"))))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (insert (format "template:%s\n" file))))
    (let* ((result (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02"))
           (run-dir (plist-get result :dir))
           (index-file (plist-get result :index))
           (weekly-file (plist-get result :weekly-summary)))
      (should (file-exists-p index-file))
      (should (file-exists-p weekly-file))
      (should (file-exists-p (expand-file-name "summary-cpp-full-accept.md" run-dir)))
      (should (file-exists-p (expand-file-name "summary-python-coordination.md" run-dir)))
      (should (file-exists-p (expand-file-name "summary-cpp-cpp-tight-loop.md" run-dir)))
      (should (file-exists-p (expand-file-name "summary-python-python-indent-block.md" run-dir)))
      (should (= (length (plist-get result :runs)) 6)))))

(ert-deftest rc/test-update-calibration-manual-status-writes-summary-and-refreshes-rollups ()
  :tags '(domain/meta risk/source-consistency prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-update-history-" t))
         (template-root (make-temp-file "ai-calibration-update-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (expected-total (length rc/test-calibration-default-languages))
         (expected-pending (1- expected-total)))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- manual-status: pending\n- manual-updated-at:\n- 真实运行时长(分钟):\n"))
          ("weekly-summary.md"
           (insert "# Weekly Calibration Summary\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Notes\n"))
          ("wave-index.md"
           (insert "# Calibration Wave Index\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Notes\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (make-directory (expand-file-name "2026-05-20" history-root) t)
    (with-temp-file
        (expand-file-name "trace-cpp-line-end-continuation-001.json"
                          (expand-file-name "2026-05-20" history-root))
      (insert "{\n  \"timestamp\": \"2026-05-20 12:00:00 +0800\",\n  \"language\": \"cpp\",\n  \"scenario\": \"line-end-continuation\",\n  \"project\": \"/tmp/cpp/\",\n  \"file\": \"/tmp/cpp/tool_runtime.cpp\",\n  \"major-mode\": \"c++-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"ok\",\n  \"stats-report\": \"requests=1 cache-miss=1\\nblocked-reasons: none\\n\"\n}\n"))
    (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02")
    (rc/test-update-calibration-manual-status "2026-05-20" "cpp" "completed" 31)
    (let ((summary (with-temp-buffer
                     (insert-file-contents
                      (expand-file-name
                       "summary-cpp-cpp-tight-loop.md"
                       (expand-file-name "2026-05-20" history-root)))
                     (buffer-string)))
          (index (with-temp-buffer
                   (insert-file-contents
                    (expand-file-name
                     "phase-07-wave-02-index.md"
                     (expand-file-name "2026-05-20" history-root)))
                   (buffer-string)))
          (weekly (with-temp-buffer
                    (insert-file-contents
                     (expand-file-name
                      "weekly-summary.md"
                      (expand-file-name "2026-05-20" history-root)))
                    (buffer-string))))
      (should (string-match-p "manual-status: completed" summary))
      (should (string-match-p "manual-updated-at: 2026-05-20" summary))
      (should (string-match-p "真实运行时长(分钟): 31" summary))
      (should (string-match-p
               (format "manual calibration 1/%d completed / pending=%d"
                       expected-total
                       expected-pending)
               index))
      (should (string-match-p
               (format "manual calibration 进度: `1/%d specialized scenario completed`"
                       expected-total)
               weekly)))))

(ert-deftest rc/test-update-calibration-manual-status-supports-scenario-override ()
  :tags '(domain/meta risk/protocol prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-update-override-" t))
         (template-root (make-temp-file "ai-calibration-update-override-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root)))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- manual-status: pending\n- manual-updated-at:\n- 真实运行时长(分钟):\n"))
          ("weekly-summary.md"
           (insert "# Weekly Calibration Summary\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Notes\n"))
          ("wave-index.md"
           (insert "# Calibration Wave Index\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Notes\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (make-directory (expand-file-name "2026-05-20" history-root) t)
    (rc/test-create-calibration-run "2026-05-20" "cpp" "line-end-continuation")
    (rc/test-update-calibration-manual-status
     "2026-05-20" "cpp" "partial" 12 "line-end-continuation")
    (let ((summary (with-temp-buffer
                     (insert-file-contents
                      (expand-file-name
                       "summary-cpp-line-end-continuation.md"
                       (expand-file-name "2026-05-20" history-root)))
                     (buffer-string))))
      (should (string-match-p "manual-status: partial" summary))
      (should (string-match-p "真实运行时长(分钟): 12" summary)))))

(ert-deftest rc/test-calibration-status-report-summarizes-specialized-progress ()
  :tags '(domain/meta risk/observability prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-status-history-" t))
         (template-root (make-temp-file "ai-calibration-status-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (rc/test-calibration-default-languages '("cpp" "python" "rust"))
         (rc/test-calibration-default-specialized-scenarios
          '(("cpp" . "cpp-tight-loop")
            ("python" . "python-indent-block")
            ("rust" . "rust-borrowish-block"))))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- manual-status: pending\n- manual-updated-at:\n- 真实运行时长(分钟):\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (let ((rc/test-calibration-allow-real-history-write t))
      (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02")
      (rc/test-update-calibration-manual-status "2026-05-20" "cpp" "completed" 31)
      (rc/test-update-calibration-manual-status "2026-05-20" "python" "partial" 12))
    (let* ((pending (rc/test-calibration-pending-manual-scenarios "2026-05-20"))
           (report (rc/test-calibration-status-report "2026-05-20")))
      (should (= (length pending) 2))
      (should (equal (plist-get (car pending) :language) "python"))
      (should (string-match-p "completed=1 partial=1 pending=1" report))
      (should (string-match-p "- cpp / cpp-tight-loop: completed updated=2026-05-20 runtime=31min"
                              report))
      (should (string-match-p "- python / python-indent-block: partial updated=2026-05-20 runtime=12min"
                              report))
      (should (string-match-p "- rust / rust-borrowish-block: pending" report)))))

(ert-deftest rc/test-calibration-manual-command-queue-renders-pending_commands ()
  :tags '(domain/meta risk/observability prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-queue-history-" t))
         (template-root (make-temp-file "ai-calibration-queue-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (rc/test-calibration-default-languages '("cpp" "python"))
         (rc/test-calibration-default-specialized-scenarios
          '(("cpp" . "cpp-tight-loop")
            ("python" . "python-indent-block"))))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- manual-status: pending\n- manual-updated-at:\n- 真实运行时长(分钟):\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (let ((rc/test-calibration-allow-real-history-write t))
      (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02")
      (rc/test-update-calibration-manual-status "2026-05-20" "cpp" "completed" 31))
    (let ((queue (rc/test-calibration-manual-command-queue "2026-05-20" "phase-07-wave-02")))
      (should (string-match-p "pending-or-partial=1 total=2" queue))
      (should (string-match-p "- python / python-indent-block \\[pending\\]" queue))
      (should (string-match-p "summary: .*/summary-python-python-indent-block\\.md" queue))
      (should (string-match-p "rc/test-update-calibration-manual-status \"2026-05-20\" \"python\" \"completed\" 30 nil \"phase-07-wave-02\"" queue))
      (should (not (string-match-p "- cpp / cpp-tight-loop \\[completed\\]" queue))))))

(ert-deftest rc/test-calibration-manual-brief-renders_language_specific_focus ()
  :tags '(domain/meta risk/observability prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-brief-history-" t))
         (template-root (make-temp-file "ai-calibration-brief-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root)))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- manual-status: pending\n- manual-updated-at:\n- 真实运行时长(分钟):\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (let ((rc/test-calibration-allow-real-history-write t))
      (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02"))
    (let ((brief (rc/test-calibration-manual-brief "2026-05-20" "ts" "phase-07-wave-02")))
      (should (string-match-p "Manual brief for ts / ts-object-literal" brief))
      (should (string-match-p "current-status=pending" brief))
      (should (string-match-p "file: .*/WebFetchTool\\.ts" brief))
      (should (string-match-p "js-mode fallback 是否真的造成体验损失" brief))
      (should (string-match-p "closeout-focus: 明确 `js-mode fallback` 是可接受环境债还是必须修的问题" brief))
      (should (string-match-p "rc/test-update-calibration-manual-status \"2026-05-20\" \"ts\" \"completed\" 30 nil \"phase-07-wave-02\"" brief)))))

(ert-deftest rc/test-calibration-manual-workbook-aggregates_pending_briefs ()
  :tags '(domain/meta risk/observability prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-workbook-history-" t))
         (template-root (make-temp-file "ai-calibration-workbook-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (rc/test-calibration-default-languages '("cpp" "ts"))
         (rc/test-calibration-default-specialized-scenarios
          '(("cpp" . "cpp-tight-loop")
            ("ts" . "ts-object-literal"))))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- manual-status: pending\n- manual-updated-at:\n- 真实运行时长(分钟):\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (let ((rc/test-calibration-allow-real-history-write t))
      (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02")
      (rc/test-update-calibration-manual-status "2026-05-20" "cpp" "completed" 31))
    (let ((workbook (rc/test-calibration-manual-workbook "2026-05-20" "phase-07-wave-02")))
      (should (string-match-p "Manual calibration workbook for 2026-05-20" workbook))
      (should (string-match-p "pending-or-partial=1" workbook))
      (should (string-match-p "Manual brief for ts / ts-object-literal" workbook))
      (should (string-match-p "summary: .*/summary-ts-ts-object-literal\\.md" workbook))
      (should (not (string-match-p "Manual brief for cpp / cpp-tight-loop" workbook))))))

(ert-deftest rc/test-calibration-manual-workbook-template-includes_fill_block ()
  :tags '(domain/meta risk/observability prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-fillable-history-" t))
         (template-root (make-temp-file "ai-calibration-fillable-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (rc/test-calibration-default-languages '("ts"))
         (rc/test-calibration-default-specialized-scenarios
          '(("ts" . "ts-object-literal"))))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- manual-status: pending\n- manual-updated-at:\n- 真实运行时长(分钟):\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (let ((rc/test-calibration-allow-real-history-write t))
      (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02"))
    (let ((workbook (rc/test-calibration-manual-workbook-template "2026-05-20" "phase-07-wave-02")))
      (should (string-match-p "Manual calibration fillable workbook for 2026-05-20" workbook))
      (should (string-match-p "Manual brief for ts / ts-object-literal" workbook))
      (should (string-match-p "fill-this-template:" workbook))
      (should (string-match-p "manual-status: pending\\|partial\\|completed" workbook))
      (should (string-match-p "关单特别关注: 明确 `js-mode fallback` 是可接受环境债还是必须修的问题" workbook)))))

(ert-deftest rc/test-calibration-manual-lint-report-flags-incomplete_completed_entries ()
  :tags '(domain/meta risk/source-consistency prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-lint-history-" t))
         (template-root (make-temp-file "ai-calibration-lint-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (rc/test-calibration-default-languages '("cpp" "python"))
         (rc/test-calibration-default-specialized-scenarios
          '(("cpp" . "cpp-tight-loop")
            ("python" . "python-indent-block"))))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert
            "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n"
            "## Manual Calibration\n\n"
            "- manual-status: pending\n"
            "- manual-updated-at:\n"
            "- 真实运行时长(分钟):\n"
            "- 这 30 分钟大概在写什么:\n"
            "- 是否是真实任务:\n"
            "- 总体顺手程度（1-5）:\n"
            "- 最大优点:\n"
            "- 最大问题:\n\n"
            "## Trigger / Accept / Coordination\n\n"
            "- 行尾触发是否及时:\n"
            "- full accept 是否自然:\n"
            "- followup 是否过于积极:\n"
            "- jump / next-edit 是否真有帮助:\n"
            "- blocked reason 是否解释得通:\n\n"
            "## Cache / Cooldown / Replay\n\n"
            "- 是否明显感受到 cache 命中:\n"
            "- stale -> fresh 替换是否平滑:\n"
            "- 是否出现 cooldown:\n"
            "- 导出的 trace 是否解释了问题:\n\n"
            "## Final Judgment\n\n"
            "- 建议保留的默认行为:\n"
            "- 建议调的参数:\n"
            "- 建议新增测试:\n"
            "- 建议新增文档:\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (let ((rc/test-calibration-allow-real-history-write t))
      (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02")
      (rc/test-update-calibration-manual-status "2026-05-20" "cpp" "completed" 31))
    (let* ((report (rc/test-calibration-manual-lint-report "2026-05-20" "phase-07-wave-02"))
           (entry (rc/test-calibration-manual-lint-entry "2026-05-20" "cpp")))
      (should (string-match-p "invalid-completed=1 total=2" report))
      (should (string-match-p "- cpp / cpp-tight-loop: INVALID completed; missing=" report))
      (should (member "这 30 分钟大概在写什么" (plist-get entry :missing-fields)))
      (should-not (plist-get entry :completed-ready)))))

(ert-deftest rc/test-calibration-manual-lint-report-accepts_filled_completed_entries ()
  :tags '(domain/meta risk/source-consistency prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-lint-ready-history-" t))
         (template-root (make-temp-file "ai-calibration-lint-ready-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (rc/test-calibration-default-languages '("elisp"))
         (rc/test-calibration-default-specialized-scenarios
          '(("elisp" . "elisp-sexp-tail"))))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert
            "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n"
            "## Manual Calibration\n\n"
            "- manual-status: completed\n"
            "- manual-updated-at: 2026-05-20\n"
            "- 真实运行时长(分钟): 30\n"
            "- 这 30 分钟大概在写什么: 在真实配置里改 complete state\n"
            "- 是否是真实任务: 是\n"
            "- 总体顺手程度（1-5）: 4\n"
            "- 最大优点: Sexp tail 比之前顺\n"
            "- 最大问题: followup 偶尔偏激进\n\n"
            "## Trigger / Accept / Coordination\n\n"
            "- 行尾触发是否及时: 基本及时\n"
            "- full accept 是否自然: 基本自然\n"
            "- followup 是否过于积极: 偶尔会\n"
            "- jump / next-edit 是否真有帮助: 有帮助\n"
            "- blocked reason 是否解释得通: 能解释\n\n"
            "## Cache / Cooldown / Replay\n\n"
            "- 是否明显感受到 cache 命中: 能感受到\n"
            "- stale -> fresh 替换是否平滑: 基本平滑\n"
            "- 是否出现 cooldown: 偶尔出现\n"
            "- 导出的 trace 是否解释了问题: 能解释\n\n"
            "## Final Judgment\n\n"
            "- 建议保留的默认行为: 保留 cache reuse\n"
            "- 建议调的参数: 略降 followup 激进度\n"
            "- 建议新增测试: 增加 elisp sexp tail 回归\n"
            "- 建议新增文档: 在 user guide 里补 elisp 场景说明\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (let ((rc/test-calibration-allow-real-history-write t))
      (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02"))
    (let* ((report (rc/test-calibration-manual-lint-report "2026-05-20" "phase-07-wave-02"))
           (entry (rc/test-calibration-manual-lint-entry "2026-05-20" "elisp")))
      (should (string-match-p "invalid-completed=0 total=1" report))
      (should (string-match-p "- elisp / elisp-sexp-tail: ok status=completed" report))
      (should-not (plist-get entry :missing-fields))
      (should (plist-get entry :completed-ready)))))

(ert-deftest rc/test-calibration-latest-date-and-wave-detect_current_history ()
  :tags '(domain/meta risk/observability prio/3)
  (let* ((history-root (make-temp-file "ai-calibration-latest-history-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root)))
    (make-directory (expand-file-name "2026-05-19" history-root) t)
    (make-directory (expand-file-name "2026-05-20" history-root) t)
    (make-directory (expand-file-name "misc" history-root) t)
    (with-temp-file
        (expand-file-name "phase-07-wave-01-index.md"
                          (expand-file-name "2026-05-20" history-root))
      (insert "wave 01"))
    (with-temp-file
        (expand-file-name "phase-07-wave-02-index.md"
                          (expand-file-name "2026-05-20" history-root))
      (insert "wave 02"))
    (should (equal (rc/test-calibration-latest-date) "2026-05-20"))
    (should (equal (rc/test-calibration-latest-wave-name "2026-05-20")
                   "phase-07-wave-02"))))

(ert-deftest rc/test-calibration-manual-dashboard-combines_status_lint_and_queue ()
  :tags '(domain/meta risk/observability prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-dashboard-history-" t))
         (template-root (make-temp-file "ai-calibration-dashboard-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (rc/test-calibration-default-languages '("cpp" "python"))
         (rc/test-calibration-default-specialized-scenarios
          '(("cpp" . "cpp-tight-loop")
            ("python" . "python-indent-block"))))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert
            "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n"
            "## Manual Calibration\n\n"
            "- manual-status: pending\n"
            "- manual-updated-at:\n"
            "- 真实运行时长(分钟):\n"
            "- 这 30 分钟大概在写什么:\n"
            "- 是否是真实任务:\n"
            "- 总体顺手程度（1-5）:\n"
            "- 最大优点:\n"
            "- 最大问题:\n\n"
            "## Trigger / Accept / Coordination\n\n"
            "- 行尾触发是否及时:\n"
            "- full accept 是否自然:\n"
            "- followup 是否过于积极:\n"
            "- jump / next-edit 是否真有帮助:\n"
            "- blocked reason 是否解释得通:\n\n"
            "## Cache / Cooldown / Replay\n\n"
            "- 是否明显感受到 cache 命中:\n"
            "- stale -> fresh 替换是否平滑:\n"
            "- 是否出现 cooldown:\n"
            "- 导出的 trace 是否解释了问题:\n\n"
            "## Final Judgment\n\n"
            "- 建议保留的默认行为:\n"
            "- 建议调的参数:\n"
            "- 建议新增测试:\n"
            "- 建议新增文档:\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (let ((rc/test-calibration-allow-real-history-write t))
      (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02")
      (rc/test-update-calibration-manual-status "2026-05-20" "cpp" "completed" 31))
    (let ((dashboard (rc/test-calibration-manual-dashboard "2026-05-20" "phase-07-wave-02")))
      (should (string-match-p "Manual calibration dashboard for 2026-05-20" dashboard))
      (should (string-match-p "== Status ==" dashboard))
      (should (string-match-p "completed=1 partial=0 pending=1" dashboard))
      (should (string-match-p "== Lint ==" dashboard))
      (should (string-match-p "invalid-completed=1 total=2" dashboard))
      (should (string-match-p "== Queue ==" dashboard))
      (should (string-match-p "- python / python-indent-block \\[pending\\]" dashboard)))))

(ert-deftest rc/test-calibration-phase-closeout-report-blocks_on_pending_and_invalid ()
  :tags '(domain/meta risk/source-consistency prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-closeout-history-" t))
         (template-root (make-temp-file "ai-calibration-closeout-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (rc/test-calibration-default-languages '("cpp" "python"))
         (rc/test-calibration-default-specialized-scenarios
          '(("cpp" . "cpp-tight-loop")
            ("python" . "python-indent-block"))))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert
            "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n"
            "## Manual Calibration\n\n"
            "- manual-status: pending\n"
            "- manual-updated-at:\n"
            "- 真实运行时长(分钟):\n"
            "- 这 30 分钟大概在写什么:\n"
            "- 是否是真实任务:\n"
            "- 总体顺手程度（1-5）:\n"
            "- 最大优点:\n"
            "- 最大问题:\n\n"
            "## Trigger / Accept / Coordination\n\n"
            "- 行尾触发是否及时:\n"
            "- full accept 是否自然:\n"
            "- followup 是否过于积极:\n"
            "- jump / next-edit 是否真有帮助:\n"
            "- blocked reason 是否解释得通:\n\n"
            "## Cache / Cooldown / Replay\n\n"
            "- 是否明显感受到 cache 命中:\n"
            "- stale -> fresh 替换是否平滑:\n"
            "- 是否出现 cooldown:\n"
            "- 导出的 trace 是否解释了问题:\n\n"
            "## Final Judgment\n\n"
            "- 建议保留的默认行为:\n"
            "- 建议调的参数:\n"
            "- 建议新增测试:\n"
            "- 建议新增文档:\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (let ((rc/test-calibration-allow-real-history-write t))
      (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02")
      (rc/test-update-calibration-manual-status "2026-05-20" "cpp" "completed" 31))
    (let ((report (rc/test-calibration-phase-closeout-report "2026-05-20" "phase-07-wave-02")))
      (should (string-match-p "closeable=no" report))
      (should (string-match-p "pending-or-partial=python/python-indent-block\\[pending\\]" report))
      (should (string-match-p "invalid-completed=cpp/cpp-tight-loop missing=" report)))))

(ert-deftest rc/test-calibration-phase-closeout-report-allows_fully_ready_wave ()
  :tags '(domain/meta risk/source-consistency prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-closeout-ready-history-" t))
         (template-root (make-temp-file "ai-calibration-closeout-ready-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (rc/test-calibration-default-languages '("elisp"))
         (rc/test-calibration-default-specialized-scenarios
          '(("elisp" . "elisp-sexp-tail"))))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert
            "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n"
            "## Manual Calibration\n\n"
            "- manual-status: completed\n"
            "- manual-updated-at: 2026-05-20\n"
            "- 真实运行时长(分钟): 30\n"
            "- 这 30 分钟大概在写什么: 在真实配置里写 elisp\n"
            "- 是否是真实任务: 是\n"
            "- 总体顺手程度（1-5）: 4\n"
            "- 最大优点: 续写顺\n"
            "- 最大问题: followup 偶尔偏快\n\n"
            "## Trigger / Accept / Coordination\n\n"
            "- 行尾触发是否及时: 基本及时\n"
            "- full accept 是否自然: 基本自然\n"
            "- followup 是否过于积极: 偶尔会\n"
            "- jump / next-edit 是否真有帮助: 有帮助\n"
            "- blocked reason 是否解释得通: 能解释\n\n"
            "## Cache / Cooldown / Replay\n\n"
            "- 是否明显感受到 cache 命中: 能感受到\n"
            "- stale -> fresh 替换是否平滑: 基本平滑\n"
            "- 是否出现 cooldown: 偶尔出现\n"
            "- 导出的 trace 是否解释了问题: 能解释\n\n"
            "## Final Judgment\n\n"
            "- 建议保留的默认行为: 保留 cache reuse\n"
            "- 建议调的参数: 略降 followup 激进度\n"
            "- 建议新增测试: 增加 elisp 回归\n"
            "- 建议新增文档: 补 user guide\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (let ((rc/test-calibration-allow-real-history-write t))
      (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02"))
    (let ((report (rc/test-calibration-phase-closeout-report "2026-05-20" "phase-07-wave-02")))
      (should (string-match-p "closeable=yes" report))
      (should (string-match-p "reasons:\n- none" report))
      (should (string-match-p "next-step:\n- closeout gate satisfied" report)))))

(ert-deftest rc/test-calibration-completion-audit-blocks_when_manual_runs_pending ()
  :tags '(domain/meta risk/source-consistency prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-audit-history-" t))
         (template-root (make-temp-file "ai-calibration-audit-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (rc/test-calibration-default-languages '("cpp" "python"))
         (rc/test-calibration-default-specialized-scenarios
          '(("cpp" . "cpp-tight-loop")
            ("python" . "python-indent-block"))))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert
            "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n"
            "## Manual Calibration\n\n"
            "- manual-status: pending\n"
            "- manual-updated-at:\n"
            "- 真实运行时长(分钟):\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (let ((rc/test-calibration-allow-real-history-write t))
      (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02"))
    (let ((report (rc/test-calibration-completion-audit "2026-05-20" "phase-07-wave-02")))
      (should (string-match-p "overall-complete=no" report))
      (should (string-match-p "proven-complete:" report))
      (should (string-match-p "not-yet-proven:" report))
      (should (string-match-p "- pending-manual: cpp / cpp-tight-loop \\[pending\\]" report))
      (should (string-match-p "- overall completion cannot yet be claimed" report)))))

(ert-deftest rc/test-calibration-completion-audit-allows_when_wave_ready ()
  :tags '(domain/meta risk/source-consistency prio/2)
  (let* ((history-root (make-temp-file "ai-calibration-audit-ready-history-" t))
         (template-root (make-temp-file "ai-calibration-audit-ready-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (rc/test-calibration-default-languages '("elisp"))
         (rc/test-calibration-default-specialized-scenarios
          '(("elisp" . "elisp-sexp-tail"))))
    (dolist (file '("language-run-summary.md"
                    "stats.txt"
                    "weekly-summary.md"
                    "wave-index.md"))
      (with-temp-file (expand-file-name file template-root)
        (pcase file
          ("language-run-summary.md"
           (insert
            "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n"
            "## Manual Calibration\n\n"
            "- manual-status: completed\n"
            "- manual-updated-at: 2026-05-20\n"
            "- 真实运行时长(分钟): 30\n"
            "- 这 30 分钟大概在写什么: 在真实配置里写 elisp\n"
            "- 是否是真实任务: 是\n"
            "- 总体顺手程度（1-5）: 4\n"
            "- 最大优点: 续写顺\n"
            "- 最大问题: followup 偶尔偏快\n\n"
            "## Trigger / Accept / Coordination\n\n"
            "- 行尾触发是否及时: 基本及时\n"
            "- full accept 是否自然: 基本自然\n"
            "- followup 是否过于积极: 偶尔会\n"
            "- jump / next-edit 是否真有帮助: 有帮助\n"
            "- blocked reason 是否解释得通: 能解释\n\n"
            "## Cache / Cooldown / Replay\n\n"
            "- 是否明显感受到 cache 命中: 能感受到\n"
            "- stale -> fresh 替换是否平滑: 基本平滑\n"
            "- 是否出现 cooldown: 偶尔出现\n"
            "- 导出的 trace 是否解释了问题: 能解释\n\n"
            "## Final Judgment\n\n"
            "- 建议保留的默认行为: 保留 cache reuse\n"
            "- 建议调的参数: 略降 followup 激进度\n"
            "- 建议新增测试: 增加 elisp 回归\n"
            "- 建议新增文档: 补 user guide\n"))
          (_
           (insert (format "template:%s\n" file))))))
    (let ((rc/test-calibration-allow-real-history-write t))
      (rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02"))
    (let ((report (rc/test-calibration-completion-audit "2026-05-20" "phase-07-wave-02")))
      (should (string-match-p "overall-complete=yes" report))
      (should (string-match-p "current-blockers:\n- none" report))
      (should (string-match-p "- overall completion can be claimed" report)))))

(ert-deftest rc/test-live-case-finds-wave-02-before-wave-01 ()
  :tags '(domain/meta risk/source-consistency prio/3)
  (let ((rc/test-live-wave-01-cases
         '((:language "cpp" :scenario "general" :marker wave-01-general)))
        (rc/test-live-wave-02-common-cases
         '((:language "cpp" :scenario "full-accept" :marker wave-02-full)
           (:language "cpp" :scenario "coordination" :marker wave-02-coordination)))
        (rc/test-live-wave-02-specialized-cases nil))
    (should (eq (plist-get (rc/test-live--case "cpp" "full-accept") :marker)
                'wave-02-full))
    (should (eq (plist-get (rc/test-live--case "cpp" "general") :marker)
                'wave-01-general))))

(ert-deftest rc/test-live-wave-02-full-accept-case-carries-accept-mode ()
  :tags '(domain/meta risk/protocol prio/2)
  (let ((case (rc/test-live--case "cpp" "full-accept")))
    (should case)
    (should (eq (plist-get case :accept) 'full))))

(ert-deftest rc/test-live-wave-02-cache-revisit-case-carries-probe-kind ()
  :tags '(domain/meta risk/protocol prio/2)
  (let ((case (rc/test-live--case "cpp" "cache-revisit")))
    (should case)
    (should (eq (plist-get case :probe-kind) 'cache-revisit))))

(ert-deftest rc/test-live-wave-02-diverge-restore-case-carries-probe-kind ()
  :tags '(domain/meta risk/protocol prio/2)
  (let ((case (rc/test-live--case "cpp" "diverge-and-restore")))
    (should case)
    (should (eq (plist-get case :probe-kind) 'diverge-and-restore))))

(ert-deftest rc/test-live-wave-02-coordination-case-carries-probe-kind ()
  :tags '(domain/meta risk/protocol prio/2)
  (let ((case (rc/test-live--case "cpp" "coordination")))
    (should case)
    (should (eq (plist-get case :probe-kind) 'coordination))))

(ert-deftest rc/test-live-wave-02-specialized-cases-carry-specialized-scenarios ()
  :tags '(domain/meta risk/protocol prio/2)
  (dolist (pair '(("cpp" . "cpp-tight-loop")
                  ("python" . "python-indent-block")
                  ("rust" . "rust-borrowish-block")
                  ("ts" . "ts-object-literal")
                  ("elisp" . "elisp-sexp-tail")))
    (let ((case (rc/test-live--case (car pair) (cdr pair))))
      (should case)
      (should (equal (plist-get case :scenario) (cdr pair)))
      (should (stringp (plist-get case :file)))
      (should (stringp (plist-get case :snippet)))
      (should (> (length (plist-get case :snippet)) 20)))))

(ert-deftest rc/test-live-json-ready-normalizes-plists-and-vectors ()
  :tags '(domain/meta risk/observability prio/3)
  (let* ((payload (list :language "cpp"
                        :settled (list :reason 'visible :visible t)
                        :vector [1 :ok]))
         (json-ready (rc/test-live--json-ready payload))
         (settled (cdr (assoc "settled" json-ready)))
         (vector-value (cdr (assoc "vector" json-ready))))
    (should (equal (cdr (assoc "language" json-ready)) "cpp"))
    (should (equal (cdr (assoc "reason" settled)) "visible"))
    (should (vectorp vector-value))
    (should (equal (aref vector-value 1) "ok"))))

(provide 'ai-calibration-tools-test)
;;; ai-calibration-tools-test.el ends here
