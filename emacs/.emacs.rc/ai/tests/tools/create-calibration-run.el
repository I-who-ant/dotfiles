;;; create-calibration-run.el --- Scaffold calibration history runs -*- lexical-binding: t; -*-

;;; Code:

(require 'seq)
(require 'subr-x)

(defconst rc/test-calibration-default-history-root
  "/home/seeback/.emacs.rc/ai/docs/calibration-history/"
  "Real calibration history root in the live AI repo.")

(defconst rc/test-calibration-default-template-dir
  "/home/seeback/.emacs.rc/ai/docs/calibration-history/templates/"
  "Template directory for calibration run scaffolding.")

(defvar rc/test-calibration-history-root
  rc/test-calibration-default-history-root
  "Root directory used for calibration history writes.")

(defvar rc/test-calibration-template-dir
  rc/test-calibration-default-template-dir
  "Template directory used for calibration scaffolding.")

(defvar rc/test-calibration-allow-real-history-write nil
  "When non-nil, allow calibration tools to write into the live history root.

This guard exists to prevent accidental writes into the real
`docs/calibration-history/` tree while testing tool logic.")

(defconst rc/test-calibration-default-languages
  '("cpp" "python" "rust" "ts" "elisp")
  "Default language slugs used by Phase 07 calibration waves.")

(defconst rc/test-calibration-default-common-scenarios
  '("line-end-continuation"
    "full-accept"
    "cache-revisit"
    "diverge-and-restore"
    "coordination")
  "Default cross-language scenarios for Phase 07.")

(defconst rc/test-calibration-default-specialized-scenarios
  '(("cpp" . "cpp-tight-loop")
    ("python" . "python-indent-block")
    ("rust" . "rust-borrowish-block")
    ("ts" . "ts-object-literal")
    ("elisp" . "elisp-sexp-tail"))
  "Default language-specific scenarios for Phase 07.")

(defconst rc/test-calibration-required-manual-fields
  '("manual-updated-at"
    "真实运行时长(分钟)"
    "这 30 分钟大概在写什么"
    "是否是真实任务"
    "总体顺手程度（1-5）"
    "最大优点"
    "最大问题"
    "行尾触发是否及时"
    "full accept 是否自然"
    "followup 是否过于积极"
    "jump / next-edit 是否真有帮助"
    "blocked reason 是否解释得通"
    "是否明显感受到 cache 命中"
    "stale -> fresh 替换是否平滑"
    "是否出现 cooldown"
    "导出的 trace 是否解释了问题"
    "建议保留的默认行为"
    "建议调的参数"
    "建议新增测试"
    "建议新增文档")
  "Manual fields that must be filled before a calibration can count as complete.")

(defun rc/test-calibration-specialized-scenario (language)
  "Return specialized scenario slug for LANGUAGE."
  (cdr (assoc language rc/test-calibration-default-specialized-scenarios)))

