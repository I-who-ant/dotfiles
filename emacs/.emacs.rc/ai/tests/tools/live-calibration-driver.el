;;; live-calibration-driver.el --- Real-call calibration probe runner -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'pp)
(require 'seq)
(require 'subr-x)

(load "/home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el" nil t)

(defvar rc/test-live-calibration-history-root
  nil
  "Optional override root directory for live probe artifacts.

When nil, live probes reuse `rc/test-calibration-history-root'.")

(defconst rc/test-live-driver-file
  "/home/seeback/.emacs.rc/ai/tests/tools/live-calibration-driver.el"
  "Absolute path to this driver file for isolated subprocess probes.")

(defconst rc/test-live-wave-01-cases
  (list
   '(:language "cpp"
     :scenario "general"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/tool_runtime.cpp"
     :snippet "\n\n// phase07 live probe\nstatic int rc_phase07_probe_sum(const std::vector<std::string>& items) {\n    int total = 0;\n    for (const auto& item : items) {\n        ")
   '(:language "python"
     :scenario "general"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/runtime.py"
     :snippet "\n\n# phase07 live probe\ndef _phase07_probe_sum(items):\n    total = 0\n    for item in items:\n        ")
   '(:language "rust"
     :scenario "general"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/src/session.rs"
     :snippet "\n\n// phase07 live probe\nfn rc_phase07_probe_sum(items: &[String]) -> usize {\n    let mut total = 0usize;\n    for item in items {\n        ")
   '(:language "ts"
     :scenario "general"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/src/tools/WebFetchTool/WebFetchTool.ts"
     :snippet "\n\n// phase07 live probe\nfunction rcPhase07ProbeSum(items: string[]): number {\n  let total = 0;\n  for (const item of items) {\n    ")
   '(:language "elisp"
     :scenario "general"
     :project "/home/seeback/.emacs.rc/ai/"
     :file "/home/seeback/.emacs.rc/ai/complete/ai-complete-state-rc.el"
     :snippet "\n\n;; phase07 live probe\n(defun rc/phase07-probe-example (items)\n  (let ((total 0))\n    (dolist (item items)\n      "))
  "Default real-call probe cases for Phase 07 wave 01.")

(defconst rc/test-live-wave-02-common-cases
  (list
   '(:language "cpp"
     :scenario "line-end-continuation"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/tool_runtime.cpp"
     :snippet "\n\n// phase07 line-end-continuation\nstatic int rc_phase07_line_end(const std::vector<std::string>& items) {\n    int total = 0;\n    for (const auto& item : items) {\n        ")
   '(:language "cpp"
     :scenario "full-accept"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/tool_runtime.cpp"
     :snippet "\n\n// phase07 full-accept\nstatic int rc_phase07_full_accept(const std::vector<std::string>& items) {\n    int total = 0;\n    for (const auto& item : items) {\n        "
     :accept full)
   '(:language "cpp"
     :scenario "cache-revisit"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/tool_runtime.cpp"
     :snippet "\n\n// phase07 cache-revisit\nstatic int rc_phase07_cache_revisit(const std::vector<std::string>& items) {\n    int total = 0;\n    for (const auto& item : items) {\n        "
     :probe-kind cache-revisit)
   '(:language "cpp"
     :scenario "diverge-and-restore"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/tool_runtime.cpp"
     :snippet "\n\n// phase07 diverge-and-restore\nstatic int rc_phase07_diverge_restore(const std::vector<std::string>& items) {\n    int total = 0;\n    for (const auto& item : items) {\n        "
     :probe-kind diverge-and-restore)
   '(:language "cpp"
     :scenario "coordination"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/tool_runtime.cpp"
     :snippet "\n\n// phase07 coordination\nstatic int rc_phase07_coordination(const std::vector<std::string>& items) {\n    int total = 0;\n    for (const auto& item : items) {\n        "
     :probe-kind coordination)
   '(:language "python"
     :scenario "line-end-continuation"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/runtime.py"
     :snippet "\n\n# phase07 line-end-continuation\ndef _phase07_line_end(items):\n    total = 0\n    for item in items:\n        ")
   '(:language "python"
     :scenario "full-accept"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/runtime.py"
     :snippet "\n\n# phase07 full-accept\ndef _phase07_full_accept(items):\n    total = 0\n    for item in items:\n        "
     :accept full)
   '(:language "python"
     :scenario "cache-revisit"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/runtime.py"
     :snippet "\n\n# phase07 cache-revisit\ndef _phase07_cache_revisit(items):\n    total = 0\n    for item in items:\n        "
     :probe-kind cache-revisit)
   '(:language "python"
     :scenario "diverge-and-restore"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/runtime.py"
     :snippet "\n\n# phase07 diverge-and-restore\ndef _phase07_diverge_restore(items):\n    total = 0\n    for item in items:\n        "
     :probe-kind diverge-and-restore)
   '(:language "python"
     :scenario "coordination"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/runtime.py"
     :snippet "\n\n# phase07 coordination\ndef _phase07_coordination(items):\n    total = 0\n    for item in items:\n        "
     :probe-kind coordination)
   '(:language "rust"
     :scenario "line-end-continuation"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/src/session.rs"
     :snippet "\n\n// phase07 line-end-continuation\nfn rc_phase07_line_end(items: &[String]) -> usize {\n    let mut total = 0usize;\n    for item in items {\n        ")
   '(:language "rust"
     :scenario "full-accept"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/src/session.rs"
     :snippet "\n\n// phase07 full-accept\nfn rc_phase07_full_accept(items: &[String]) -> usize {\n    let mut total = 0usize;\n    for item in items {\n        "
     :accept full)
   '(:language "rust"
     :scenario "cache-revisit"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/src/session.rs"
     :snippet "\n\n// phase07 cache-revisit\nfn rc_phase07_cache_revisit(items: &[String]) -> usize {\n    let mut total = 0usize;\n    for item in items {\n        "
     :probe-kind cache-revisit)
   '(:language "rust"
     :scenario "diverge-and-restore"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/src/session.rs"
     :snippet "\n\n// phase07 diverge-and-restore\nfn rc_phase07_diverge_restore(items: &[String]) -> usize {\n    let mut total = 0usize;\n    for item in items {\n        "
     :probe-kind diverge-and-restore)
   '(:language "rust"
     :scenario "coordination"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/src/session.rs"
     :snippet "\n\n// phase07 coordination\nfn rc_phase07_coordination(items: &[String]) -> usize {\n    let mut total = 0usize;\n    for item in items {\n        "
     :probe-kind coordination)
   '(:language "ts"
     :scenario "line-end-continuation"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/src/tools/WebFetchTool/WebFetchTool.ts"
     :snippet "\n\n// phase07 line-end-continuation\nfunction rcPhase07LineEnd(items: string[]): number {\n  let total = 0;\n  for (const item of items) {\n    ")
   '(:language "ts"
     :scenario "full-accept"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/src/tools/WebFetchTool/WebFetchTool.ts"
     :snippet "\n\n// phase07 full-accept\nfunction rcPhase07FullAccept(items: string[]): number {\n  let total = 0;\n  for (const item of items) {\n    "
     :accept full)
   '(:language "ts"
     :scenario "cache-revisit"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/src/tools/WebFetchTool/WebFetchTool.ts"
     :snippet "\n\n// phase07 cache-revisit\nfunction rcPhase07CacheRevisit(items: string[]): number {\n  let total = 0;\n  for (const item of items) {\n    "
     :probe-kind cache-revisit)
   '(:language "ts"
     :scenario "diverge-and-restore"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/src/tools/WebFetchTool/WebFetchTool.ts"
     :snippet "\n\n// phase07 diverge-and-restore\nfunction rcPhase07DivergeRestore(items: string[]): number {\n  let total = 0;\n  for (const item of items) {\n    "
     :probe-kind diverge-and-restore)
   '(:language "ts"
     :scenario "coordination"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/src/tools/WebFetchTool/WebFetchTool.ts"
     :snippet "\n\n// phase07 coordination\nfunction rcPhase07Coordination(items: string[]): number {\n  let total = 0;\n  for (const item of items) {\n    "
     :probe-kind coordination)
   '(:language "elisp"
     :scenario "line-end-continuation"
     :project "/home/seeback/.emacs.rc/ai/"
     :file "/home/seeback/.emacs.rc/ai/complete/ai-complete-state-rc.el"
     :snippet "\n\n;; phase07 line-end-continuation\n(defun rc/phase07-line-end (items)\n  (let ((total 0))\n    (dolist (item items)\n      ")
   '(:language "elisp"
     :scenario "full-accept"
     :project "/home/seeback/.emacs.rc/ai/"
     :file "/home/seeback/.emacs.rc/ai/complete/ai-complete-state-rc.el"
     :snippet "\n\n;; phase07 full-accept\n(defun rc/phase07-full-accept (items)\n  (let ((total 0))\n    (dolist (item items)\n      "
     :accept full)
   '(:language "elisp"
     :scenario "cache-revisit"
     :project "/home/seeback/.emacs.rc/ai/"
     :file "/home/seeback/.emacs.rc/ai/complete/ai-complete-state-rc.el"
     :snippet "\n\n;; phase07 cache-revisit\n(defun rc/phase07-cache-revisit (items)\n  (let ((total 0))\n    (dolist (item items)\n      "
     :probe-kind cache-revisit)
   '(:language "elisp"
     :scenario "diverge-and-restore"
     :project "/home/seeback/.emacs.rc/ai/"
     :file "/home/seeback/.emacs.rc/ai/complete/ai-complete-state-rc.el"
     :snippet "\n\n;; phase07 diverge-and-restore\n(defun rc/phase07-diverge-restore (items)\n  (let ((total 0))\n    (dolist (item items)\n      "
     :probe-kind diverge-and-restore)
   '(:language "elisp"
     :scenario "coordination"
     :project "/home/seeback/.emacs.rc/ai/"
     :file "/home/seeback/.emacs.rc/ai/complete/ai-complete-state-rc.el"
     :snippet "\n\n;; phase07 coordination\n(defun rc/phase07-coordination (items)\n  (let ((total 0))\n    (dolist (item items)\n      "
     :probe-kind coordination))
  "Default real-call probe cases for Phase 07 wave 02 common scenario pack.")

(defconst rc/test-live-wave-02-specialized-cases
  (list
   '(:language "cpp"
     :scenario "cpp-tight-loop"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/31_跨语言骨架示例/cpp/tool_runtime.cpp"
     :snippet "\n\n// phase07 cpp-tight-loop\nstatic int rc_phase07_tight_loop(const std::vector<int>& values) {\n    int best = 0;\n    for (int value : values) {\n        if (value > best) {\n            ")
   '(:language "python"
     :scenario "python-indent-block"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/_构建工作台/30_最小可运行骨架/python_blueprint/agent_blueprint/runtime.py"
     :snippet "\n\n# phase07 python-indent-block\ndef _phase07_indent_block(items):\n    total = 0\n    for item in items:\n        if item:\n            ")
   '(:language "rust"
     :scenario "rust-borrowish-block"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claw-code/rust/crates/runtime/src/session.rs"
     :snippet "\n\n// phase07 rust-borrowish-block\nfn rc_phase07_borrowish<'a>(items: &'a [String]) -> Option<&'a str> {\n    for item in items {\n        if !item.is_empty() {\n            ")
   '(:language "ts"
     :scenario "ts-object-literal"
     :project "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/"
     :file "/home/seeback/myCode/Agent/notes/agent-architecture/参考工具代码/claude-code-build/src/tools/WebFetchTool/WebFetchTool.ts"
     :snippet "\n\n// phase07 ts-object-literal\nfunction rcPhase07ObjectLiteral(url: string) {\n  return {\n    url,\n    headers: {\n      ")
   '(:language "elisp"
     :scenario "elisp-sexp-tail"
     :project "/home/seeback/.emacs.rc/ai/"
     :file "/home/seeback/.emacs.rc/ai/complete/ai-complete-state-rc.el"
     :snippet "\n\n;; phase07 elisp-sexp-tail\n(defun rc/phase07-sexp-tail (items)\n  (when items\n    (let ((first (car items)))\n      "))
  "Default real-call probe cases for Phase 07 wave 02 specialized scenario pack.")

(defun rc/test-live--load-env ()
  "Load the full user Emacs environment once."
  (unless (featurep 'ai-rc)
    (load "/home/seeback/.emacs" nil t)))

(defun rc/test-live--case (language &optional scenario)
  "Return wave-01 case plist for LANGUAGE and optional SCENARIO."
  (let ((target-scenario (or scenario "general")))
    (seq-find
     (lambda (entry)
       (and (equal (plist-get entry :language) language)
            (equal (plist-get entry :scenario) target-scenario)))
     (append rc/test-live-wave-02-common-cases
             rc/test-live-wave-02-specialized-cases
             rc/test-live-wave-01-cases))))

(defun rc/test-live--wait-until-settled (timeout)
  "Wait until inline completion becomes visible or terminal.
Return a plist describing the observed terminal condition."
  (let ((deadline (+ (float-time) timeout))
        done)
    (while (and (not done)
                (< (float-time) deadline))
      (accept-process-output nil 0.2)
      (setq done
            (or (and (fboundp 'gptel-autocomplete-visible-p)
                     (gptel-autocomplete-visible-p)
                     'visible)
                (and (fboundp 'gptel-autocomplete-last-error)
                     (gptel-autocomplete-last-error)
                     'error)
                (and (fboundp 'gptel-autocomplete-active-request-id)
                     (not (gptel-autocomplete-active-request-id))
                     (fboundp 'gptel-autocomplete-state)
                     (memq (gptel-autocomplete-state)
                           '(failed followup-ready idle ignored))
                     'settled))))
    (list :reason done
          :timed-out (not done)
          :state (and (fboundp 'gptel-autocomplete-state)
                      (gptel-autocomplete-state))
          :visible (and (fboundp 'gptel-autocomplete-visible-p)
                        (gptel-autocomplete-visible-p))
          :active-request-id (and (fboundp 'gptel-autocomplete-active-request-id)
                                  (gptel-autocomplete-active-request-id))
          :last-error (and (fboundp 'gptel-autocomplete-last-error)
                           (gptel-autocomplete-last-error)))))

(defun rc/test-live--apply-accept (accept)
  "Apply ACCEPT action when non-nil."
  (pcase accept
    ('full (gptel-accept-completion))
    ('word (gptel-accept-word))
    ('line (gptel-accept-line))
    (_ nil)))

(defun rc/test-live--stats-value (stats key)
  "Return numeric KEY from STATS plist, defaulting to 0."
  (or (and (listp stats)
           (plist-get stats key))
      0))

(defun rc/test-live--run-until-visible (timeout &optional max-attempts)
  "Run manual completion until visible or attempts are exhausted."
  (let ((attempts 0)
        settled)
    (while (and (< attempts (or max-attempts 3))
                (not (and settled (plist-get settled :visible))))
      (setq attempts (1+ attempts))
      (when (> attempts 1)
        (rc/gptel-manual-complete))
      (setq settled (rc/test-live--wait-until-settled timeout)))
    (list :attempt-count attempts
          :settled settled
          :visible (and settled (plist-get settled :visible)))))

(defun rc/test-live--plist-like-p (value)
  "Return non-nil when VALUE looks like a property list."
  (and (listp value)
       (ignore-errors
         (and (cl-evenp (length value))
              (cl-loop for (k _v) on value by #'cddr
                       always (keywordp k))))))

(defun rc/test-live--alist-like-p (value)
  "Return non-nil when VALUE looks like an alist."
  (and (listp value)
       (seq-every-p
        (lambda (entry)
          (and (consp entry)
               (not (keywordp (car entry)))))
        value)))

(defun rc/test-live--json-ready (value)
  "Convert Lisp VALUE into a JSON-friendly tree."
  (cond
   ((or (null value) (numberp value) (stringp value)) value)
   ((keywordp value) (substring (symbol-name value) 1))
   ((symbolp value) (symbol-name value))
   ((bufferp value) (buffer-name value))
   ((markerp value) (marker-position value))
   ((hash-table-p value)
    (let (pairs)
      (maphash (lambda (k v)
                 (push (cons (format "%s" k)
                             (rc/test-live--json-ready v))
                       pairs))
               value)
      (nreverse pairs)))
   ((vectorp value)
    (vconcat (mapcar #'rc/test-live--json-ready value)))
   ((consp value)
    (cond
     ((rc/test-live--plist-like-p value)
        (mapcar (lambda (pair)
                  (cons (substring (symbol-name (car pair)) 1)
                        (rc/test-live--json-ready (cadr pair))))
                (seq-partition value 2)))
     ((rc/test-live--alist-like-p value)
     (mapcar (lambda (entry)
                (cons (format "%s" (car entry))
                      (rc/test-live--json-ready (cdr entry))))
              value))
     (t
      (vconcat (mapcar #'rc/test-live--json-ready value)))))
   (t (format "%S" value))))

(defun rc/test-live--write-file (file content)
  "Write CONTENT string to FILE, creating parent directories."
  (make-directory (file-name-directory file) t)
  (with-temp-file file
    (insert content)))

(defun rc/test-live--json-artifact-payload (result)
  "Return stable JSON payload derived from probe RESULT."
  (list :timestamp (plist-get result :timestamp)
        :language (plist-get result :language)
        :scenario (plist-get result :scenario)
        :project (plist-get result :project)
        :file (plist-get result :file)
        :major-mode (plist-get result :major-mode)
        :backend (plist-get result :backend)
        :model (plist-get result :model)
        :accept (plist-get result :accept)
        :probe-kind (plist-get result :probe-kind)
        :settled (plist-get result :settled)
        :cache-revisit (plist-get result :cache-revisit)
        :coordination (plist-get result :coordination)
        :diverge-restore (plist-get result :diverge-restore)
        :visible-text (plist-get result :visible-text)
        :prompt-diagnostics (plist-get result :prompt-diagnostics)
        :stats-report (plist-get result :stats-report)
        :trace-export (plist-get result :trace-export)
        :trace-replay (plist-get result :trace-replay)))

(defun rc/test-live--cache-revisit-probe (timeout)
  "Run a two-step cache revisit probe with TIMEOUT."
  (let* ((first-run (rc/test-live--run-until-visible timeout 3))
         (first (plist-get first-run :settled))
         (first-visible (and (fboundp 'gptel-autocomplete-last-visible-text)
                             (gptel-autocomplete-last-visible-text)))
         (first-suggestion (and (fboundp 'gptel-autocomplete-current-suggestion)
                                (gptel-autocomplete-current-suggestion)))
         (first-request-id (and first-suggestion
                                (plist-get first-suggestion :request-id)))
         (first-stats (and (fboundp 'gptel-autocomplete-stats)
                           (copy-sequence (gptel-autocomplete-stats)))))
    (gptel-clear-completion 'user-reject)
    (sit-for 0.05)
    (rc/gptel-manual-complete)
    (let* ((second (rc/test-live--wait-until-settled timeout))
           (suggestion (and (fboundp 'gptel-autocomplete-current-suggestion)
                            (gptel-autocomplete-current-suggestion)))
           (second-visible (and (fboundp 'gptel-autocomplete-last-visible-text)
                                (gptel-autocomplete-last-visible-text)))
           (second-request-id (and suggestion (plist-get suggestion :request-id)))
           (request-source (and suggestion (plist-get suggestion :request-source)))
           (cache-source (and suggestion (plist-get suggestion :cache-source)))
           (display-phase (and (fboundp 'gptel-autocomplete-display-phase)
                               (gptel-autocomplete-display-phase)))
           (stale (and (fboundp 'gptel-autocomplete-stale-p)
                       (gptel-autocomplete-stale-p)))
           (second-stats (and (fboundp 'gptel-autocomplete-stats)
                              (copy-sequence (gptel-autocomplete-stats))))
           (trace-data (and (fboundp 'rc/gptel-complete-observe-export-data)
                            (rc/gptel-complete-observe-export-data
                             (current-buffer) nil)))
           (recent-trace (plist-get trace-data :recent-trace))
           (reused-entry
            (seq-find
             (lambda (entry)
               (equal (plist-get entry :event) 'reused))
             recent-trace))
           (reused-cache-entry (and reused-entry (plist-get reused-entry :cache-entry)))
           (cache-hit-kind (or (plist-get reused-entry :cache-hit-kind)
                               (plist-get reused-cache-entry :cache-hit-kind)
                               (and suggestion (plist-get suggestion :cache-hit-kind))))
           (reused-source (or (plist-get reused-cache-entry :source)
                              cache-source))
           (request-count-delta
            (- (rc/test-live--stats-value second-stats :request-count)
               (rc/test-live--stats-value first-stats :request-count)))
           (cache-hit-delta
            (- (+ (rc/test-live--stats-value second-stats :cache-exact-hit-count)
                  (rc/test-live--stats-value second-stats :cache-prefix-hit-count))
               (+ (rc/test-live--stats-value first-stats :cache-exact-hit-count)
                  (rc/test-live--stats-value first-stats :cache-prefix-hit-count)))))
      (list :first-attempt-count (plist-get first-run :attempt-count)
            :first-settled first
            :first-visible-text first-visible
            :first-request-id first-request-id
            :first-stats first-stats
            :second-settled second
            :second-visible-text second-visible
            :second-request-id second-request-id
            :second-request-source (or (and reused-entry "cache")
                                       request-source)
            :second-cache-source reused-source
            :second-cache-hit-kind cache-hit-kind
            :second-display-phase display-phase
            :second-stale stale
            :second-network-request-p (> request-count-delta 0)
            :reused-event (and reused-entry t)
            :cache-hit-delta cache-hit-delta
            :revisit-success
            (and (plist-get first :visible)
                 (plist-get second :visible)
                 reused-entry
                 (<= request-count-delta 0))
            :trace-export-after-second trace-data))))

(defun rc/test-live--diverge-and-restore-probe (timeout)
  "Run a visible -> diverge -> restore probe with TIMEOUT."
  (let* ((first-run (rc/test-live--run-until-visible timeout 3))
         (first (plist-get first-run :settled))
         (baseline-visible (and (fboundp 'gptel-autocomplete-last-visible-text)
                                (gptel-autocomplete-last-visible-text))))
    (let ((this-command 'self-insert-command))
      (gptel--pre-command)
      (insert "x")
      (gptel--post-command-clear))
    (let* ((diverged-state (and (fboundp 'gptel-autocomplete-state)
                                (gptel-autocomplete-state)))
           (restore-available (and (fboundp 'gptel-autocomplete-restore-available-p)
                                   (gptel-autocomplete-restore-available-p)))
           (divergence-distance (and (fboundp 'gptel-autocomplete-divergence-distance)
                                     (gptel-autocomplete-divergence-distance)))
           (visible-after-diverge (and (fboundp 'gptel-autocomplete-visible-p)
                                       (gptel-autocomplete-visible-p))))
      (let ((this-command 'delete-backward-char))
        (gptel--pre-command)
        (delete-backward-char 1)
        (gptel--post-command-clear))
      (sit-for 0.05)
      (let* ((restored-state (and (fboundp 'gptel-autocomplete-state)
                                  (gptel-autocomplete-state)))
             (restore-available-after (and (fboundp 'gptel-autocomplete-restore-available-p)
                                           (gptel-autocomplete-restore-available-p)))
             (visible-after-restore (and (fboundp 'gptel-autocomplete-visible-p)
                                         (gptel-autocomplete-visible-p)))
             (restored-visible-text (and (fboundp 'gptel-autocomplete-last-visible-text)
                                         (gptel-autocomplete-last-visible-text)))
             (trace-data (and (fboundp 'rc/gptel-complete-observe-export-data)
                              (rc/gptel-complete-observe-export-data
                               (current-buffer) nil)))
             (recent-trace (plist-get trace-data :recent-trace))
             (diverged-entry
              (seq-find
               (lambda (entry)
                 (equal (plist-get entry :state) 'temporarily-diverged))
               recent-trace))
             (restored-entry
              (seq-find
               (lambda (entry)
                 (equal (plist-get entry :end-reason) 'restored-after-delete))
               recent-trace)))
        (list :first-attempt-count (plist-get first-run :attempt-count)
              :first-settled first
              :baseline-visible-text baseline-visible
              :diverged-state diverged-state
              :restore-available-during (and restore-available t)
              :divergence-distance (or divergence-distance 0)
              :visible-after-diverge (and visible-after-diverge t)
              :restored-state restored-state
              :restore-available-after (and restore-available-after t)
              :visible-after-restore (and visible-after-restore t)
              :restored-visible-text restored-visible-text
              :diverged-event (and diverged-entry t)
              :restored-event (and restored-entry t)
              :restore-success
              (and (plist-get first :visible)
                   restore-available
                   diverged-entry
                   restored-entry
                   visible-after-restore)
              :trace-export-after-restore trace-data)))))

(defun rc/test-live--coordination-probe ()
  "Run one coordination probe in the current real buffer.
Collect both a blocked manual path and a yielded company path."
  (let (blocked-reason
        blocked-trace
        blocked-yield-target
        company-yield-trace
        company-request-source
        company-aborted
        recent-trace
        snapshot
        state)
    (setq buffer-read-only t)
    (unwind-protect
        (progn
          (rc/gptel-manual-complete)
          (sit-for 0.05)
          (setq recent-trace (rc/gptel-complete-recent-trace (current-buffer)))
          (setq blocked-trace
                (seq-find
                 (lambda (entry)
                   (and (eq (plist-get entry :kind) 'suppress)
                        (eq (plist-get entry :event) 'manual-denied)))
                 recent-trace))
          (setq blocked-reason (plist-get blocked-trace :reason))
          (setq blocked-yield-target (plist-get blocked-trace :yield-target)))
      (setq buffer-read-only nil))
    (cl-letf (((symbol-function 'company--active-p) (lambda () t))
              ((symbol-function 'company-abort)
               (lambda ()
                 (setq company-aborted t)
                 t))
              ((symbol-function 'gptel-complete)
               (lambda (&optional source &rest _args)
                 (setq company-request-source source)
                 t)))
      (setq-local company-candidates '("phase07"))
      (rc/gptel-manual-complete)
      (sit-for 0.05))
    (setq recent-trace (rc/gptel-complete-recent-trace (current-buffer)))
    (setq company-yield-trace
          (seq-find
           (lambda (entry)
             (and (eq (plist-get entry :kind) 'coordination)
                  (eq (plist-get entry :event) 'yield)
                  (eq (plist-get entry :yield-target) 'company)))
           recent-trace))
    (when (fboundp 'rc/gptel-sync-complete-session-state)
      (rc/gptel-sync-complete-session-state))
    (setq state (and (fboundp 'rc/gptel-complete-session-state)
                     (copy-tree (rc/gptel-complete-session-state))))
    (setq snapshot (and (fboundp 'rc/gptel-action-current-snapshot)
                        (rc/gptel-action-current-snapshot)))
    (list :blocked-reason blocked-reason
          :blocked-yield-target blocked-yield-target
          :blocked-trace blocked-trace
          :yield-trace company-yield-trace
          :yield-target (and company-yield-trace
                             (plist-get company-yield-trace :yield-target))
          :company-aborted company-aborted
          :request-source company-request-source
          :manual-allow-after-yield
          (and state (plist-get state :environment-manual-allow))
          :snapshot-request-id (and snapshot (plist-get snapshot :request-id))
          :settled
          (list :reason 'coordination
                :state (if company-yield-trace 'yielded 'blocked)
                :visible nil
                :active-request-id nil
                :last-error nil)
          :trace-export-after-coordination
          (and (fboundp 'rc/gptel-complete-observe-export-data)
               (rc/gptel-complete-observe-export-data (current-buffer) nil)))))

(defun rc/test-live-run-probe (language &optional scenario timeout accept)
  "Run one real inline-complete probe for LANGUAGE.
SCENARIO defaults to \"general\".  TIMEOUT defaults to 45 seconds.
Optional ACCEPT may be one of `full', `word' or `line'."
  (interactive "sLanguage: ")
  (rc/test-live--load-env)
  (let* ((case (or (rc/test-live--case language scenario)
                   (user-error "Unknown live probe case: %s/%s"
                               language (or scenario "general"))))
         (timeout (or timeout 45.0))
         (accept (or accept (plist-get case :accept)))
         (probe-kind (or (plist-get case :probe-kind) 'single))
         (target-file (plist-get case :file))
         (project (plist-get case :project))
         (snippet (plist-get case :snippet))
         (buf (find-file-noselect target-file))
         result)
    (with-current-buffer buf
      (setq-local default-directory project)
      (goto-char (point-max))
      (insert snippet)
      (rc/gptel-autocomplete-setup)
      (rc/gptel-stats-reset t)
      (setq-local rc/gptel-complete-auto-trigger-mode 'off)
      (setq-local rc/gptel-complete-auto-trigger-enabled nil)
      (rc/gptel-manual-complete)
      (let* ((cache-revisit (and (eq probe-kind 'cache-revisit)
                                 (rc/test-live--cache-revisit-probe timeout)))
             (coordination (and (eq probe-kind 'coordination)
                                (rc/test-live--coordination-probe)))
             (diverge-restore (and (eq probe-kind 'diverge-and-restore)
                                   (rc/test-live--diverge-and-restore-probe timeout)))
             (settled (or (and cache-revisit
                               (plist-get cache-revisit :second-settled))
                          (and coordination
                               (plist-get coordination :settled))
                          (and diverge-restore
                               (plist-get diverge-restore :first-settled))
                          (rc/test-live--wait-until-settled timeout)))
             (visible (or (and coordination
                               (format "blocked=%s yield=%s request=%s"
                                       (or (plist-get coordination :blocked-reason) 'none)
                                       (or (plist-get coordination :yield-target) 'none)
                                       (or (plist-get coordination :request-source) 'none)))
                          (and (fboundp 'gptel-autocomplete-last-visible-text)
                               (gptel-autocomplete-last-visible-text))))
             (diag (or (and (fboundp 'gptel-autocomplete-last-prompt-diagnostics)
                            (gptel-autocomplete-last-prompt-diagnostics))
                       (plist-get (gptel--request-context) :diagnostics)))
             (trace-data nil))
        (when (and accept
                   (not coordination)
                   (plist-get settled :visible))
          (rc/test-live--apply-accept accept)
          (sit-for 0.1)
          (setq settled (append settled
                                (list :post-accept-state
                                      (and (fboundp 'gptel-autocomplete-state)
                                           (gptel-autocomplete-state))))))
        (setq trace-data
              (and (fboundp 'rc/gptel-complete-observe-export-data)
                   (rc/gptel-complete-observe-export-data
                    (current-buffer) nil)))
        (setq result
              (list :timestamp (format-time-string "%Y-%m-%d %H:%M:%S %z")
                    :language language
                    :scenario (or scenario "general")
                    :probe-kind probe-kind
                    :project project
                    :file target-file
                    :major-mode major-mode
                    :backend (format "%S" (and (boundp 'gptel-backend) gptel-backend))
                    :model (format "%S" (and (boundp 'gptel-model) gptel-model))
                    :accept accept
                    :settled settled
                    :cache-revisit cache-revisit
                    :coordination coordination
                    :diverge-restore diverge-restore
                    :visible-text visible
                    :snapshot (and (fboundp 'rc/gptel-action-current-snapshot)
                                   (rc/gptel-action-current-snapshot))
                    :prompt-diagnostics diag
                    :stats-report (rc/gptel-stats)
                    :trace-export trace-data
                    :trace-replay (and (fboundp 'rc/gptel-complete-replay-trace-summary)
                                       (rc/gptel-complete-replay-trace-summary
                                        trace-data))))))
    result))

(defun rc/test-live-write-probe-artifacts (date language &optional scenario timeout accept)
  "Run one probe and write its result under DATE."
  (interactive
   (list (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d"))
         (read-string "Language: ")
         (read-string "Scenario: " nil nil "general")))
  (let* ((history-root (or rc/test-live-calibration-history-root
                           rc/test-calibration-history-root))
         (scenario (or scenario "general")))
    (rc/test-calibration--ensure-write-allowed history-root)
    (let* ((run-dir (expand-file-name date history-root))
         (result (rc/test-live-run-probe language scenario timeout accept))
         (stats-file (expand-file-name
                      (format "stats-%s-%s.txt" language scenario)
                      run-dir))
         (trace-file (expand-file-name
                      (format "trace-%s-%s-001.json" language scenario)
                      run-dir))
         (result-file (expand-file-name
                       (format "probe-%s-%s.el" language scenario)
                       run-dir)))
      (rc/test-live--write-file stats-file (plist-get result :stats-report))
      (rc/test-live--write-file
       trace-file
       (let ((json-encoding-pretty-print t))
         (json-encode
          (rc/test-live--json-ready
           (rc/test-live--json-artifact-payload result)))))
      (rc/test-live--write-file result-file (pp-to-string result))
      (message "Wrote live probe artifacts: %s" run-dir)
      result)))

(defun rc/test-live-write-wave-01 (date &optional timeout)
  "Run the default wave-01 general probes for DATE in isolated subprocesses."
  (interactive
   (list (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d"))))
  (mapcar
   (lambda (entry)
     (let* ((language (plist-get entry :language))
            (scenario (plist-get entry :scenario))
            (expr
             (format
              "(rc/test-live-write-probe-artifacts %S %S %S %S nil)"
              date language scenario (or timeout 45.0)))
            (buffer (generate-new-buffer (format " *phase07-%s*" language)))
            exit-code
            output)
       (unwind-protect
           (progn
             (setq exit-code
                   (call-process
                    (concat invocation-directory invocation-name)
                    nil
                    buffer
                    nil
                    "--batch"
                    "-l" rc/test-live-driver-file
                    "--eval" expr))
             (with-current-buffer buffer
               (setq output (buffer-string)))
             (unless (zerop exit-code)
               (error "Wave-01 probe failed for %s:\n%s"
                      language
                      output)))
         (when (buffer-live-p buffer)
           (kill-buffer buffer)))
       (list :language language
             :scenario scenario
             :exit-code exit-code
             :output output)))
   rc/test-live-wave-01-cases))

(defun rc/test-live--write-pack (date cases timeout label)
  "Run DATE probe CASES with TIMEOUT in isolated subprocesses using LABEL."
  (mapcar
   (lambda (entry)
     (let* ((language (plist-get entry :language))
            (scenario (plist-get entry :scenario))
            (accept (plist-get entry :accept))
            (expr
             (format
              "(rc/test-live-write-probe-artifacts %S %S %S %S '%s)"
              date language scenario (or timeout 45.0) (or accept 'nil)))
            (buffer (generate-new-buffer (format " *phase07-%s-%s-%s*" label language scenario)))
            exit-code
            output)
       (unwind-protect
           (progn
             (setq exit-code
                   (call-process
                    (concat invocation-directory invocation-name)
                    nil
                    buffer
                    nil
                    "--batch"
                    "-l" rc/test-live-driver-file
                    "--eval" expr))
             (with-current-buffer buffer
               (setq output (buffer-string)))
             (unless (zerop exit-code)
               (error "%s probe failed for %s/%s:\n%s"
                      label
                      language
                      scenario
                      output)))
         (when (buffer-live-p buffer)
           (kill-buffer buffer)))
       (list :language language
             :scenario scenario
             :exit-code exit-code
             :output output)))
   cases))

(defun rc/test-live-write-wave-02-common-pack (date &optional timeout)
  "Run the default wave-02 common scenario pack for DATE in isolated subprocesses."
  (interactive
   (list (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d"))))
  (rc/test-live--write-pack date rc/test-live-wave-02-common-cases timeout "wave02-common"))

(defun rc/test-live-write-wave-02-specialized-pack (date &optional timeout)
  "Run the default wave-02 specialized scenario pack for DATE in isolated subprocesses."
  (interactive
   (list (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d"))))
  (rc/test-live--write-pack date rc/test-live-wave-02-specialized-cases timeout "wave02-specialized"))

(provide 'live-calibration-driver)
;;; live-calibration-driver.el ends here
