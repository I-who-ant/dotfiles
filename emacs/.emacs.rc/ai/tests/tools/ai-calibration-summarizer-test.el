;;; ai-calibration-summarizer-test.el --- Tests for calibration markdown filler -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/tools/fill-calibration-summaries.el" nil t)

(defun rc/test--write-json-file (file content)
  "Write CONTENT string to FILE."
  (make-directory (file-name-directory file) t)
  (with-temp-file file
    (insert content)))

(ert-deftest rc/test-calibration-fill-summary-renders-scripted-visible-fields ()
  :tags '(domain/meta risk/observability prio/2)
  (let* ((history-root (make-temp-file "ai-cal-fill-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (run-dir (expand-file-name "2026-05-20" history-root))
         (trace-file (expand-file-name "trace-cpp-line-end-continuation-001.json" run-dir)))
    (rc/test--write-json-file
     trace-file
     "{\n  \"timestamp\": \"2026-05-19 15:16:36 +0800\",\n  \"language\": \"cpp\",\n  \"scenario\": \"line-end-continuation\",\n  \"project\": \"/tmp/cpp/\",\n  \"file\": \"/tmp/cpp/tool_runtime.cpp\",\n  \"major-mode\": \"c++-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"total += std::stoi(item);\",\n  \"stats-report\": \"AI Complete Stats: tool_runtime.cpp\\n  requests=1 cache-miss=1\\n  latency first p50=1.82\\n  blocked-reasons: none\\n\"\n}\n")
    (rc/test-calibration-fill-summary "2026-05-20" "cpp" "line-end-continuation")
    (let ((text (with-temp-buffer
                  (insert-file-contents
                   (expand-file-name "summary-cpp-line-end-continuation.md" run-dir))
                  (buffer-string))))
      (should (string-match-p "语言: `cpp`" text))
      (should (string-match-p "major-mode: `c\\+\\+-ts-mode`" text))
      (should (string-match-p "requests=1 cache-miss=1 blocked-reasons=none latency-first≈1.82s" text))
      (should (string-match-p "request-started -> cached -> visible" text))
      (should (string-match-p "<!-- AUTO:BEGIN -->" text)))))

(ert-deftest rc/test-create-calibration-run-template-keeps_completed_gate_hint ()
  :tags '(domain/meta risk/protocol prio/2)
  (let* ((history-root (make-temp-file "ai-cal-gate-history-" t))
         (template-root (make-temp-file "ai-cal-gate-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root)))
    (with-temp-file (expand-file-name "language-run-summary.md" template-root)
      (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- manual-status: pending\n- manual-updated-at:\n- 真实运行时长(分钟):\n- completed gate:\n  - 只有真实 specialized run 覆盖了 accept / cache / divergence / coordination，并回填完 Final Judgment，才允许改成 `completed`\n"))
    (with-temp-file (expand-file-name "stats.txt" template-root)
      (insert "Stats snapshot:\n"))
    (let* ((result (rc/test-create-calibration-run "2026-05-20" "cpp" "cpp-tight-loop"))
           (summary (plist-get result :summary))
           (text (with-temp-buffer
                   (insert-file-contents summary)
                   (buffer-string))))
      (should (string-match-p "completed gate:" text))
      (should (string-match-p "真实 specialized run" text)))))

(ert-deftest rc/test-calibration-fill-summary-renders-full-accept-fields ()
  :tags '(domain/meta risk/protocol prio/2)
  (let* ((history-root (make-temp-file "ai-cal-fill-accept-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (run-dir (expand-file-name "2026-05-20" history-root))
         (trace-file (expand-file-name "trace-cpp-full-accept-001.json" run-dir)))
    (rc/test--write-json-file
     trace-file
     "{\n  \"timestamp\": \"2026-05-19 21:34:08 +0800\",\n  \"language\": \"cpp\",\n  \"scenario\": \"full-accept\",\n  \"project\": \"/tmp/cpp/\",\n  \"file\": \"/tmp/cpp/tool_runtime.cpp\",\n  \"major-mode\": \"c++-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"accept\": \"full\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null, \"post-accept-state\": \"accepted\"},\n  \"visible-text\": \"total += std::stoi(item);\",\n  \"stats-report\": \"AI Complete Stats: tool_runtime.cpp\\n  requests=1 cache-miss=1\\n  latency first p50=1.17\\n  blocked-reasons: none\\n\"\n}\n")
    (rc/test-calibration-fill-summary "2026-05-20" "cpp" "full-accept")
    (let ((text (with-temp-buffer
                  (insert-file-contents
                   (expand-file-name "summary-cpp-full-accept.md" run-dir))
                  (buffer-string))))
      (should (string-match-p "accept mode: `full`" text))
      (should (string-match-p "post-accept-state: `accepted`" text))
      (should (string-match-p "Common Scenario B 接受 / 部分接受: `已覆盖；按 scripted probe 视角拿到接受后状态`" text))
      (should (string-match-p "full accept 已实际执行（accept=full），post-accept-state=accepted" text)))))

(ert-deftest rc/test-calibration-fill-summary-renders-cache-revisit-fields ()
  :tags '(domain/meta risk/cache-hit prio/2)
  (let* ((history-root (make-temp-file "ai-cal-fill-cache-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (run-dir (expand-file-name "2026-05-20" history-root))
         (trace-file (expand-file-name "trace-cpp-cache-revisit-001.json" run-dir)))
    (rc/test--write-json-file
     trace-file
     "{\n  \"timestamp\": \"2026-05-20 10:00:00 +0800\",\n  \"language\": \"cpp\",\n  \"scenario\": \"cache-revisit\",\n  \"project\": \"/tmp/cpp/\",\n  \"file\": \"/tmp/cpp/tool_runtime.cpp\",\n  \"major-mode\": \"c++-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"total += std::stoi(item);\",\n  \"cache-revisit\": {\"revisit-success\": true, \"second-request-source\": \"cache\", \"second-cache-source\": \"result\", \"second-cache-hit-kind\": \"exact\", \"second-network-request-p\": null, \"second-display-phase\": \"visible\"},\n  \"stats-report\": \"AI Complete Stats: tool_runtime.cpp\\n  requests=1 cache-miss=1\\n  latency first p50=0.63\\n  blocked-reasons: none\\n\"\n}\n")
    (rc/test-calibration-fill-summary "2026-05-20" "cpp" "cache-revisit")
    (let ((text (with-temp-buffer
                  (insert-file-contents
                   (expand-file-name "summary-cpp-cache-revisit.md" run-dir))
                  (buffer-string))))
      (should (string-match-p "cache-revisit evidence: `second-source=cache hit=exact network=no display=visible`" text))
      (should (string-match-p "Common Scenario C cache / revisit: `已部分覆盖；已验证二次触发 cache revisit，stale/prefix 仍待后续细化`" text))
      (should (string-match-p "revisit(cache/exact)" text))
      (should (string-match-p "cache revisit 二次触发 直接走 cache（hit=exact），且没有新的网络请求" text)))))

(ert-deftest rc/test-calibration-fill-summary-renders-diverge-restore-fields ()
  :tags '(domain/meta risk/source-consistency prio/2)
  (let* ((history-root (make-temp-file "ai-cal-fill-diverge-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (run-dir (expand-file-name "2026-05-20" history-root))
         (trace-file (expand-file-name "trace-cpp-diverge-and-restore-001.json" run-dir)))
    (rc/test--write-json-file
     trace-file
     "{\n  \"timestamp\": \"2026-05-20 11:00:00 +0800\",\n  \"language\": \"cpp\",\n  \"scenario\": \"diverge-and-restore\",\n  \"project\": \"/tmp/cpp/\",\n  \"file\": \"/tmp/cpp/tool_runtime.cpp\",\n  \"major-mode\": \"c++-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"total += std::stoi(item);\",\n  \"diverge-restore\": {\"restore-available-during\": true, \"divergence-distance\": 1, \"restored-event\": true, \"visible-after-restore\": true, \"restore-success\": true},\n  \"stats-report\": \"AI Complete Stats: tool_runtime.cpp\\n  requests=1 cache-miss=1\\n  latency first p50=0.63\\n  blocked-reasons: none\\n\"\n}\n")
    (rc/test-calibration-fill-summary "2026-05-20" "cpp" "diverge-and-restore")
    (let ((text (with-temp-buffer
                  (insert-file-contents
                   (expand-file-name "summary-cpp-diverge-and-restore.md" run-dir))
                  (buffer-string))))
      (should (string-match-p "diverge-restore evidence: `restore-available=yes divergence=1 restored=yes visible-after-restore=yes`" text))
      (should (string-match-p "Common Scenario D divergence / restore: `未覆盖`" text))
      (should (string-match-p "diverged(1) -> restore(ok)" text))
      (should (string-match-p "diverge 后 restore 仍可用，且 delete 后成功恢复" text)))))

(ert-deftest rc/test-calibration-fill-summary-renders-coordination-fields ()
  :tags '(domain/meta risk/coordination prio/2)
  (let* ((history-root (make-temp-file "ai-cal-fill-coordination-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (run-dir (expand-file-name "2026-05-20" history-root))
         (trace-file (expand-file-name "trace-cpp-coordination-001.json" run-dir)))
    (rc/test--write-json-file
     trace-file
     "{\n  \"timestamp\": \"2026-05-20 12:00:00 +0800\",\n  \"language\": \"cpp\",\n  \"scenario\": \"coordination\",\n  \"project\": \"/tmp/cpp/\",\n  \"file\": \"/tmp/cpp/tool_runtime.cpp\",\n  \"major-mode\": \"c++-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"coordination\", \"state\": \"yielded\", \"last-error\": null},\n  \"visible-text\": \"blocked=read-only yield=company request=manual\",\n  \"coordination\": {\"blocked-reason\": \"read-only\", \"yield-target\": \"company\", \"request-source\": \"manual\", \"company-aborted\": true},\n  \"stats-report\": \"AI Complete Stats: tool_runtime.cpp\\n  requests=0 cache-miss=0\\n  blocked-reasons: none\\n  latency first p50=0.00\\n\"\n}\n")
    (rc/test-calibration-fill-summary "2026-05-20" "cpp" "coordination")
    (let ((text (with-temp-buffer
                  (insert-file-contents
                   (expand-file-name "summary-cpp-coordination.md" run-dir))
                  (buffer-string))))
      (should (string-match-p "coordination evidence: `blocked=read-only yield=company request=manual aborted=yes`" text))
      (should (string-match-p "Common Scenario F coordination / yield: `已覆盖；已验证真实 blocked/yield 协调证据`" text))
      (should (string-match-p "manual-denied(read-only) -> yield(company) -> request(manual)" text))
      (should (string-match-p "coordination 已拿到 blocked=read-only / yield=company / request=manual" text)))))

(ert-deftest rc/test-calibration-fill-summary-renders-specialized-fields ()
  :tags '(domain/meta risk/observability prio/2)
  (let* ((history-root (make-temp-file "ai-cal-fill-specialized-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (run-dir (expand-file-name "2026-05-20" history-root))
         (cpp-trace (expand-file-name "trace-cpp-cpp-tight-loop-001.json" run-dir))
         (ts-trace (expand-file-name "trace-ts-ts-object-literal-001.json" run-dir)))
    (rc/test--write-json-file
     cpp-trace
     "{\n  \"timestamp\": \"2026-05-20 20:38:24 +0800\",\n  \"language\": \"cpp\",\n  \"scenario\": \"cpp-tight-loop\",\n  \"project\": \"/tmp/cpp/\",\n  \"file\": \"/tmp/cpp/tool_runtime.cpp\",\n  \"major-mode\": \"c++-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"best = value;\",\n  \"stats-report\": \"requests=1 cache-miss=1\\nblocked-reasons: none\\nlatency first p50=2.14\\n\"\n}\n")
    (rc/test--write-json-file
     ts-trace
     "{\n  \"timestamp\": \"2026-05-20 20:38:30 +0800\",\n  \"language\": \"ts\",\n  \"scenario\": \"ts-object-literal\",\n  \"project\": \"/tmp/ts/\",\n  \"file\": \"/tmp/ts/WebFetchTool.ts\",\n  \"major-mode\": \"js-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"'User-Agent': 'Claude/1.0',\",\n  \"stats-report\": \"requests=1 cache-miss=1\\nblocked-reasons: none\\nlatency first p50=1.25\\n\"\n}\n")
    (rc/test-calibration-fill-summary "2026-05-20" "cpp" "cpp-tight-loop")
    (rc/test-calibration-fill-summary "2026-05-20" "ts" "ts-object-literal")
    (let ((cpp-text (with-temp-buffer
                      (insert-file-contents
                       (expand-file-name "summary-cpp-cpp-tight-loop.md" run-dir))
                      (buffer-string)))
          (ts-text (with-temp-buffer
                     (insert-file-contents
                      (expand-file-name "summary-ts-ts-object-literal.md" run-dir))
                     (buffer-string))))
      (should (string-match-p "Language-specialized scenario: `已覆盖；紧凑循环块续写已拿到真实 visible evidence`" cpp-text))
      (should (string-match-p "紧凑循环块的真实续写已打通" cpp-text))
      (should (string-match-p "Language-specialized scenario: `已覆盖；object literal 续写链路已通，但仍处于 js-mode fallback`" ts-text))
      (should (string-match-p "object literal 的真实续写已打通" ts-text)))))

(ert-deftest rc/test-calibration-fill-summary-preserves-manual-notes ()
  :tags '(domain/meta risk/source-consistency prio/2)
  (let* ((history-root (make-temp-file "ai-cal-fill-preserve-" t))
         (template-root (make-temp-file "ai-cal-fill-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (run-dir (expand-file-name "2026-05-20" history-root))
         (trace-file (expand-file-name "trace-python-line-end-continuation-001.json" run-dir))
         (summary-file (expand-file-name "summary-python-line-end-continuation.md" run-dir)))
    (with-temp-file (expand-file-name "language-run-summary.md" template-root)
      (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nold-auto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- 最大问题: keep-me\n"))
    (rc/test--write-json-file
     trace-file
     "{\n  \"timestamp\": \"2026-05-20 09:00:00 +0800\",\n  \"language\": \"python\",\n  \"scenario\": \"line-end-continuation\",\n  \"project\": \"/tmp/python/\",\n  \"file\": \"/tmp/python/runtime.py\",\n  \"major-mode\": \"python-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"total += len(item)\",\n  \"stats-report\": \"requests=1 cache-miss=1\\nblocked-reasons: none\\nlatency first p50=0.88\\n\"\n}\n")
    (with-temp-file summary-file
      (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nold-auto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- 最大问题: keep-me\n"))
    (rc/test-calibration-fill-summary "2026-05-20" "python" "line-end-continuation")
    (let ((text (with-temp-buffer
                  (insert-file-contents summary-file)
                  (buffer-string))))
      (should (string-match-p "最大问题: keep-me" text))
      (should-not (string-match-p "old-auto" text))
      (should (string-match-p "visible text: `total \\+= len(item)`" text)))))

(ert-deftest rc/test-calibration-fill-summary-migrates-legacy-file-into-auto-manual-layout ()
  :tags '(domain/meta risk/source-consistency prio/2)
  (let* ((history-root (make-temp-file "ai-cal-legacy-" t))
         (template-root (make-temp-file "ai-cal-legacy-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (run-dir (expand-file-name "2026-05-20" history-root))
         (trace-file (expand-file-name "trace-cpp-general-001.json" run-dir))
         (summary-file (expand-file-name "summary-cpp-general.md" run-dir)))
    (with-temp-file (expand-file-name "language-run-summary.md" template-root)
      (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nplaceholder\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- 最大问题:\n\n## Final Judgment\n\n- 建议新增测试:\n"))
    (rc/test--write-json-file
     trace-file
     "{\n  \"timestamp\": \"2026-05-20 09:00:00 +0800\",\n  \"language\": \"cpp\",\n  \"scenario\": \"general\",\n  \"project\": \"/tmp/cpp/\",\n  \"file\": \"/tmp/cpp/tool_runtime.cpp\",\n  \"major-mode\": \"c++-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"total += std::stoi(item);\",\n  \"stats-report\": \"requests=1 cache-miss=1\\nblocked-reasons: none\\nlatency first p50=0.91\\n\"\n}\n")
    (with-temp-file summary-file
      (insert "# Calibration Run\n\n- 日期: old\n\n## Manual Follow-up\n\n- 建议新增测试: keep-me\n"))
    (rc/test-calibration-fill-summary "2026-05-20" "cpp" "general")
    (let ((text (with-temp-buffer
                  (insert-file-contents summary-file)
                  (buffer-string))))
      (should (string-match-p "<!-- AUTO:BEGIN -->" text))
      (should (string-match-p "场景: `general`" text))
      (should (string-match-p "建议新增测试: keep-me" text)))))

(ert-deftest rc/test-calibration-fill-wave-index-renders_status_table ()
  :tags '(domain/meta risk/observability prio/2)
  (let* ((history-root (make-temp-file "ai-cal-index-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (run-dir (expand-file-name "2026-05-20" history-root)))
    (dolist (pair '(("cpp" "c++-ts-mode")
                    ("python" "python-ts-mode")
                    ("rust" "rust-mode")
                    ("ts" "js-mode")
                    ("elisp" "emacs-lisp-mode")))
      (rc/test--write-json-file
       (expand-file-name (format "trace-%s-line-end-continuation-001.json" (car pair)) run-dir)
       (format "{\n  \"timestamp\": \"2026-05-19 15:16:36 +0800\",\n  \"language\": \"%s\",\n  \"scenario\": \"line-end-continuation\",\n  \"project\": \"/tmp/%s/\",\n  \"file\": \"/tmp/%s/file\",\n  \"major-mode\": \"%s\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"ok\",\n  \"stats-report\": \"requests=1 cache-miss=1\\nblocked-reasons: none\\n\"\n}\n"
               (car pair) (car pair) (car pair) (cadr pair))))
    (rc/test--write-json-file
     (expand-file-name "trace-cpp-cache-revisit-001.json" run-dir)
     "{\n  \"timestamp\": \"2026-05-20 10:00:00 +0800\",\n  \"language\": \"cpp\",\n  \"scenario\": \"cache-revisit\",\n  \"project\": \"/tmp/cpp/\",\n  \"file\": \"/tmp/cpp/file\",\n  \"major-mode\": \"c++-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"ok\",\n  \"cache-revisit\": {\"revisit-success\": true, \"second-request-source\": \"cache\", \"second-cache-hit-kind\": \"exact\", \"second-display-phase\": \"visible\"},\n  \"stats-report\": \"requests=1 cache-miss=1\\nblocked-reasons: none\\n\"\n}\n")
    (rc/test--write-json-file
     (expand-file-name "trace-cpp-diverge-and-restore-001.json" run-dir)
     "{\n  \"timestamp\": \"2026-05-20 11:00:00 +0800\",\n  \"language\": \"cpp\",\n  \"scenario\": \"diverge-and-restore\",\n  \"project\": \"/tmp/cpp/\",\n  \"file\": \"/tmp/cpp/file\",\n  \"major-mode\": \"c++-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"ok\",\n  \"diverge-restore\": {\"restore-available-during\": true, \"divergence-distance\": 1, \"restored-event\": true, \"visible-after-restore\": true, \"restore-success\": true},\n  \"stats-report\": \"requests=1 cache-miss=1\\nblocked-reasons: none\\n\"\n}\n")
    (rc/test--write-json-file
     (expand-file-name "trace-cpp-coordination-001.json" run-dir)
     "{\n  \"timestamp\": \"2026-05-20 12:00:00 +0800\",\n  \"language\": \"cpp\",\n  \"scenario\": \"coordination\",\n  \"project\": \"/tmp/cpp/\",\n  \"file\": \"/tmp/cpp/file\",\n  \"major-mode\": \"c++-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"coordination\", \"state\": \"yielded\", \"last-error\": null},\n  \"visible-text\": \"blocked=read-only yield=company request=manual\",\n  \"coordination\": {\"blocked-reason\": \"read-only\", \"yield-target\": \"company\", \"request-source\": \"manual\", \"company-aborted\": true},\n  \"stats-report\": \"requests=0 cache-miss=0\\nblocked-reasons: none\\n\"\n}\n")
    (with-temp-file (expand-file-name "summary-cpp-cpp-tight-loop.md" run-dir)
      (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- manual-status: completed\n- manual-updated-at: 2026-05-20\n- 真实运行时长(分钟): 32\n"))
    (with-temp-file (expand-file-name "summary-python-python-indent-block.md" run-dir)
      (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- manual-status: partial\n- manual-updated-at: 2026-05-20\n- 真实运行时长(分钟): 18\n"))
    (rc/test-calibration-fill-wave-index "2026-05-20" "phase-07-wave-02")
    (let ((text (with-temp-buffer
                  (insert-file-contents
                   (expand-file-name "phase-07-wave-02-index.md" run-dir))
                  (buffer-string))))
      (should (string-match-p "manual calibration 1/5 completed / partial=1 / pending=3" text))
      (should (string-match-p "scripted-visible-js-mode" text))
      (should (string-match-p "line-end-continuation" text))
      (should (string-match-p "| `cache-revisit` | cache/stale 是否真有帮助 | scripted-visible | scaffold-only | scaffold-only | scaffold-only | scaffold-only |" text))
      (should (string-match-p "| `diverge-and-restore` | 兼容输入 / 回退 / restore 是否平滑 | scripted-visible | scaffold-only | scaffold-only | scaffold-only | scaffold-only |" text))
      (should (string-match-p "| `coordination` | company/yas/CAPF 等协调是否清晰 | scripted-coordination | scaffold-only | scaffold-only | scaffold-only | scaffold-only |" text))
      (should (string-match-p "| `cpp` | `cpp-tight-loop` | 紧凑循环 / 块间空行 / 工程风继承 | manual-completed | 人工校准已完成；runtime=32min；updated=2026-05-20 |" text))
      (should (string-match-p "| `python` | `python-indent-block` | 缩进块 / 续写 / 空行 | manual-partial | 人工校准进行中；runtime=18min；updated=2026-05-20 |" text))
      (should (string-match-p "`ts` 当前 fallback: `yes`" text))
      (should (string-match-p "<!-- AUTO:END -->" text)))))

(ert-deftest rc/test-calibration-fill-weekly-summary-highlights_timeout_or_fallback ()
  :tags '(domain/meta risk/observability prio/2)
  (let* ((history-root (make-temp-file "ai-cal-weekly-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (run-dir (expand-file-name "2026-05-20" history-root)))
    (rc/test--write-json-file
     (expand-file-name "trace-ts-line-end-continuation-001.json" run-dir)
     "{\n  \"timestamp\": \"2026-05-19 15:16:50 +0800\",\n  \"language\": \"ts\",\n  \"scenario\": \"line-end-continuation\",\n  \"project\": \"/tmp/ts/\",\n  \"file\": \"/tmp/ts/file.ts\",\n  \"major-mode\": \"js-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"ok\",\n  \"stats-report\": \"requests=1 cache-miss=1\\nblocked-reasons: none\\n\"\n}\n")
    (rc/test-calibration-fill-weekly-summary "2026-05-20")
    (let ((text (with-temp-buffer
                  (insert-file-contents
                   (expand-file-name "weekly-summary.md" run-dir))
                  (buffer-string))))
      (should (string-match-p "TypeScript：当前仍走 js-mode fallback" text))
      (should (string-match-p "deepseek-chat" text)))))

(ert-deftest rc/test-calibration-fill-weekly-summary-highlights-cache-revisit ()
  :tags '(domain/meta risk/cache-hit prio/2)
  (let* ((history-root (make-temp-file "ai-cal-weekly-cache-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (run-dir (expand-file-name "2026-05-20" history-root)))
    (rc/test--write-json-file
     (expand-file-name "trace-cpp-cache-revisit-001.json" run-dir)
     "{\n  \"timestamp\": \"2026-05-20 10:00:00 +0800\",\n  \"language\": \"cpp\",\n  \"scenario\": \"cache-revisit\",\n  \"project\": \"/tmp/cpp/\",\n  \"file\": \"/tmp/cpp/file.cpp\",\n  \"major-mode\": \"c++-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"ok\",\n  \"cache-revisit\": {\"revisit-success\": true, \"second-request-source\": \"cache\", \"second-cache-hit-kind\": \"exact\", \"second-display-phase\": \"visible\"},\n  \"stats-report\": \"requests=1 cache-miss=1\\nblocked-reasons: none\\n\"\n}\n")
    (rc/test--write-json-file
     (expand-file-name "trace-cpp-coordination-001.json" run-dir)
     "{\n  \"timestamp\": \"2026-05-20 12:00:00 +0800\",\n  \"language\": \"cpp\",\n  \"scenario\": \"coordination\",\n  \"project\": \"/tmp/cpp/\",\n  \"file\": \"/tmp/cpp/file.cpp\",\n  \"major-mode\": \"c++-ts-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"coordination\", \"state\": \"yielded\", \"last-error\": null},\n  \"visible-text\": \"blocked=read-only yield=company request=manual\",\n  \"coordination\": {\"blocked-reason\": \"read-only\", \"yield-target\": \"company\", \"request-source\": \"manual\", \"company-aborted\": true},\n  \"stats-report\": \"requests=0 cache-miss=0\\nblocked-reasons: none\\n\"\n}\n")
    (with-temp-file (expand-file-name "summary-cpp-cpp-tight-loop.md" run-dir)
      (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- manual-status: completed\n"))
    (with-temp-file (expand-file-name "summary-rust-rust-borrowish-block.md" run-dir)
      (insert "# Calibration Run\n\n<!-- AUTO:BEGIN -->\nauto\n<!-- AUTO:END -->\n\n## Manual Calibration\n\n- manual-status: partial\n"))
    (rc/test-calibration-fill-weekly-summary "2026-05-20")
    (let ((text (with-temp-buffer
                  (insert-file-contents
                   (expand-file-name "weekly-summary.md" run-dir))
                  (buffer-string))))
      (should (string-match-p "最清晰的 coordination 证据: `cpp：已拿到 blocked/yield 证据，但仍缺人工误伤率判断。`" text))
      (should (string-match-p "cpp：已看到二次触发直接走 cache，但 stale/prefix 还没覆盖。" text))
      (should (string-match-p "manual calibration 进度: `1/5 specialized scenario completed，partial=rust`" text))
      (should (string-match-p "manual calibration pending: `python / ts / elisp`" text)))))

(ert-deftest rc/test-calibration-fill-weekly-summary-preserves-manual-notes ()
  :tags '(domain/meta risk/source-consistency prio/2)
  (let* ((history-root (make-temp-file "ai-cal-weekly-preserve-" t))
         (template-root (make-temp-file "ai-cal-weekly-template-" t))
         (rc/test-calibration-history-root (file-name-as-directory history-root))
         (rc/test-calibration-template-dir (file-name-as-directory template-root))
         (run-dir (expand-file-name "2026-05-20" history-root))
         (weekly-file (expand-file-name "weekly-summary.md" run-dir)))
    (with-temp-file (expand-file-name "weekly-summary.md" template-root)
      (insert "# Weekly Calibration Summary\n\n<!-- AUTO:BEGIN -->\nold-auto\n<!-- AUTO:END -->\n\n## Manual Notes\n\n- 本周主观体验结论: keep-me\n"))
    (rc/test--write-json-file
     (expand-file-name "trace-ts-line-end-continuation-001.json" run-dir)
     "{\n  \"timestamp\": \"2026-05-19 15:16:50 +0800\",\n  \"language\": \"ts\",\n  \"scenario\": \"line-end-continuation\",\n  \"project\": \"/tmp/ts/\",\n  \"file\": \"/tmp/ts/file.ts\",\n  \"major-mode\": \"js-mode\",\n  \"backend\": \"#s(gptel-deepseek)\",\n  \"model\": \"deepseek-chat\",\n  \"settled\": {\"reason\": \"visible\", \"state\": \"visible\", \"last-error\": null},\n  \"visible-text\": \"ok\",\n  \"stats-report\": \"requests=1 cache-miss=1\\nblocked-reasons: none\\n\"\n}\n")
    (with-temp-file weekly-file
      (insert "# Weekly Calibration Summary\n\n<!-- AUTO:BEGIN -->\nold-auto\n<!-- AUTO:END -->\n\n## Manual Notes\n\n- 本周主观体验结论: keep-me\n"))
    (rc/test-calibration-fill-weekly-summary "2026-05-20")
    (let ((text (with-temp-buffer
                  (insert-file-contents weekly-file)
                  (buffer-string))))
      (should (string-match-p "本周主观体验结论: keep-me" text))
      (should-not (string-match-p "old-auto" text))
      (should (string-match-p "TypeScript：当前仍走 js-mode fallback" text)))))

(provide 'ai-calibration-summarizer-test)
;;; ai-calibration-summarizer-test.el ends here