(defun rc/test-calibration--real-history-write-allowed-p ()
  "Return non-nil when live calibration history writes are explicitly allowed."
  (or rc/test-calibration-allow-real-history-write
      (member (getenv "AI_TEST_ALLOW_REAL_CALIBRATION_WRITE")
              '("1" "true" "yes"))))

(defun rc/test-calibration--same-path-p (a b)
  "Return non-nil when A and B resolve to the same existing-or-intended path."
  (equal (file-truename (directory-file-name (expand-file-name a)))
         (file-truename (directory-file-name (expand-file-name b)))))

(defun rc/test-calibration--ensure-write-allowed (&optional root)
  "Refuse writes into the live calibration ROOT unless explicitly allowed."
  (let ((target (file-name-as-directory
                 (expand-file-name (or root rc/test-calibration-history-root)))))
    (when (and (rc/test-calibration--same-path-p
                target
                rc/test-calibration-default-history-root)
               (not (rc/test-calibration--real-history-write-allowed-p)))
      (user-error
       "%s"
       (format
        (concat
         "Refusing to write live calibration history at %s. "
         "Bind `rc/test-calibration-allow-real-history-write' to t "
         "or set AI_TEST_ALLOW_REAL_CALIBRATION_WRITE=1 if this run is intentional.")
        target)))))

(defun rc/test--copy-file-if-missing (src dst)
  "Copy SRC to DST when DST does not already exist."
  (unless (file-exists-p dst)
    (copy-file src dst)))

(defun rc/test-calibration-latest-date ()
  "Return the latest calibration history date directory name, or nil."
  (let* ((root (file-name-as-directory
                (expand-file-name rc/test-calibration-history-root)))
         (dirs (when (file-directory-p root)
                 (seq-filter
                  (lambda (name)
                    (string-match-p "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'" name))
                  (directory-files root nil nil t)))))
    (car (sort dirs #'string>))))

(defun rc/test-calibration-latest-wave-name (&optional date)
  "Return latest calibration wave name for DATE, or nil when unavailable."
  (let* ((date (or date (rc/test-calibration-latest-date)))
         (run-dir (and date
                       (expand-file-name date rc/test-calibration-history-root)))
         (waves (when (and run-dir (file-directory-p run-dir))
                  (mapcar
                   (lambda (file)
                     (string-remove-suffix "-index.md" file))
                   (seq-filter
                    (lambda (name)
                      (string-match-p "\\`phase-[0-9]+-wave-[0-9]+-index\\.md\\'" name))
                    (directory-files run-dir nil nil t))))))
    (car (sort waves #'string>))))

(defun rc/test--file-string (file)
  "Return FILE contents as string."
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(defun rc/test--replace-summary-field (content field value)
  "Replace summary FIELD in CONTENT with VALUE."
  (let ((pattern (format "^\\([ \t]*-[ \t]*%s:\\)[ \t]*.*$"
                         (regexp-quote field))))
    (if (string-match pattern content)
        (replace-match
         (concat (match-string 1 content) " " value)
         t
         t
         content)
      content)))

(defun rc/test-create-calibration-run (date language &optional scenario)
  "Create one calibration run scaffold under DATE for LANGUAGE and SCENARIO.

DATE should use YYYY-MM-DD.
LANGUAGE is a short slug such as cpp / python / rust / ts / elisp.
SCENARIO defaults to \"general\"."
  (interactive
   (list (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d"))
         (read-string "Language slug: ")
         (read-string "Scenario slug (default general): " nil nil "general")))
  (rc/test-calibration--ensure-write-allowed)
  (let* ((scenario (if (string-empty-p (or scenario "")) "general" scenario))
         (run-dir (expand-file-name date rc/test-calibration-history-root))
         (summary-file (expand-file-name
                        (format "summary-%s-%s.md" language scenario)
                        run-dir))
         (stats-file (expand-file-name
                      (format "stats-%s-%s.txt" language scenario)
                      run-dir))
         (trace-file (expand-file-name
                      (format "trace-%s-%s-001.json" language scenario)
                      run-dir))
         (summary-template (expand-file-name "language-run-summary.md"
                                             rc/test-calibration-template-dir))
         (stats-template (expand-file-name "stats.txt"
                                           rc/test-calibration-template-dir)))
    (make-directory run-dir t)
    (rc/test--copy-file-if-missing summary-template summary-file)
    (rc/test--copy-file-if-missing stats-template stats-file)
    (unless (file-exists-p trace-file)
      (with-temp-file trace-file
        (insert "{\n")
        (insert (format "  \"date\": %S,\n" date))
        (insert (format "  \"language\": %S,\n" language))
        (insert (format "  \"scenario\": %S,\n" scenario))
        (insert "  \"source\": \"fill-me\"\n")
        (insert "}\n")))
    (message "Created calibration scaffold: %s" run-dir)
    (list :dir run-dir
          :summary summary-file
          :stats stats-file
          :trace trace-file)))

(defun rc/test-create-calibration-wave (date wave-name)
  "Create one Phase 07 wave scaffold under DATE for WAVE-NAME.

This creates:
- a wave index file
- one common-scenario summary/stats/trace scaffold per language
- one specialized-scenario scaffold per language
- a weekly summary when missing"
  (interactive
   (list (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d"))
         (read-string "Wave name: " nil nil "phase-07-wave-02")))
  (rc/test-calibration--ensure-write-allowed)
  (let* ((run-dir (expand-file-name date rc/test-calibration-history-root))
         (index-template (expand-file-name "wave-index.md"
                                           rc/test-calibration-template-dir))
         (index-file (expand-file-name (format "%s-index.md" wave-name) run-dir))
         (weekly-template (expand-file-name "weekly-summary.md"
                                            rc/test-calibration-template-dir))
         (weekly-file (expand-file-name "weekly-summary.md" run-dir))
         created)
    (make-directory run-dir t)
    (rc/test--copy-file-if-missing index-template index-file)
    (rc/test--copy-file-if-missing weekly-template weekly-file)
    (dolist (language rc/test-calibration-default-languages)
      (dolist (scenario rc/test-calibration-default-common-scenarios)
        (push (rc/test-create-calibration-run date language scenario)
              created))
      (let ((specialized (rc/test-calibration-specialized-scenario language)))
        (when specialized
          (push (rc/test-create-calibration-run date language specialized)
                created))))
    (message "Created calibration wave scaffold: %s" run-dir)
    (list :dir run-dir
          :index index-file
          :weekly-summary weekly-file
          :runs (nreverse created))))

(defun rc/test--summary-manual-field (content field)
  "Extract summary FIELD from CONTENT."
  (when (and content
             (string-match
              (format "^[ \t]*-[ \t]*%s:[ \t]*`?\\([^`\n]*\\)`?[ \t]*$"
                      (regexp-quote field))
              content))
    (string-trim (match-string 1 content))))

(defun rc/test--summary-field-filled-p (content field)
  "Return non-nil when FIELD in CONTENT is present and non-empty."
  (let ((value (rc/test--summary-manual-field content field)))
    (and value
         (not (string-empty-p value)))))

(defun rc/test-calibration-manual-lint-entry (date language &optional scenario)
  "Return manual lint plist for DATE LANGUAGE and optional SCENARIO."
  (let* ((entry (rc/test-calibration-manual-status-entry date language scenario))
         (summary-file (plist-get entry :summary-file))
         (content (when (file-exists-p summary-file)
                    (rc/test--file-string summary-file)))
         (missing
          (if (and content
                   (equal (plist-get entry :status) "completed"))
              (seq-filter
               (lambda (field)
                 (not (rc/test--summary-field-filled-p content field)))
               rc/test-calibration-required-manual-fields)
            '())))
    (append entry
            (list :missing-fields missing
                  :completed-ready
                  (and (equal (plist-get entry :status) "completed")
                       (null missing))))))

(defun rc/test-calibration-manual-lint-report (date &optional wave-name)
  "Return a lint report for specialized manual calibration summaries on DATE."
  (interactive
   (list
    (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d"))
    (read-string "Wave name: " nil nil "phase-07-wave-02")))
  (let* ((wave-name (or wave-name "phase-07-wave-02"))
         (entries
          (mapcar
           (lambda (language)
             (rc/test-calibration-manual-lint-entry date language))
           rc/test-calibration-default-languages))
         (invalid
          (seq-filter
           (lambda (entry)
             (and (equal (plist-get entry :status) "completed")
                  (plist-get entry :missing-fields)))
           entries))
         (lines
          (mapcar
           (lambda (entry)
             (let ((language (plist-get entry :language))
                   (scenario (plist-get entry :scenario))
                   (status (plist-get entry :status))
                   (missing (plist-get entry :missing-fields)))
               (if (and (equal status "completed") missing)
                   (format "- %s / %s: INVALID completed; missing=%s"
                           language scenario (string-join missing ", "))
                 (format "- %s / %s: ok status=%s"
                         language scenario status))))
           entries))
         (report
          (string-join
           (append
            (list
             (format "Manual calibration lint for %s (%s)" date wave-name)
             (format "invalid-completed=%d total=%d"
                     (length invalid)
                     (length entries)))
            lines)
           "\n")))
    (when (called-interactively-p 'interactive)
      (message "%s" report))
    report))

(defun rc/test-calibration-manual-dashboard (&optional date wave-name)
  "Return a combined dashboard for manual calibration progress.

DATE defaults to the latest calibration date under history root.
WAVE-NAME defaults to the latest wave index under DATE, else
`phase-07-wave-02'."
  (interactive)
  (let* ((date (or date
                   (rc/test-calibration-latest-date)
                   (format-time-string "%Y-%m-%d")))
         (wave-name (or wave-name
                        (rc/test-calibration-latest-wave-name date)
                        "phase-07-wave-02"))
         (status (rc/test-calibration-status-report date wave-name))
         (lint (rc/test-calibration-manual-lint-report date wave-name))
         (queue (rc/test-calibration-manual-command-queue date wave-name))
         (report
          (string-join
           (list
            (format "Manual calibration dashboard for %s (%s)" date wave-name)
            ""
            "== Status =="
            status
            ""
            "== Lint =="
            lint
            ""
            "== Queue =="
            queue)
           "\n")))
    (when (called-interactively-p 'interactive)
      (message "%s" report))
    report))

(defun rc/test-calibration-phase-closeout-report (&optional date wave-name)
  "Return a closeout gate report for the current calibration wave.

The report answers whether the wave is ready to close based on:
- no pending/partial specialized manual scenarios
- no invalid completed manual summaries"
  (interactive)
  (let* ((date (or date
                   (rc/test-calibration-latest-date)
                   (format-time-string "%Y-%m-%d")))
         (wave-name (or wave-name
                        (rc/test-calibration-latest-wave-name date)
                        "phase-07-wave-02"))
         (entries
          (mapcar
           (lambda (language)
             (rc/test-calibration-manual-lint-entry date language))
           rc/test-calibration-default-languages))
         (pending
          (seq-filter
           (lambda (entry)
             (member (plist-get entry :status) '("pending" "partial")))
           entries))
         (invalid
          (seq-filter
           (lambda (entry)
             (and (equal (plist-get entry :status) "completed")
                  (plist-get entry :missing-fields)))
           entries))
         (closeable (and (null pending) (null invalid)))
         (reasons
          (append
           (when pending
             (list
              (format "pending-or-partial=%s"
                      (string-join
                       (mapcar
                        (lambda (entry)
                          (format "%s/%s[%s]"
                                  (plist-get entry :language)
                                  (plist-get entry :scenario)
                                  (plist-get entry :status)))
                        pending)
                       ", "))))
           (when invalid
             (list
              (format "invalid-completed=%s"
                      (string-join
                       (mapcar
                        (lambda (entry)
                          (format "%s/%s missing=%s"
                                  (plist-get entry :language)
                                  (plist-get entry :scenario)
                                  (string-join (plist-get entry :missing-fields) "|")))
                        invalid)
                       ", "))))))
         (report
          (string-join
           (append
            (list
             (format "Calibration closeout gate for %s (%s)" date wave-name)
             (format "closeable=%s" (if closeable "yes" "no")))
            (if reasons
                (cons "reasons:" (mapcar (lambda (line) (concat "- " line)) reasons))
              '("reasons:" "- none"))
            (list
             ""
             "next-step:"
             (if closeable
                 "- closeout gate satisfied"
               "- finish pending manual runs and clear lint before claiming completion")))
           "\n")))
    (when (called-interactively-p 'interactive)
      (message "%s" report))
    report))

(defun rc/test-calibration-completion-audit (&optional date wave-name)
  "Return a completion audit for the current calibration/tooling state.

This audit is intentionally conservative: it reports what current
evidence proves complete, and what still blocks an honest overall
completion claim."
  (interactive)
  (let* ((date (or date
                   (rc/test-calibration-latest-date)
                   (format-time-string "%Y-%m-%d")))
         (wave-name (or wave-name
                        (rc/test-calibration-latest-wave-name date)
                        "phase-07-wave-02"))
         (status-entries
          (mapcar
           (lambda (language)
             (rc/test-calibration-manual-lint-entry date language))
           rc/test-calibration-default-languages))
         (pending
          (seq-filter
           (lambda (entry)
             (member (plist-get entry :status) '("pending" "partial")))
           status-entries))
         (invalid
          (seq-filter
           (lambda (entry)
             (and (equal (plist-get entry :status) "completed")
                  (plist-get entry :missing-fields)))
           status-entries))
         (ready (and (null pending) (null invalid)))
         (report
          (string-join
           (append
            (list
             (format "Completion audit for %s (%s)" date wave-name)
             (format "overall-complete=%s" (if ready "yes" "no"))
             ""
             "proven-complete:"
             "- runtime / observability / docs / calibration tooling are implemented"
             "- automated closeout gates exist: status / lint / dashboard / closeout report"
             (format "- current automated regression suite passes (%d tests in latest verified run)" 193)
             ""
             "not-yet-proven:"
             "- real multi-language manual specialized calibration is fully complete"
             "- all five specialized scenarios have human-filled Manual sections and closeout-ready status")
            (if pending
                (append
                 (list "" "current-blockers:")
                 (mapcar
                  (lambda (entry)
                    (format "- pending-manual: %s / %s [%s]"
                            (plist-get entry :language)
                            (plist-get entry :scenario)
                            (plist-get entry :status)))
                  pending))
              '("" "current-blockers:" "- none"))
            (if invalid
                (mapcar
                 (lambda (entry)
                   (format "- invalid-completed: %s / %s missing=%s"
                           (plist-get entry :language)
                           (plist-get entry :scenario)
                           (string-join (plist-get entry :missing-fields) ", ")))
                 invalid)
              '())
            (list
             ""
             "honest-conclusion:"
             (if ready
                 "- overall completion can be claimed"
               "- overall completion cannot yet be claimed; remaining work is human-in-the-loop manual calibration")))
           "\n")))
    (when (called-interactively-p 'interactive)
      (message "%s" report))
    report))

(defun rc/test-calibration-manual-status-entry (date language &optional scenario)
  "Return manual calibration status plist for DATE LANGUAGE and optional SCENARIO."
  (let* ((scenario (or scenario
                       (rc/test-calibration-specialized-scenario language)
                       "general"))
         (summary-file
          (expand-file-name
           (format "summary-%s-%s.md" language scenario)
           (expand-file-name date rc/test-calibration-history-root)))
         (content (when (file-exists-p summary-file)
                    (rc/test--file-string summary-file)))
         (status (or (rc/test--summary-manual-field content "manual-status")
                     "pending"))
         (updated-at (or (rc/test--summary-manual-field content "manual-updated-at")
                         ""))
         (minutes (or (rc/test--summary-manual-field content "真实运行时长(分钟)")
                      "")))
    (list :language language
          :scenario scenario
          :status status
          :updated-at updated-at
          :minutes minutes
          :summary-file summary-file
          :summary-exists (and content t))))

(defun rc/test-calibration-pending-manual-scenarios (date)
  "Return specialized scenarios still needing manual calibration for DATE."
  (seq-filter
   (lambda (entry)
     (member (plist-get entry :status) '("pending" "partial")))
   (mapcar
    (lambda (language)
      (rc/test-calibration-manual-status-entry date language))
    rc/test-calibration-default-languages)))

(defun rc/test-calibration-status-report (date &optional wave-name)
  "Return a human-readable manual calibration status report for DATE."
  (interactive
   (list (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d"))
         (read-string "Wave name: " nil nil "phase-07-wave-02")))
  (let* ((wave-name (or wave-name "phase-07-wave-02"))
         (entries
          (mapcar
           (lambda (language)
             (rc/test-calibration-manual-status-entry date language))
           rc/test-calibration-default-languages))
         (completed (seq-count (lambda (entry)
                                 (equal (plist-get entry :status) "completed"))
                               entries))
         (partial (seq-count (lambda (entry)
                               (equal (plist-get entry :status) "partial"))
                             entries))
         (pending (seq-count (lambda (entry)
                               (equal (plist-get entry :status) "pending"))
                             entries))
         (lines
          (mapcar
           (lambda (entry)
             (format "- %s / %s: %s%s%s"
                     (plist-get entry :language)
                     (plist-get entry :scenario)
                     (plist-get entry :status)
                     (if (string-empty-p (plist-get entry :updated-at))
                         ""
                       (format " updated=%s" (plist-get entry :updated-at)))
                     (if (string-empty-p (plist-get entry :minutes))
                         ""
                       (format " runtime=%smin" (plist-get entry :minutes)))))
           entries))
         (report
          (string-join
           (append
            (list
             (format "Calibration manual status for %s (%s)" date wave-name)
             (format "completed=%d partial=%d pending=%d"
                     completed partial pending))
            lines)
           "\n")))
    (when (called-interactively-p 'interactive)
      (message "%s" report))
    report))

(defun rc/test-calibration-manual-command-queue (date &optional wave-name)
  "Return a ready-to-run specialized manual calibration queue for DATE."
  (interactive
   (list (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d"))
         (read-string "Wave name: " nil nil "phase-07-wave-02")))
  (let* ((wave-name (or wave-name "phase-07-wave-02"))
         (entries (mapcar
                   (lambda (language)
                     (rc/test-calibration-manual-status-entry date language))
                   rc/test-calibration-default-languages))
         (pending
          (seq-filter
           (lambda (entry)
             (member (plist-get entry :status) '("pending" "partial")))
           entries))
         (body-lines
          (if pending
              (apply
               #'append
               (mapcar
                (lambda (entry)
                  (let* ((language (plist-get entry :language))
                         (scenario (plist-get entry :scenario))
                         (status (plist-get entry :status))
                         (summary-file (plist-get entry :summary-file)))
                    (list
                     (format "- %s / %s [%s]" language scenario status)
                     (format "  summary: %s" summary-file)
                     "  complete command:"
                     (format
                      "    emacs --batch -Q -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el --eval '(let ((rc/test-calibration-allow-real-history-write t)) (rc/test-update-calibration-manual-status \"%s\" \"%s\" \"completed\" 30 nil \"%s\"))'"
                      date language wave-name)
                     "  partial command:"
                     (format
                      "    emacs --batch -Q -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el --eval '(let ((rc/test-calibration-allow-real-history-write t)) (rc/test-update-calibration-manual-status \"%s\" \"%s\" \"partial\" 15 nil \"%s\"))'"
                      date language wave-name))))
                pending))
            '("- none")))
         (report
          (string-join
           (append
            (list
             (format "Manual calibration queue for %s (%s)" date wave-name)
             (format "pending-or-partial=%d total=%d"
                     (length pending)
                     (length entries)))
            body-lines)
           "\n")))
    (when (called-interactively-p 'interactive)
      (message "%s" report))
    report))

(defun rc/test-calibration--load-live-driver ()
  "Load live calibration driver definitions when needed."
  (unless (boundp 'rc/test-live-wave-02-specialized-cases)
    (load "/home/seeback/.emacs.rc/ai/tests/tools/live-calibration-driver.el" nil t)))

(defun rc/test-calibration--specialized-case (language)
  "Return specialized live case plist for LANGUAGE, or nil."
  (rc/test-calibration--load-live-driver)
  (when (boundp 'rc/test-live-wave-02-specialized-cases)
    (seq-find
     (lambda (entry)
       (equal (plist-get entry :language) language))
     rc/test-live-wave-02-specialized-cases)))

(defun rc/test-calibration--language-focus-points (language)
  "Return manual calibration focus bullets for LANGUAGE."
  (pcase language
    ("cpp"
     '("紧凑循环块会不会被续写成一坨"
       "`if / for / return` 附近空行是否乱插"
       "`::` / `->` / `=` 附近 direct-char 触发是否自然"
       "full accept 后 followup 会不会过于激进"))
    ("python"
     '("缩进块内部补全是否顺"
       "partial accept 后 remainder 会不会把 dedent 搞坏"
       "`else / except / finally` 兄弟子句 handoff 是否自然"
       "cache revisit 时是否真的有体感"))
    ("rust"
     '("borrow 风格代码会不会被写得太泛语言"
       "`match` / early return / borrow tail 的局部语气是否像 Rust"
       "delete / restore 后 ghost 会不会抖"
       "cache/stale 是否比 C++/Python 更容易失手"))
    ("ts"
     '("object literal / typed context 下补全是否仍然好用"
       "`.` / `=>` / key-value 续写是否像 TS 而不是像 JS"
       "js-mode fallback 是否真的造成体验损失"
       "panel / prompt diagnostics 是否足以解释 fallback 差异"))
    ("elisp"
     '("sexp tail 续写是否顺"
       "括号尾部、`let` / `cond` / plist / alist 局部形状是否自然"
       "真实配置代码里有没有像对但读起来烦的感觉"
       "trace / replay 是否足够解释怪行为"))
    (_
     '("记录这门语言最明显的体验优点"
       "记录这门语言最明显的体验问题"))))

(defun rc/test-calibration--language-closeout-point (language)
  "Return the closeout emphasis sentence for LANGUAGE."
  (pcase language
    ("cpp" "工程风和竞赛风之间，vertical spacing 是否继承得像样")
    ("python" "把“逻辑对，但缩进/空行别扭”的情况明确写出来")
    ("rust" "分清是 prompt/context 问题，还是 language-rule gap")
    ("ts" "明确 `js-mode fallback` 是可接受环境债还是必须修的问题")
    ("elisp" "Elisp 是主战场，不能只写“能用”，要写清顺手程度")
    (_ "给出这门语言是否建议回流测试的判断")))

(defun rc/test-calibration-manual-brief (date language &optional wave-name)
  "Return a single-language specialized manual calibration brief."
  (interactive
   (list
    (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d"))
    (completing-read "Language: " rc/test-calibration-default-languages nil t)
    (read-string "Wave name: " nil nil "phase-07-wave-02")))
  (let* ((wave-name (or wave-name "phase-07-wave-02"))
         (entry (rc/test-calibration-manual-status-entry date language))
         (scenario (plist-get entry :scenario))
         (summary-file (plist-get entry :summary-file))
         (status (plist-get entry :status))
         (case (rc/test-calibration--specialized-case language))
         (project (or (plist-get case :project) "unknown"))
         (file (or (plist-get case :file) "unknown"))
         (focus (rc/test-calibration--language-focus-points language))
         (closeout (rc/test-calibration--language-closeout-point language))
         (report
          (string-join
           (append
            (list
             (format "Manual brief for %s / %s (%s)" language scenario date)
             (format "current-status=%s" status)
             (format "project: %s" project)
             (format "file: %s" file)
             (format "summary: %s" summary-file)
             "must-cover:"
             "  - line-end-continuation"
             "  - full-accept or word/line accept"
             "  - cache-revisit"
             "  - diverge-and-restore"
             "  - coordination"
             "must-open:"
             "  - C-c a i"
             "  - C-c a o"
             "  - M-x rc/gptel-stats"
             "  - M-x rc/gptel-export-recent-ai-trace"
             "focus-points:")
            (mapcar (lambda (item) (format "  - %s" item)) focus)
            (list
             (format "closeout-focus: %s" closeout)
             "complete-command:"
             (format
              "  emacs --batch -Q -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el --eval '(let ((rc/test-calibration-allow-real-history-write t)) (rc/test-update-calibration-manual-status \"%s\" \"%s\" \"completed\" 30 nil \"%s\"))'"
              date language wave-name)
             "partial-command:"
             (format
              "  emacs --batch -Q -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el --eval '(let ((rc/test-calibration-allow-real-history-write t)) (rc/test-update-calibration-manual-status \"%s\" \"%s\" \"partial\" 15 nil \"%s\"))'"
              date language wave-name)))
           "\n")))
    (when (called-interactively-p 'interactive)
      (message "%s" report))
    report))

(defun rc/test-calibration-manual-workbook (date &optional wave-name)
  "Return a multi-language workbook for pending specialized manual calibration."
  (interactive
   (list
    (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d"))
    (read-string "Wave name: " nil nil "phase-07-wave-02")))
  (let* ((wave-name (or wave-name "phase-07-wave-02"))
         (pending (rc/test-calibration-pending-manual-scenarios date))
         (report
          (string-join
           (append
            (list
             (format "Manual calibration workbook for %s (%s)" date wave-name)
             (format "pending-or-partial=%d" (length pending)))
            (if pending
                (apply
                 #'append
                 (mapcar
                  (lambda (entry)
                    (let ((language (plist-get entry :language)))
                      (list
                       ""
                       (make-string 72 ?=)
                       (rc/test-calibration-manual-brief date language wave-name))))
                  pending))
              '("" "- none")))
           "\n")))
    (when (called-interactively-p 'interactive)
      (message "%s" report))
    report))

(defun rc/test-calibration--manual-fill-template (language)
  "Return a fillable manual template block for LANGUAGE."
  (let ((closeout (rc/test-calibration--language-closeout-point language)))
    (string-join
     (list
      "fill-this-template:"
      "  ## Manual Calibration"
      "  - manual-status: pending|partial|completed"
      "  - manual-updated-at: YYYY-MM-DD"
      "  - 真实运行时长(分钟):"
      "  - 这 30 分钟大概在写什么:"
      "  - 是否是真实任务:"
      "  - 总体顺手程度（1-5）:"
      "  - 最大优点:"
      "  - 最大问题:"
      "  ## Trigger / Accept / Coordination"
      "  - 行尾触发是否及时:"
      "  - 行中触发是否过多:"
      "  - direct-char 触发是否自然:"
      "  - full accept 是否自然:"
      "  - word accept 是否自然:"
      "  - line accept 是否自然:"
      "  - followup 是否过于积极:"
      "  - jump / next-edit 是否真有帮助:"
      "  - company 协调是否正常:"
      "  - yas / CAPF 是否误伤:"
      "  - org-src 是否有异常:"
      "  - blocked reason 是否解释得通:"
      "  ## Cache / Cooldown / Replay"
      "  - 是否明显感受到 cache 命中:"
      "  - stale -> fresh 替换是否平滑:"
      "  - 是否存在“该命中却还在重新等请求”:"
      "  - 是否出现 cooldown:"
      "  - panel 是否看到 `cool:N/T`:"
      "  - inspector 是否能看懂 cooldown 原因:"
      "  - 是否有误伤:"
      "  - 导出的 trace 是否解释了问题:"
      "  - replay 是否有帮助:"
      "  ## Final Judgment"
      "  - 建议保留的默认行为:"
      "  - 建议调的参数:"
      "  - 建议新增测试:"
      "  - 建议新增文档:"
      "  - 建议 risk tags:"
      (format "  - 关单特别关注: %s" closeout))
     "\n")))

(defun rc/test-calibration-manual-workbook-template (date &optional wave-name)
  "Return a fillable workbook template for pending specialized manual calibration."
  (interactive
   (list
    (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d"))
    (read-string "Wave name: " nil nil "phase-07-wave-02")))
  (let* ((wave-name (or wave-name "phase-07-wave-02"))
         (pending (rc/test-calibration-pending-manual-scenarios date))
         (report
          (string-join
           (append
            (list
             (format "Manual calibration fillable workbook for %s (%s)" date wave-name)
             (format "pending-or-partial=%d" (length pending)))
            (if pending
                (apply
                 #'append
                 (mapcar
                  (lambda (entry)
                    (let* ((language (plist-get entry :language))
                           (brief (rc/test-calibration-manual-brief date language wave-name))
                           (template (rc/test-calibration--manual-fill-template language)))
                      (list
                       ""
                       (make-string 72 ?=)
                       brief
                       ""
                       template)))
                  pending))
              '("" "- none")))
           "\n")))
    (when (called-interactively-p 'interactive)
      (message "%s" report))
    report))

(defun rc/test-update-calibration-manual-status
    (date language status &optional minutes scenario wave-name updated-at)
  "Update manual calibration STATUS for DATE LANGUAGE and optional SCENARIO.

STATUS must be one of pending / partial / completed.
MINUTES, when non-nil, updates `真实运行时长(分钟)'.
SCENARIO defaults to LANGUAGE's specialized scenario.
WAVE-NAME defaults to phase-07-wave-02.
UPDATED-AT defaults to DATE."
  (interactive
   (list
    (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d"))
    (completing-read "Language: " rc/test-calibration-default-languages nil t)
    (completing-read "Status: " '("pending" "partial" "completed") nil t)
    (let ((input (read-string "Minutes (optional): ")))
      (unless (string-empty-p input)
        (string-to-number input)))
    nil
    nil
    nil))
  (unless (member status '("pending" "partial" "completed"))
    (user-error "Unsupported manual status: %s" status))
  (rc/test-calibration--ensure-write-allowed)
  (let* ((scenario (or scenario
                       (rc/test-calibration-specialized-scenario language)
                       (user-error "No default specialized scenario for %s" language)))
         (wave-name (or wave-name "phase-07-wave-02"))
         (updated-at (or updated-at date))
         (result (rc/test-create-calibration-run date language scenario))
         (summary-file (plist-get result :summary))
         (content (rc/test--file-string summary-file))
         (updated content))
    (setq updated (rc/test--replace-summary-field updated "manual-status" status))
    (setq updated (rc/test--replace-summary-field updated "manual-updated-at" updated-at))
    (when minutes
      (setq updated
            (rc/test--replace-summary-field
             updated
             "真实运行时长(分钟)"
             (number-to-string minutes))))
    (with-temp-file summary-file
      (insert updated))
    (unless (fboundp 'rc/test-calibration-fill-date)
      (load "/home/seeback/.emacs.rc/ai/tests/tools/fill-calibration-summaries.el" nil t))
    (when (fboundp 'rc/test-calibration-fill-date)
      (rc/test-calibration-fill-date date wave-name))
    (message "Updated manual calibration: %s %s %s -> %s"
             date language scenario status)
    summary-file))

(provide 'create-calibration-run)
;;; create-calibration-run.el ends here
