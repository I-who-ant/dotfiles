;;; fill-calibration-summaries.el --- Auto-fill calibration markdown from artifacts -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'seq)
(require 'subr-x)

(load "/home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el" nil t)

(defconst rc/test-calibration-wave-default-name
  "phase-07-wave-02"
  "Default wave index name when auto-filling calibration history.")

(defconst rc/test-calibration-fallback-scenarios
  '("line-end-continuation" "general")
  "Preferred scenario order when building rollup summaries.")

(defconst rc/test-calibration-auto-begin-marker
  "<!-- AUTO:BEGIN -->"
  "Marker starting the auto-generated block in calibration markdown.")

(defconst rc/test-calibration-auto-end-marker
  "<!-- AUTO:END -->"
  "Marker ending the auto-generated block in calibration markdown.")

(defconst rc/test-calibration-manual-status-values
  '("pending" "partial" "completed")
  "Allowed manual calibration status values.")

(defun rc/test-calibration--run-dir (date)
  "Return calibration history directory for DATE."
  (expand-file-name date rc/test-calibration-history-root))

(defun rc/test-calibration--summary-file (date language scenario)
  "Return summary file path for DATE LANGUAGE and SCENARIO."
  (expand-file-name
   (format "summary-%s-%s.md" language scenario)
   (rc/test-calibration--run-dir date)))

(defun rc/test-calibration--trace-file (date language scenario)
  "Return trace file path for DATE LANGUAGE and SCENARIO."
  (expand-file-name
   (format "trace-%s-%s-001.json" language scenario)
   (rc/test-calibration--run-dir date)))

(defun rc/test-calibration--weekly-file (date)
  "Return weekly summary path for DATE."
  (expand-file-name "weekly-summary.md" (rc/test-calibration--run-dir date)))

(defun rc/test-calibration--wave-index-file (date wave-name)
  "Return wave index file path for DATE and WAVE-NAME."
  (expand-file-name
   (format "%s-index.md" wave-name)
   (rc/test-calibration--run-dir date)))

(defun rc/test-calibration--template-file (name)
  "Return absolute template file path for NAME."
  (expand-file-name name rc/test-calibration-template-dir))

(defun rc/test-calibration--summary-content (date language scenario)
  "Return summary markdown contents for DATE LANGUAGE and SCENARIO, else nil."
  (let ((file (rc/test-calibration--summary-file date language scenario)))
    (when (file-exists-p file)
      (rc/test-calibration--file-string file))))

(defun rc/test-calibration--json-read-file (file)
  "Read JSON FILE into an alist with string keys."
  (let ((json-object-type 'alist)
        (json-array-type 'list)
        (json-key-type 'string)
        (json-false nil))
    (json-read-file file)))

(defun rc/test-calibration--file-string (file)
  "Return FILE contents as string."
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(defun rc/test-calibration--ensure-template-file (file template-name)
  "Ensure FILE exists, copying TEMPLATE-NAME from template dir when missing."
  (unless (file-exists-p file)
    (make-directory (file-name-directory file) t)
    (copy-file (rc/test-calibration--template-file template-name) file)))

(defun rc/test-calibration--replace-auto-block (content auto-body)
  "Replace AUTO markers in CONTENT with AUTO-BODY.
AUTO-BODY should not include begin/end markers."
  (let ((pattern (format "%s\\([\0-\377[:nonascii:][:multibyte:]]*?\\)%s"
                         (regexp-quote rc/test-calibration-auto-begin-marker)
                         (regexp-quote rc/test-calibration-auto-end-marker))))
    (if (string-match pattern content)
        (replace-match
         (concat rc/test-calibration-auto-begin-marker
                 "\n"
                 (string-trim-right auto-body)
                 "\n"
                 rc/test-calibration-auto-end-marker)
         t t content)
      nil)))

(defun rc/test-calibration--merge-with-template (file template-name auto-body)
  "Return FILE content updated from TEMPLATE-NAME with AUTO-BODY.
When FILE lacks AUTO markers, keep its manual tail when possible and migrate it
onto the current template."
  (let* ((current (and (file-exists-p file)
                       (rc/test-calibration--file-string file)))
         (template (rc/test-calibration--file-string
                    (rc/test-calibration--template-file template-name)))
         (updated-current (and current
                               (rc/test-calibration--replace-auto-block
                                current auto-body))))
    (or updated-current
        (let* ((template-with-auto
                (or (rc/test-calibration--replace-auto-block template auto-body)
                    template))
               (manual-section
                (and current
                     (string-match "\n## \\(Manual\\|Final Judgment\\|Manual Notes\\)[\0-\377[:nonascii:][:multibyte:]]*\\'" current)
                     (match-string 0 current))))
          (if manual-section
              (replace-regexp-in-string
               "\n## \\(Manual Calibration\\|Manual Notes\\)[\0-\377[:nonascii:][:multibyte:]]*\\'"
               manual-section
               template-with-auto
               t t)
            template-with-auto)))))

(defun rc/test-calibration--aget (alist key)
  "Return value from ALIST by string KEY using `equal'."
  (alist-get key alist nil nil #'equal))

(defun rc/test-calibration--nested (obj &rest keys)
  "Traverse OBJ alists by string KEYS."
  (seq-reduce
   (lambda (acc key)
     (and (listp acc)
          (rc/test-calibration--aget acc key)))
   keys
   obj))

(defun rc/test-calibration--trace-artifacts (date)
  "Return parsed trace artifacts for DATE."
  (let* ((run-dir (rc/test-calibration--run-dir date))
         (files (when (file-directory-p run-dir)
                  (directory-files run-dir t "\\`trace-.*-001\\.json\\'"))))
    (delq
     nil
     (mapcar
      (lambda (file)
        (let* ((data (rc/test-calibration--json-read-file file))
               (language (rc/test-calibration--aget data "language"))
               (scenario (rc/test-calibration--aget data "scenario"))
               (timestamp (rc/test-calibration--aget data "timestamp")))
          (when (and language scenario timestamp)
            (list :file file
                  :data data
                  :language language
                  :scenario scenario))))
      files))))

(defun rc/test-calibration--trace-by-language-scenario (date)
  "Return alist mapping (LANGUAGE . SCENARIO) to parsed trace for DATE."
  (mapcar
   (lambda (entry)
     (cons (cons (plist-get entry :language)
                 (plist-get entry :scenario))
           entry))
   (rc/test-calibration--trace-artifacts date)))

(defun rc/test-calibration--lookup-trace (date language scenario)
  "Return parsed trace entry for DATE LANGUAGE and SCENARIO."
  (alist-get (cons language scenario)
             (rc/test-calibration--trace-by-language-scenario date)
             nil nil #'equal))

(defun rc/test-calibration--stats-number (report label)
  "Extract numeric LABEL from stats REPORT."
  (let* ((exact-pattern (format "%s=\\([0-9.]+\\)" (regexp-quote label)))
         (space-pattern
          (format "%s=\\([0-9.]+\\)"
                  (regexp-quote (replace-regexp-in-string "-" " " label))))
         (stats-pattern
          (pcase label
            ("cache-miss" "miss=\\([0-9.]+\\)")
            ("cache-exact" "exact=\\([0-9.]+\\)")
            ("cache-prefix" "prefix=\\([0-9.]+\\)")
            (_ nil))))
    (cond
     ((and report (string-match exact-pattern report))
      (match-string 1 report))
     ((and report (string-match space-pattern report))
      (match-string 1 report))
     ((and report stats-pattern (string-match stats-pattern report))
      (match-string 1 report))
     (t nil))))

(defun rc/test-calibration--blocked-reasons (report)
  "Extract blocked reasons summary from stats REPORT."
  (when (and report (string-match "blocked-reasons: \\(.*\\)" report))
    (string-trim (match-string 1 report))))

(defun rc/test-calibration--settled-status (trace)
  "Return status symbol for TRACE alist."
  (let* ((settled (rc/test-calibration--aget trace "settled"))
         (reason (rc/test-calibration--aget settled "reason"))
         (major-mode-name (rc/test-calibration--aget trace "major-mode"))
         (language (rc/test-calibration--aget trace "language"))
         (last-error (rc/test-calibration--aget settled "last-error")))
    (cond
     ((equal reason "coordination")
      'scripted-coordination)
     ((equal reason "visible")
      (if (and (equal language "ts")
               (equal major-mode-name "js-mode"))
          'scripted-visible-js-mode
        'scripted-visible))
     ((and (equal last-error "timeout")
           (equal (rc/test-calibration--aget settled "state") "failed"))
      'scripted-timeout)
     ((or (equal reason "error")
          (equal (rc/test-calibration--aget settled "state") "failed"))
      'scripted-failed)
     (t 'scripted-other))))

(defun rc/test-calibration--status-string (status)
  "Render STATUS symbol for markdown tables."
  (cond
   ((eq status 'scripted-coordination) "scripted-coordination")
   ((eq status 'scripted-visible) "scripted-visible")
   ((eq status 'scripted-visible-js-mode) "scripted-visible-js-mode")
   ((eq status 'scripted-timeout) "scripted-timeout")
   ((eq status 'scripted-failed) "scripted-failed")
   (t "scripted-other")))

(defun rc/test-calibration--trace-route-summary (trace)
  "Return short lifecycle summary string for TRACE."
  (let* ((status (rc/test-calibration--settled-status trace))
         (scenario (rc/test-calibration--aget trace "scenario"))
         (reason (rc/test-calibration--nested trace "settled" "reason"))
         (error (rc/test-calibration--nested trace "settled" "last-error"))
         (cache-revisit (rc/test-calibration--cache-revisit trace))
         (coordination (rc/test-calibration--coordination trace))
         (diverge-restore (rc/test-calibration--diverge-restore trace)))
    (cond
     ((and (equal scenario "cache-revisit") cache-revisit)
      (format "request-started -> visible -> clear -> revisit(%s/%s)"
              (or (rc/test-calibration--aget cache-revisit "second-request-source") "unknown")
              (or (rc/test-calibration--aget cache-revisit "second-cache-hit-kind") "none")))
     ((and (equal scenario "coordination") coordination)
      (format "manual-denied(%s) -> yield(%s) -> request(%s)"
              (or (rc/test-calibration--aget coordination "blocked-reason") "none")
              (or (rc/test-calibration--aget coordination "yield-target") "none")
              (or (rc/test-calibration--aget coordination "request-source") "none")))
     ((and (equal scenario "diverge-and-restore") diverge-restore)
      (format "request-started -> visible -> diverged(%s) -> restore(%s)"
              (or (rc/test-calibration--aget diverge-restore "divergence-distance") 0)
              (if (rc/test-calibration--aget diverge-restore "restored-event") "ok" "failed")))
     ((memq status '(scripted-visible scripted-visible-js-mode))
      "request-started -> cached -> visible")
     ((eq status 'scripted-timeout)
      (format "request-started -> failed (%s)" (or error "timeout")))
     ((eq status 'scripted-failed)
      (format "request-started -> failed (%s)" (or error reason "unknown")))
     (t "request-started -> settled"))))

(defun rc/test-calibration--best-rollup-entry (date language)
  "Return best available rollup trace entry for DATE and LANGUAGE."
  (seq-some
   (lambda (scenario)
     (rc/test-calibration--lookup-trace date language scenario))
   rc/test-calibration-fallback-scenarios))

(defun rc/test-calibration--scenario-coverage-note (scenario)
  "Return auto-generated coverage note for SCENARIO."
  (cond
   ((equal scenario "line-end-continuation")
    "已覆盖；按 scripted probe 视角拿到结论")
   ((equal scenario "full-accept")
    "已覆盖；按 scripted probe 视角拿到接受后状态")
   ((equal scenario "coordination")
    "已覆盖；已验证协调层 blocked/yield 证据")
   ((member scenario (mapcar #'cdr rc/test-calibration-default-specialized-scenarios))
    "待人工校准；这是语言特化 scenario，重点看局部风格和语言手感")
   ((equal scenario "cache-revisit")
    "已部分覆盖；已验证二次触发 cache revisit，stale/prefix 仍待后续细化")
   ((equal scenario "general")
    "已覆盖；这是综合 scripted probe，后续仍需拆细到具体 common scenario")
   (t
    "未覆盖")))

(defun rc/test-calibration--specialized-coverage-note (trace)
  "Return specialized coverage note for TRACE, or nil when not specialized."
  (let* ((language (rc/test-calibration--aget trace "language"))
         (scenario (rc/test-calibration--aget trace "scenario"))
         (status (rc/test-calibration--settled-status trace)))
    (when (equal scenario (rc/test-calibration-specialized-scenario language))
      (pcase language
        ("cpp"
         "已覆盖；紧凑循环块续写已拿到真实 visible evidence")
        ("python"
         "已覆盖；缩进块内部续写已拿到真实 visible evidence")
        ("rust"
         "已覆盖；borrow 风格块续写已拿到真实 visible evidence")
        ("ts"
         (if (eq status 'scripted-visible-js-mode)
             "已覆盖；object literal 续写链路已通，但仍处于 js-mode fallback"
           "已覆盖；object literal 续写已拿到真实 visible evidence"))
        ("elisp"
         "已覆盖；sexp tail 续写已拿到真实 visible evidence")
        (_
         "已覆盖；语言特化 scenario 已拿到真实 visible evidence")))))

(defun rc/test-calibration--extract-manual-field (content field)
  "Extract FIELD value from summary CONTENT."
  (when (and content
             (string-match
              (format "^[ \t]*-[ \t]*%s:[ \t]*`?\\([^`\n]+\\)`?[ \t]*$"
                      (regexp-quote field))
              content))
    (string-trim (match-string 1 content))))

(defun rc/test-calibration--manual-status-info (date language scenario)
  "Return manual calibration status plist for DATE LANGUAGE and SCENARIO."
  (let* ((content (rc/test-calibration--summary-content date language scenario))
         (raw-status (or (rc/test-calibration--extract-manual-field content "manual-status")
                         "pending"))
         (status (if (member raw-status rc/test-calibration-manual-status-values)
                     raw-status
                   "pending"))
         (updated-at (rc/test-calibration--extract-manual-field content "manual-updated-at"))
         (duration (rc/test-calibration--extract-manual-field content "真实运行时长(分钟)")))
    (list :status status
          :updated-at updated-at
          :duration duration
          :summary-exists (and content t))))

(defun rc/test-calibration--manual-status-string (status)
  "Render manual STATUS for markdown."
  (pcase status
    ("completed" "manual-completed")
    ("partial" "manual-partial")
    (_ "manual-pending")))

(defun rc/test-calibration--specialized-status-cell (date language scenario)
  "Return status cell plist for DATE LANGUAGE and specialized SCENARIO."
  (let* ((manual (rc/test-calibration--manual-status-info date language scenario))
         (status (plist-get manual :status))
         (updated-at (plist-get manual :updated-at))
         (duration (plist-get manual :duration))
         (trace-entry (rc/test-calibration--lookup-trace date language scenario))
         (scripted (and trace-entry
                        (rc/test-calibration--status-string
                         (rc/test-calibration--settled-status
                          (plist-get trace-entry :data)))))
         (status-label
          (if scripted
              (format "%s + %s"
                      (rc/test-calibration--manual-status-string status)
                      scripted)
            (rc/test-calibration--manual-status-string status)))
         (note-parts
          (delq nil
                (list
                 (pcase status
                   ("completed" "人工校准已完成")
                   ("partial" "人工校准进行中")
                   (_ "待人工校准"))
                 (when duration
                   (format "runtime=%smin" duration))
                 (when updated-at
                   (format "updated=%s" updated-at))
                 (when scripted
                   (format "scripted=%s" scripted))))))
    (list :status status-label
          :note (string-join note-parts "；"))))

(defun rc/test-calibration--cache-revisit (trace)
  "Return cache revisit evidence plist from TRACE."
  (rc/test-calibration--aget trace "cache-revisit"))

(defun rc/test-calibration--diverge-restore (trace)
  "Return diverge-and-restore evidence plist from TRACE."
  (rc/test-calibration--aget trace "diverge-restore"))

(defun rc/test-calibration--coordination (trace)
  "Return coordination evidence plist from TRACE."
  (rc/test-calibration--aget trace "coordination"))

(defun rc/test-calibration--scenario-biggest-problem (trace)
  "Return auto-generated biggest-problem sentence for TRACE."
  (let ((status (rc/test-calibration--settled-status trace))
        (scenario (rc/test-calibration--aget trace "scenario"))
        (post-accept-state (rc/test-calibration--nested trace "settled" "post-accept-state"))
        (cache-revisit (rc/test-calibration--cache-revisit trace))
        (coordination (rc/test-calibration--coordination trace))
        (diverge-restore (rc/test-calibration--diverge-restore trace)))
    (cond
     ((eq status 'scripted-visible-js-mode)
      "链路已通，但当前仍是 js-mode fallback，不是 TS 专属 mode")
     ((equal scenario "coordination")
      (if (and coordination
               (rc/test-calibration--aget coordination "blocked-reason")
               (rc/test-calibration--aget coordination "yield-target"))
          "协调层已拿到真实 blocked/yield 证据，但手感与误伤率仍缺人工校准"
        "协调层还没拿到完整 blocked/yield 证据，需要继续排查"))
     ((equal scenario "cache-revisit")
      (if (rc/test-calibration--aget cache-revisit "revisit-success")
          "二次触发已命中 cache，但 stale/prefix 体验仍缺人工校准"
        "二次触发还没稳定命中 cache，需要继续排查"))
     ((equal scenario "diverge-and-restore")
      (if (rc/test-calibration--aget diverge-restore "restore-success")
          "临时偏离后能恢复，但恢复手感和 delete 节奏仍缺人工校准"
        "临时偏离后的恢复链路还不稳定，需要继续排查"))
     ((equal scenario "full-accept")
      (if post-accept-state
          (format "accept 后状态为 %s，但仍缺人工节奏判断" post-accept-state)
        "accept 后状态还没有被自动解释清楚"))
     ((eq status 'scripted-timeout)
      "这次 probe 发生 timeout，需要继续观察是否偶发链路抖动")
     ((memq status '(scripted-failed scripted-other))
      "这次 probe 未拿到 visible completion，需要继续排查")
     (t
      "还没有人工体验数据"))))

(defun rc/test-calibration--scenario-highlight (trace)
  "Return auto-generated highlight sentence for TRACE."
  (let ((visible-text (or (rc/test-calibration--aget trace "visible-text") ""))
        (scenario (rc/test-calibration--aget trace "scenario"))
        (language (rc/test-calibration--aget trace "language"))
        (accept (rc/test-calibration--aget trace "accept"))
        (post-accept-state (rc/test-calibration--nested trace "settled" "post-accept-state"))
        (cache-revisit (rc/test-calibration--cache-revisit trace))
        (coordination (rc/test-calibration--coordination trace))
        (diverge-restore (rc/test-calibration--diverge-restore trace)))
    (let ((status (rc/test-calibration--settled-status trace)))
      (cond
       ((equal scenario (rc/test-calibration-specialized-scenario language))
        (pcase language
          ("cpp" "紧凑循环块的真实续写已打通，可继续看空行和局部风格是否合手")
          ("python" "缩进块内部的真实续写已打通，可继续看 dedent 和 sibling clause 手感")
          ("rust" "borrow 风格块的真实续写已打通，可继续看 match/借用语气是否别扭")
          ("ts" "object literal 的真实续写已打通，可继续看类型上下文和 fallback 影响")
          ("elisp" "sexp tail 的真实续写已打通，可继续看括号尾部和局部风格手感")
          (_ "语言特化 scenario 的真实续写已打通，下一步看人工手感")))
       ((eq status 'scripted-visible-js-mode)
        "TS 文件真实链路已打通，不再退回 fundamental-mode")
       ((equal scenario "coordination")
        (format "coordination 已拿到 blocked=%s / yield=%s / request=%s"
                (or (rc/test-calibration--aget coordination "blocked-reason") "none")
                (or (rc/test-calibration--aget coordination "yield-target") "none")
                (or (rc/test-calibration--aget coordination "request-source") "none")))
       ((equal scenario "cache-revisit")
        (format "cache revisit 二次触发%s%s%s"
                (if (equal (rc/test-calibration--aget cache-revisit "second-request-source")
                           "cache")
                    " 直接走 cache"
                  " 未直接走 cache")
                (let ((kind (rc/test-calibration--aget cache-revisit "second-cache-hit-kind")))
                  (if kind
                      (format "（hit=%s）" kind)
                    ""))
                (if (rc/test-calibration--aget cache-revisit "second-network-request-p")
                    "，且发生了新的网络请求"
                  "，且没有新的网络请求")))
       ((equal scenario "diverge-and-restore")
        (format "diverge 后 restore%s%s"
                (if (rc/test-calibration--aget diverge-restore "restore-available-during")
                    " 仍可用"
                  " 不可用")
                (if (rc/test-calibration--aget diverge-restore "restored-event")
                    "，且 delete 后成功恢复"
                  "，但 delete 后未成功恢复")))
       ((equal scenario "full-accept")
        (format "full accept 已实际执行%s%s"
                (if accept (format "（accept=%s）" accept) "")
                (if post-accept-state
                    (format "，post-accept-state=%s" post-accept-state)
                  "")))
       ((memq status '(scripted-visible scripted-visible-js-mode))
        (if (string-empty-p visible-text)
            "行尾续写链路直接打通"
          (format "行尾续写链路直接打通，visible text 示例: %S"
                  (truncate-string-to-width visible-text 48 nil nil t))))
       ((eq status 'scripted-timeout)
        "脚本能稳定落盘 timeout 证据，便于后续复核")
       (t "已拿到失败工件，便于后续继续分析")))))

(defun rc/test-calibration--summary-auto-block (trace)
  "Render summary auto block from parsed TRACE."
  (let* ((language (rc/test-calibration--aget trace "language"))
         (scenario (rc/test-calibration--aget trace "scenario"))
         (report (rc/test-calibration--aget trace "stats-report"))
         (latency (or (rc/test-calibration--stats-number report "latency first p50")
                      "N/A"))
         (requests (or (rc/test-calibration--stats-number report "requests") "N/A"))
         (cache-miss (or (rc/test-calibration--stats-number report "cache-miss") "N/A"))
         (blocked (or (rc/test-calibration--blocked-reasons report) "none"))
         (status (rc/test-calibration--settled-status trace))
         (need-ert (if (memq status '(scripted-failed scripted-timeout))
                       "暂不需要；先观察是否稳定复现"
                     "暂不需要；本轮没有稳定异常"))
         (manual-note (rc/test-calibration--scenario-coverage-note scenario))
         (real-task-note (if (equal language "ts")
                             "是真实项目文件，但当前仍依赖 js-mode fallback"
                           "是真实项目文件，但这里只验证链路"))
         (visible-text (or (rc/test-calibration--aget trace "visible-text") ""))
         (accept (or (rc/test-calibration--aget trace "accept") "none"))
         (post-accept-state (or (rc/test-calibration--nested trace "settled" "post-accept-state")
                                "none"))
         (cache-revisit (rc/test-calibration--cache-revisit trace))
         (coordination (rc/test-calibration--coordination trace))
         (diverge-restore (rc/test-calibration--diverge-restore trace))
         (cache-revisit-source (or (rc/test-calibration--aget cache-revisit "second-request-source")
                                   "none"))
         (cache-revisit-hit-kind (or (rc/test-calibration--aget cache-revisit "second-cache-hit-kind")
                                     "none"))
         (cache-revisit-network (if (rc/test-calibration--aget cache-revisit "second-network-request-p")
                                    "yes"
                                  "no"))
         (cache-revisit-display (or (rc/test-calibration--aget cache-revisit "second-display-phase")
                                    "none"))
         (cache-revisit-note (if cache-revisit
                                 (format "second-source=%s hit=%s network=%s display=%s"
                                         cache-revisit-source
                                         cache-revisit-hit-kind
                                         cache-revisit-network
                                         cache-revisit-display)
                               "none"))
         (coordination-note
          (if coordination
              (format "blocked=%s yield=%s request=%s aborted=%s"
                      (or (rc/test-calibration--aget coordination "blocked-reason") "none")
                      (or (rc/test-calibration--aget coordination "yield-target") "none")
                      (or (rc/test-calibration--aget coordination "request-source") "none")
                      (if (rc/test-calibration--aget coordination "company-aborted") "yes" "no"))
            "none"))
         (diverge-restore-note
          (if diverge-restore
              (format "restore-available=%s divergence=%s restored=%s visible-after-restore=%s"
                      (if (rc/test-calibration--aget diverge-restore "restore-available-during") "yes" "no")
                      (or (rc/test-calibration--aget diverge-restore "divergence-distance") 0)
                      (if (rc/test-calibration--aget diverge-restore "restored-event") "yes" "no")
                      (if (rc/test-calibration--aget diverge-restore "visible-after-restore") "yes" "no"))
            "none"))
         (trace-file (format "trace-%s-%s-001.json" language scenario))
         (stats-file (format "stats-%s-%s.txt" language scenario))
         (probe-file (format "probe-%s-%s.el" language scenario))
         (specialized-note (or (rc/test-calibration--specialized-coverage-note trace)
                               "not-applicable")))
    (format
     "- 日期: `%s`\n- 语言: `%s`\n- 场景: `%s`\n- 项目: `%s`\n- 文件: `%s`\n- major-mode: `%s`\n- 模型: `%s`\n- backend: `%s`\n- auto-trigger mode: `off`\n- complete profile: `balanced`\n\n## 自动采证\n\n- scripted probe 状态: `%s`\n- visible text: %s\n- accept mode: `%s`\n- post-accept-state: `%s`\n- cache-revisit evidence: `%s`\n- coordination evidence: `%s`\n- diverge-restore evidence: `%s`\n- stats 摘要: `requests=%s cache-miss=%s blocked-reasons=%s latency-first≈%ss`\n- trace route: `%s`\n- 工件: `%s` / `%s` / `%s`\n\n## 自动覆盖结论\n\n- Common Scenario A 行尾续写: `%s`\n- Common Scenario B 接受 / 部分接受: `%s`\n- Common Scenario C cache / revisit: `%s`\n- Common Scenario D divergence / restore: `%s`\n- Common Scenario E formatting / vertical spacing: `未覆盖`\n- Common Scenario F coordination / yield: `%s`\n- Language-specialized scenario: `%s`\n- scripted-only 备注: `%s`\n- 自动 highlight: `%s`\n- 自动 biggest problem: `%s`\n\n## 自动 Backflow 建议\n\n- 是否需要回流 ERT: `%s`\n- 若需要，最小复现条件: `若后续人工校准或复跑再次稳定失败，再抽最小复现`\n- 建议归属的测试文件: `tests/complete/ai-complete-state-test.el 或 ai-complete-observe-test.el`\n"
     (substring (or (rc/test-calibration--aget trace "timestamp") "") 0 10)
     language
     scenario
     (rc/test-calibration--aget trace "project")
     (file-name-nondirectory (rc/test-calibration--aget trace "file"))
     (rc/test-calibration--aget trace "major-mode")
     (rc/test-calibration--aget trace "model")
     (if (string-match "#s(gptel-\\([^ ]+\\)" (or (rc/test-calibration--aget trace "backend") ""))
         (concat "gptel-" (match-string 1 (rc/test-calibration--aget trace "backend")))
       "unknown")
     (rc/test-calibration--status-string status)
     (if (string-empty-p visible-text)
         "`none`"
       (format "`%s`" (truncate-string-to-width visible-text 80 nil nil t)))
     accept
     post-accept-state
     cache-revisit-note
     coordination-note
     diverge-restore-note
     requests
     cache-miss
     blocked
     latency
     (rc/test-calibration--trace-route-summary trace)
     stats-file
     trace-file
     probe-file
     (if (equal scenario "line-end-continuation")
         manual-note
       "未覆盖")
     (if (equal scenario "full-accept")
         manual-note
       "未覆盖")
     (if (equal scenario "cache-revisit")
         manual-note
       "未覆盖")
     (if (equal scenario "diverge-and-restore")
         manual-note
       "未覆盖")
     (if (equal scenario "coordination")
         "已覆盖；已验证真实 blocked/yield 协调证据"
       "未覆盖")
     specialized-note
     real-task-note
     (rc/test-calibration--scenario-highlight trace)
     (rc/test-calibration--scenario-biggest-problem trace)
     need-ert)))

(defun rc/test-calibration-fill-summary (date language scenario)
  "Auto-fill one summary for DATE LANGUAGE and SCENARIO from trace artifacts."
  (interactive "sDate (YYYY-MM-DD): \nsLanguage: \nsScenario: ")
  (rc/test-calibration--ensure-write-allowed)
  (let* ((entry (or (rc/test-calibration--lookup-trace date language scenario)
                    (user-error "No trace artifact for %s/%s on %s" language scenario date)))
         (trace (plist-get entry :data))
         (summary-file (rc/test-calibration--summary-file date language scenario)))
    (rc/test-calibration--ensure-template-file summary-file "language-run-summary.md")
    (with-temp-file summary-file
      (insert
       (rc/test-calibration--merge-with-template
        summary-file
        "language-run-summary.md"
        (rc/test-calibration--summary-auto-block trace))))
    summary-file))

(defun rc/test-calibration--common-scenario-row (date scenario languages)
  "Render one common scenario row for DATE SCENARIO and LANGUAGES."
  (let ((goal (pcase scenario
                ("general" "综合 scripted probe（待拆细）")
                ("line-end-continuation" "行尾续写是否自然")
                ("full-accept" "full accept 后结果与节奏")
                ("cache-revisit" "cache/stale 是否真有帮助")
                ("diverge-and-restore" "兼容输入 / 回退 / restore 是否平滑")
                ("coordination" "company/yas/CAPF 等协调是否清晰")
                (_ scenario))))
    (concat
     "| `" scenario "` | " goal
     (mapconcat
      (lambda (language)
        (let ((entry (rc/test-calibration--lookup-trace date language scenario)))
          (concat " | "
                  (if entry
                      (rc/test-calibration--status-string
                       (rc/test-calibration--settled-status (plist-get entry :data)))
                    "scaffold-only"))))
      languages
      "")
     " |\n")))

(defun rc/test-calibration--scenario-rows (date)
  "Return ordered scenario rows to render for DATE."
  (let ((rows rc/test-calibration-default-common-scenarios))
    (when (seq-some (lambda (entry)
                      (equal (plist-get entry :scenario) "general"))
                    (rc/test-calibration--trace-artifacts date))
      (setq rows (cons "general" rows)))
    (delete-dups rows)))

(defun rc/test-calibration--successful-languages (date scenario)
  "Return successful languages for DATE and SCENARIO."
  (seq-filter
   #'identity
   (mapcar
    (lambda (language)
      (let ((entry (rc/test-calibration--lookup-trace date language scenario)))
        (when (and entry
                   (memq (rc/test-calibration--settled-status (plist-get entry :data))
                         '(scripted-visible scripted-visible-js-mode)))
          language)))
    rc/test-calibration-default-languages)))

(defun rc/test-calibration--successful-rollup-languages (date)
  "Return languages with successful preferred rollup traces on DATE."
  (seq-filter
   #'identity
   (mapcar
    (lambda (language)
      (let ((entry (rc/test-calibration--best-rollup-entry date language)))
        (when (and entry
                   (memq (rc/test-calibration--settled-status (plist-get entry :data))
                         '(scripted-visible scripted-visible-js-mode)))
          language)))
    rc/test-calibration-default-languages)))

(defun rc/test-calibration--languages-with-status (date status)
  "Return languages for DATE whose line-end trace has STATUS."
  (seq-filter
   #'identity
   (mapcar
    (lambda (language)
      (let ((entry (rc/test-calibration--lookup-trace date language "line-end-continuation")))
        (when (and entry
                   (eq (rc/test-calibration--settled-status (plist-get entry :data))
                       status))
          language)))
    rc/test-calibration-default-languages)))

(defun rc/test-calibration--languages-with-rollup-status (date status)
  "Return languages for DATE whose preferred rollup traces have STATUS."
  (seq-filter
   #'identity
   (mapcar
    (lambda (language)
      (let ((entry (rc/test-calibration--best-rollup-entry date language)))
        (when (and entry
                   (eq (rc/test-calibration--settled-status (plist-get entry :data))
                       status))
          language)))
    rc/test-calibration-default-languages)))

(defun rc/test-calibration--weekly-summary-markdown (date)
  "Render weekly summary markdown for DATE."
  (let* ((successful (rc/test-calibration--successful-rollup-languages date))
         (fallback-ts
          (rc/test-calibration--languages-with-rollup-status
           date 'scripted-visible-js-mode))
         (timeouts
          (rc/test-calibration--languages-with-rollup-status
           date 'scripted-timeout))
         (traces (rc/test-calibration--trace-artifacts date))
         (model (or (seq-some
                     (lambda (entry)
                       (rc/test-calibration--aget (plist-get entry :data) "model"))
                     traces)
                    "unknown"))
         (blocked-count
          (delete-dups
           (delq nil
                 (mapcar
                  (lambda (entry)
                    (let ((blocked
                           (rc/test-calibration--blocked-reasons
                            (rc/test-calibration--aget
                             (plist-get entry :data)
                             "stats-report"))))
                      (unless (or (null blocked) (equal blocked "none"))
                        blocked)))
                  traces))))
         (cache-revisit-languages
          (seq-filter
           #'identity
           (mapcar
            (lambda (language)
              (let* ((entry (rc/test-calibration--lookup-trace date language "cache-revisit"))
                     (trace (and entry (plist-get entry :data)))
                     (cache-revisit (and trace (rc/test-calibration--cache-revisit trace))))
                (when (and cache-revisit
                           (equal (rc/test-calibration--aget cache-revisit "second-request-source")
                                  "cache")
                           (not (rc/test-calibration--aget cache-revisit "second-network-request-p")))
                  language)))
            rc/test-calibration-default-languages)))
         (coordination-languages
          (seq-filter
           #'identity
           (mapcar
            (lambda (language)
              (let* ((entry (rc/test-calibration--lookup-trace date language "coordination"))
                     (trace (and entry (plist-get entry :data)))
                     (coordination (and trace (rc/test-calibration--coordination trace))))
                (when (and coordination
                           (rc/test-calibration--aget coordination "blocked-reason")
                           (rc/test-calibration--aget coordination "yield-target"))
                  language)))
            rc/test-calibration-default-languages)))
         (manual-statuses
          (mapcar
           (lambda (language)
             (cons language
                   (plist-get
                    (rc/test-calibration--manual-status-info
                     date
                     language
                     (rc/test-calibration-specialized-scenario language))
                    :status)))
           rc/test-calibration-default-languages))
         (manual-completed
          (mapcar #'car
                  (seq-filter (lambda (entry) (equal (cdr entry) "completed"))
                              manual-statuses)))
         (manual-partial
          (mapcar #'car
                  (seq-filter (lambda (entry) (equal (cdr entry) "partial"))
                              manual-statuses)))
         (manual-pending
          (mapcar #'car
                  (seq-filter (lambda (entry) (equal (cdr entry) "pending"))
                              manual-statuses))))
    (format
     "- 周期: `%s / scripted checkpoint`
- 覆盖语言: `%s`
- 使用模型: `%s`

## 自动汇总

- 最稳定的语言: `%s`
- 最容易误伤的语言: `%s`
- 最常见 blocked reason: `%s`
- 最清晰的 coordination 证据: `%s`
- 最常见 cooldown 场景: `none`：当前 scripted probe 还没有进入 cooldown 体验层。
- 最明显的 scripted cache / stale 问题: `%s`
- manual calibration 进度: `%s`
- manual calibration pending: `%s`
- 下一轮优先语言: `%s`
"
     date
     (string-join rc/test-calibration-default-languages " / ")
     model
     (if successful
         (format "%s：当前可见的 scripted probe 已拿到 visible evidence"
                 (string-join successful " / "))
       "暂无")
     (cond
      (fallback-ts
       "TypeScript：当前仍走 js-mode fallback，需要继续盯环境债")
      (timeouts
       (format "%s：出现 scripted timeout，需要继续复核"
               (string-join timeouts " / ")))
      (t
       "暂无 scripted 证据支持“误伤”判断；manual calibration 仍未开始。"))
     (if blocked-count
         (string-join blocked-count " / ")
       "none")
     (if coordination-languages
         (format "%s：已拿到 blocked/yield 证据，但仍缺人工误伤率判断。"
                 (string-join coordination-languages " / "))
       "暂无：当前还没有 scripted coordination 证据。")
     (if cache-revisit-languages
         (format "%s：已看到二次触发直接走 cache，但 stale/prefix 还没覆盖。"
                 (string-join cache-revisit-languages " / "))
       "暂无：当前还没有 scripted cache revisit 证据。")
     (format "%d/%d specialized scenario completed%s"
             (length manual-completed)
             (length rc/test-calibration-default-languages)
             (if manual-partial
                 (format "，partial=%s" (string-join manual-partial " / "))
               ""))
     (if manual-pending
         (string-join manual-pending " / ")
       "none")
     (cond
      (manual-pending
       (format "%s：优先补语言特化 manual calibration。"
               (string-join manual-pending " / ")))
      (manual-partial
       (format "%s：先把本轮人工校准补全。"
               (string-join manual-partial " / ")))
      (fallback-ts
       "TypeScript：当前仍走 js-mode fallback。")
      (timeouts
       (format "%s：因为 scripted probe 出现 timeout。"
               (string-join timeouts " / ")))
      (t
       "TypeScript / Rust：优先继续做人工校准和语言特化 scenario。")))))

(defun rc/test-calibration--wave-index-markdown (date wave-name)
  "Render wave index markdown for DATE and WAVE-NAME."
  (let* ((successful (rc/test-calibration--successful-rollup-languages date))
         (ts-fallback (member "ts"
                              (rc/test-calibration--languages-with-rollup-status
                               date 'scripted-visible-js-mode)))
         (timeouts (rc/test-calibration--languages-with-rollup-status date 'scripted-timeout))
         (manual-statuses
          (mapcar
           (lambda (language)
             (cons language
                   (plist-get
                    (rc/test-calibration--manual-status-info
                     date
                     language
                     (rc/test-calibration-specialized-scenario language))
                    :status)))
           rc/test-calibration-default-languages))
         (manual-completed
          (seq-count (lambda (entry) (equal (cdr entry) "completed")) manual-statuses))
         (manual-partial
          (seq-count (lambda (entry) (equal (cdr entry) "partial")) manual-statuses))
         (manual-pending
          (seq-count (lambda (entry) (equal (cdr entry) "pending")) manual-statuses)))
    (concat
     "- 日期: `" date "`\n"
     "- Wave: `" wave-name "`\n"
     "- 状态: `scripted probes completed / manual calibration "
     (number-to-string manual-completed) "/"
     (number-to-string (length rc/test-calibration-default-languages))
     " completed"
     (if (> manual-partial 0)
         (format " / partial=%d" manual-partial)
       "")
     " / pending="
     (number-to-string manual-pending)
     "`\n"
     "- 覆盖语言: `" (string-join rc/test-calibration-default-languages " / ") "`\n"
     "- 说明: `当前已自动汇总 scripted artifact；manual calibration 通过 summary 中的 manual-status 自动统计。`\n\n"
     "## 通用 Scenario\n\n"
     "| Scenario | 目标 | cpp | python | rust | ts | elisp |\n"
     "| --- | --- | --- | --- | --- | --- | --- |\n"
     (mapconcat
      (lambda (scenario)
        (rc/test-calibration--common-scenario-row date scenario rc/test-calibration-default-languages))
      (rc/test-calibration--scenario-rows date)
      "")
     "\n## 语言特化 Scenario\n\n"
     "| Language | Scenario | 目标 | 状态 | 备注 |\n"
     "| --- | --- | --- | --- | --- |\n"
     (mapconcat
      (lambda (language)
        (let* ((scenario (rc/test-calibration-specialized-scenario language))
               (goal (pcase language
                       ("cpp" "紧凑循环 / 块间空行 / 工程风继承")
                       ("python" "缩进块 / 续写 / 空行")
                       ("rust" "borrow 风块 / match / 紧凑度")
                       ("ts" "object literal / type-heavy context")
                       ("elisp" "sexp tail / 局部风格 / 续写")
                       (_ "语言特化手感校准")))
               (cell (rc/test-calibration--specialized-status-cell date language scenario)))
          (format "| `%s` | `%s` | %s | %s | %s |\n"
                  language
                  scenario
                  goal
                  (plist-get cell :status)
                  (plist-get cell :note))))
      rc/test-calibration-default-languages
      "")
     "\n"
     "## 工件 Checklist\n\n"
     "- `summary-<lang>-<scenario>.md`\n"
     "- `stats-<lang>-<scenario>.txt`\n"
     "- `trace-<lang>-<scenario>-001.json`\n"
     "- `probe-<lang>-<scenario>.el`（scripted probe）\n"
     "- `weekly-summary.md`\n\n"
     "## 回流判断\n\n"
     "- 哪些 case 已稳定复现，可回流 ERT: `当前 scripted artifact 没有给出稳定 live bug。`\n"
     "- 哪些 case 只是参数问题: `暂无自动证据。`\n"
     "- 哪些 case 只是 prompt/context 问题: `暂无自动证据。`\n"
     "- 哪些 case 只是 manual-only feel issue: `需要等 specialized scenario 的 manual-status 进入 completed/partial 后再判断。`\n\n"
     "## 备注\n\n"
     "- preferred scripted visible languages: `"
     (if successful (string-join successful " / ") "none")
     "`\n"
     "- `ts` 当前 fallback: `" (if ts-fallback "yes" "no") "`\n"
     "- scripted timeout languages: `" (if timeouts (string-join timeouts " / ") "none") "`\n"
     "- scripted probe 完成不等于 wave completed。\n"
     "- manual calibration 至少补完一轮语言实跑后才能宣称体验结论。\n"
     "- specialized scenario 的 manual-status 由人工填写，汇总结果由脚本自动读取。\n")))

(defun rc/test-calibration-fill-wave-index (date &optional wave-name)
  "Auto-fill wave index for DATE and optional WAVE-NAME."
  (interactive "sDate (YYYY-MM-DD): ")
  (rc/test-calibration--ensure-write-allowed)
  (let ((file (rc/test-calibration--wave-index-file
               date (or wave-name rc/test-calibration-wave-default-name))))
    (rc/test-calibration--ensure-template-file file "wave-index.md")
    (with-temp-file file
      (insert
       (rc/test-calibration--merge-with-template
        file
        "wave-index.md"
        (rc/test-calibration--wave-index-markdown
         date (or wave-name rc/test-calibration-wave-default-name)))))
    file))

(defun rc/test-calibration-fill-weekly-summary (date)
  "Auto-fill weekly summary for DATE."
  (interactive "sDate (YYYY-MM-DD): ")
  (rc/test-calibration--ensure-write-allowed)
  (let ((file (rc/test-calibration--weekly-file date)))
    (rc/test-calibration--ensure-template-file file "weekly-summary.md")
    (with-temp-file file
      (insert
       (rc/test-calibration--merge-with-template
        file
        "weekly-summary.md"
        (rc/test-calibration--weekly-summary-markdown date))))
    file))

(defun rc/test-calibration-fill-date (date &optional wave-name)
  "Auto-fill summaries, wave index, and weekly summary for DATE."
  (interactive "sDate (YYYY-MM-DD): ")
  (rc/test-calibration--ensure-write-allowed)
  (dolist (entry (rc/test-calibration--trace-artifacts date))
    (rc/test-calibration-fill-summary
     date
     (plist-get entry :language)
     (plist-get entry :scenario)))
  (rc/test-calibration-fill-wave-index date (or wave-name rc/test-calibration-wave-default-name))
  (rc/test-calibration-fill-weekly-summary date)
  (message "Filled calibration markdown for %s" date)
  t)

(provide 'fill-calibration-summaries)
;;; fill-calibration-summaries.el ends here
