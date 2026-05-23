;;; ai-complete-observe-rc.el --- Inline completion observability -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'ai-core-rc)
(require 'ai-action-request-rc)

(defcustom rc/gptel-complete-observe-trace-length 500
  "Maximum number of recent observability trace entries to keep."
  :type 'integer
  :group 'gptel-autocomplete)

(defvar rc/gptel-complete-global-observe-stats nil
  "Global lifetime observability counters for inline completion.")

(defvar rc/gptel-complete-global-observe-trace nil
  "Global lifetime recent observability trace for inline completion.")

(defvar rc/gptel-complete-global-request-timelines nil
  "Global request timeline table for inline completion observability.")

(defvar-local rc/gptel-complete-observe-since-reset nil
  "Buffer-local observability counters since the last reset.")

(defvar-local rc/gptel-complete-observe-trace nil
  "Buffer-local recent observability trace since the last reset.")

(defvar-local rc/gptel-complete-observe-request-timelines nil
  "Buffer-local request timeline table for inline completion observability.")

(defun rc/gptel-complete-observe--empty-stats ()
  "Return a fresh observability stats plist."
  (list :request-count 0
        :accepted-full-count 0
        :accepted-partial-count 0
        :ignored-point-move-count 0
        :ignored-buffer-edit-count 0
        :ignored-typing-disagreed-count 0
        :ignored-superseded-count 0
        :rejected-user-count 0
        :request-succeeded-count 0
        :request-failed-count 0
        :request-aborted-count 0
        :request-superseded-count 0
        :cache-exact-hit-count 0
        :cache-prefix-hit-count 0
        :cache-miss-count 0
        :temporarily-diverged-count 0
        :restored-after-delete-count 0
        :trigger-source-counts nil
        :blocked-reason-counts nil))

(defun rc/gptel-complete-observe--ensure-global ()
  "Ensure global observability containers exist."
  (unless (listp rc/gptel-complete-global-observe-stats)
    (setq rc/gptel-complete-global-observe-stats
          (rc/gptel-complete-observe--empty-stats)))
  (unless (hash-table-p rc/gptel-complete-global-request-timelines)
    (setq rc/gptel-complete-global-request-timelines
          (make-hash-table :test #'equal))))

(defun rc/gptel-complete-observe--ensure-local ()
  "Ensure buffer-local observability containers exist."
  (unless (listp rc/gptel-complete-observe-since-reset)
    (setq rc/gptel-complete-observe-since-reset
          (rc/gptel-complete-observe--empty-stats)))
  (unless (hash-table-p rc/gptel-complete-observe-request-timelines)
    (setq rc/gptel-complete-observe-request-timelines
          (make-hash-table :test #'equal))))

(defun rc/gptel-complete-observe--update-stats (stats key &optional subkey delta)
  "Return STATS with KEY updated.
When SUBKEY is non-nil, KEY is treated as an alist bucket."
  (if subkey
      (plist-put stats key
                 (rc/gptel--alist-inc
                  (plist-get stats key)
                  subkey
                  delta))
    (rc/gptel--plist-inc stats key delta)))

(defun rc/gptel-complete-observe--normalize-request-id (request-id)
  "Normalize REQUEST-ID to a stable shared form."
  (if (fboundp 'rc/gptel-complete-normalize-request-id)
      (rc/gptel-complete-normalize-request-id request-id)
    request-id))

(defun rc/gptel-complete-observe--take (items)
  "Return ITEMS truncated to the configured trace length."
  (seq-take items (max 1 rc/gptel-complete-observe-trace-length)))

(defun rc/gptel-complete-observe--track-request (table request-id props)
  "Merge PROPS into TABLE entry for REQUEST-ID and return updated entry."
  (let* ((key (rc/gptel-complete-observe--normalize-request-id request-id))
         (current (copy-tree (or (gethash key table) (list :request-id key))))
         (cursor props))
    (while cursor
      (setq current (plist-put current (pop cursor) (pop cursor))))
    (puthash key current table)
    current))

(defun rc/gptel-complete-observe--request-timelines-as-list (table)
  "Return TABLE timelines as a reverse-chronological list."
  (let (rows)
    (maphash (lambda (_key value)
               (push (copy-tree value) rows))
             table)
    (sort rows
          (lambda (a b)
            (> (or (plist-get a :started-at)
                   (plist-get a :completed-at)
                   0)
               (or (plist-get b :started-at)
                   (plist-get b :completed-at)
                   0))))))

(defun rc/gptel-complete-current-buffer-observe-stats ()
  "Return current buffer observability counters since reset."
  (rc/gptel-complete-observe--ensure-local)
  (copy-tree rc/gptel-complete-observe-since-reset))

(defun rc/gptel-complete-global-observe-stats ()
  "Return global lifetime observability counters."
  (rc/gptel-complete-observe--ensure-global)
  (copy-tree rc/gptel-complete-global-observe-stats))

(defun rc/gptel-complete-recent-trace (&optional buffer)
  "Return recent trace entries for BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    (rc/gptel-complete-observe--ensure-local)
    (copy-tree rc/gptel-complete-observe-trace)))

(defun rc/gptel-complete-request-timelines (&optional buffer global)
  "Return request timelines for BUFFER.
When GLOBAL is non-nil, return global lifetime timelines."
  (if global
      (progn
        (rc/gptel-complete-observe--ensure-global)
        (rc/gptel-complete-observe--request-timelines-as-list
         rc/gptel-complete-global-request-timelines))
    (with-current-buffer (or buffer (current-buffer))
      (rc/gptel-complete-observe--ensure-local)
      (rc/gptel-complete-observe--request-timelines-as-list
       rc/gptel-complete-observe-request-timelines))))

(defun rc/gptel-complete-observe--push-trace (entry)
  "Record observability ENTRY into local and global trace."
  (rc/gptel-complete-observe--ensure-local)
  (rc/gptel-complete-observe--ensure-global)
  (push entry rc/gptel-complete-observe-trace)
  (setq rc/gptel-complete-observe-trace
        (rc/gptel-complete-observe--take rc/gptel-complete-observe-trace))
  (push entry rc/gptel-complete-global-observe-trace)
  (setq rc/gptel-complete-global-observe-trace
        (rc/gptel-complete-observe--take rc/gptel-complete-global-observe-trace)))

(defun rc/gptel-complete-observe-record-trace (kind props)
  "Record trace entry of KIND merged with PROPS."
  (rc/gptel-complete-observe--push-trace
   (append (list :kind kind
                 :buffer (buffer-name)
                 :major-mode major-mode
                 :timestamp (float-time))
           props)))

(defun rc/gptel-complete-observe--mark-request-outcome (request-id outcome timestamp source)
  "Mark REQUEST-ID OUTCOME at TIMESTAMP and SOURCE in both timeline tables."
  (dolist (table (list rc/gptel-complete-observe-request-timelines
                       rc/gptel-complete-global-request-timelines))
    (when (hash-table-p table)
      (let ((current (gethash (rc/gptel-complete-observe--normalize-request-id request-id) table)))
        (unless (plist-get current :outcome)
          (rc/gptel-complete-observe--track-request
           table
           request-id
           (list :completed-at timestamp
                 :first-stream-at (or (plist-get current :first-stream-at) timestamp)
                 :outcome outcome
                 :request-source source)))))))

(defun rc/gptel-complete-observe--record-stats (entry)
  "Update observability counters using lifecycle ENTRY."
  (let* ((event (plist-get entry :event))
         (end-reason (plist-get entry :end-reason))
         (state (plist-get entry :state))
         (source (or (plist-get entry :source)
                     (plist-get entry :request-source)))
         (timestamp (or (plist-get entry :timestamp) (float-time)))
         (request-id (plist-get entry :request-id))
         (local rc/gptel-complete-observe-since-reset)
         (global rc/gptel-complete-global-observe-stats))
    (pcase event
      ('request-started
       (setq local (rc/gptel-complete-observe--update-stats local :request-count))
       (setq local (rc/gptel-complete-observe--update-stats local :cache-miss-count))
       (setq global (rc/gptel-complete-observe--update-stats global :request-count))
       (setq global (rc/gptel-complete-observe--update-stats global :cache-miss-count))
       (when source
         (setq local
               (rc/gptel-complete-observe--update-stats
                local :trigger-source-counts source))
         (setq global
               (rc/gptel-complete-observe--update-stats
                global :trigger-source-counts source)))
       (dolist (table (list rc/gptel-complete-observe-request-timelines
                            rc/gptel-complete-global-request-timelines))
         (rc/gptel-complete-observe--track-request
          table request-id
          (list :request-id (rc/gptel-complete-observe--normalize-request-id request-id)
                :started-at timestamp
                :request-source source
                :buffer (buffer-name)))))
      ('reused
       (setq local (rc/gptel-complete-observe--update-stats local :cache-exact-hit-count))
       (setq global (rc/gptel-complete-observe--update-stats global :cache-exact-hit-count)))
      ((or 'visible 'candidate-visible 'followup-visible)
       (dolist (table (list rc/gptel-complete-observe-request-timelines
                            rc/gptel-complete-global-request-timelines))
         (let ((current (gethash (rc/gptel-complete-observe--normalize-request-id request-id) table)))
           (when current
             (rc/gptel-complete-observe--track-request
              table request-id
              (list :first-stream-at (or (plist-get current :first-stream-at) timestamp)))
             (unless (plist-get current :outcome)
               (rc/gptel-complete-observe--track-request
                table request-id
                (list :completed-at timestamp
                      :outcome 'succeeded
                      :request-source (or (plist-get current :request-source) source)))))))
       (when (and source (not (eq source 'cache)))
         (setq local (rc/gptel-complete-observe--update-stats local :request-succeeded-count))
         (setq global (rc/gptel-complete-observe--update-stats global :request-succeeded-count))))
      ('request-skipped
       (when (plist-get entry :reason)
         (setq local
               (rc/gptel-complete-observe--update-stats
                local :blocked-reason-counts (plist-get entry :reason)))
         (setq global
               (rc/gptel-complete-observe--update-stats
                global :blocked-reason-counts (plist-get entry :reason))))))
    (when (eq state 'temporarily-diverged)
      (setq local (rc/gptel-complete-observe--update-stats local :temporarily-diverged-count))
      (setq global (rc/gptel-complete-observe--update-stats global :temporarily-diverged-count)))
    (pcase end-reason
      ('accepted-full
       (setq local (rc/gptel-complete-observe--update-stats local :accepted-full-count))
       (setq global (rc/gptel-complete-observe--update-stats global :accepted-full-count)))
      ((or 'accepted-word 'accepted-line)
       (setq local (rc/gptel-complete-observe--update-stats local :accepted-partial-count))
       (setq global (rc/gptel-complete-observe--update-stats global :accepted-partial-count)))
      ('ignored-point-move
       (setq local (rc/gptel-complete-observe--update-stats local :ignored-point-move-count))
       (setq global (rc/gptel-complete-observe--update-stats global :ignored-point-move-count)))
      ('ignored-buffer-edit
       (setq local (rc/gptel-complete-observe--update-stats local :ignored-buffer-edit-count))
       (setq global (rc/gptel-complete-observe--update-stats global :ignored-buffer-edit-count)))
      ('ignored-typing-disagreed
       (setq local (rc/gptel-complete-observe--update-stats local :ignored-typing-disagreed-count))
       (setq global (rc/gptel-complete-observe--update-stats global :ignored-typing-disagreed-count)))
      ('ignored-superseded
       (setq local (rc/gptel-complete-observe--update-stats local :ignored-superseded-count))
       (setq global (rc/gptel-complete-observe--update-stats global :ignored-superseded-count))
       (setq local (rc/gptel-complete-observe--update-stats local :request-superseded-count))
       (setq global (rc/gptel-complete-observe--update-stats global :request-superseded-count))
       (rc/gptel-complete-observe--mark-request-outcome request-id 'superseded timestamp source))
      ('rejected-user
       (setq local (rc/gptel-complete-observe--update-stats local :rejected-user-count))
       (setq global (rc/gptel-complete-observe--update-stats global :rejected-user-count)))
      ('restored-after-delete
       (setq local (rc/gptel-complete-observe--update-stats local :restored-after-delete-count))
       (setq global (rc/gptel-complete-observe--update-stats global :restored-after-delete-count)))
      ((or 'failed-request 'failed-empty)
       (setq local (rc/gptel-complete-observe--update-stats local :request-failed-count))
       (setq global (rc/gptel-complete-observe--update-stats global :request-failed-count))
       (rc/gptel-complete-observe--mark-request-outcome request-id 'failed timestamp source))
      ('aborted-request
       (setq local (rc/gptel-complete-observe--update-stats local :request-aborted-count))
       (setq global (rc/gptel-complete-observe--update-stats global :request-aborted-count))
       (rc/gptel-complete-observe--mark-request-outcome request-id 'aborted timestamp source)))
    (setq rc/gptel-complete-observe-since-reset local
          rc/gptel-complete-global-observe-stats global)))

(defun rc/gptel-complete-observe-lifecycle-hook (payload)
  "Record completion lifecycle PAYLOAD for observability."
  (rc/gptel-complete-observe--ensure-local)
  (rc/gptel-complete-observe--ensure-global)
  (let* ((entry (if (fboundp 'rc/gptel-complete-normalize-entry)
                    (rc/gptel-complete-normalize-entry payload)
                  payload))
         (record (append
                  (list :kind 'lifecycle
                        :buffer (buffer-name)
                        :major-mode major-mode)
                  entry)))
    (rc/gptel-complete-observe--record-stats record)
    (rc/gptel-complete-observe--push-trace record)))

(defun rc/gptel-install-complete-observe-hooks ()
  "Install observability hooks for inline completion."
  (rc/gptel-ensure-autocomplete)
  (add-hook 'gptel-autocomplete-lifecycle-hook
            #'rc/gptel-complete-observe-lifecycle-hook))

(defun rc/gptel-complete-observe-reset-buffer ()
  "Reset current buffer observability counters and trace."
  (setq rc/gptel-complete-observe-since-reset
        (rc/gptel-complete-observe--empty-stats)
        rc/gptel-complete-observe-trace nil
        rc/gptel-complete-observe-request-timelines
        (make-hash-table :test #'equal)))

(defun rc/gptel-complete-observe-reset-global ()
  "Reset global inline completion observability counters and trace."
  (setq rc/gptel-complete-global-observe-stats
        (rc/gptel-complete-observe--empty-stats)
        rc/gptel-complete-global-observe-trace nil
        rc/gptel-complete-global-request-timelines
        (make-hash-table :test #'equal)))

(defun rc/gptel-stats-reset (&optional global)
  "Reset current buffer stats and trace.
With GLOBAL non-nil, also reset global lifetime aggregates."
  (interactive "P")
  (rc/gptel-complete-observe-reset-buffer)
  (when global
    (rc/gptel-complete-observe-reset-global))
  (when (called-interactively-p 'interactive)
    (message "已重置 %sAI 统计"
             (if global "当前 buffer 与全局 " "当前 buffer "))))

(defun rc/gptel-complete-observe--sorted-values (numbers)
  "Return NUMBERS as an ascending sorted copy."
  (sort (copy-sequence (delq nil numbers)) #'<))

(defun rc/gptel-complete-observe--percentile (numbers ratio)
  "Return percentile from NUMBERS using RATIO."
  (let ((sorted (rc/gptel-complete-observe--sorted-values numbers)))
    (when sorted
      (nth (min (1- (length sorted))
                (max 0 (floor (* ratio (1- (length sorted))))))
           sorted))))

(defun rc/gptel-complete-observe--latency-summary (timelines)
  "Return latency summary plist for TIMELINES."
  (let (complete-latencies first-latencies)
    (dolist (entry timelines)
      (let ((started (plist-get entry :started-at))
            (first (plist-get entry :first-stream-at))
            (completed (plist-get entry :completed-at)))
        (when (and started completed (>= completed started))
          (push (- completed started) complete-latencies))
        (when (and started first (>= first started))
          (push (- first started) first-latencies))))
    (list :complete-count (length complete-latencies)
          :complete-p50 (rc/gptel-complete-observe--percentile complete-latencies 0.50)
          :complete-p95 (rc/gptel-complete-observe--percentile complete-latencies 0.95)
          :first-count (length first-latencies)
          :first-p50 (rc/gptel-complete-observe--percentile first-latencies 0.50)
          :first-p95 (rc/gptel-complete-observe--percentile first-latencies 0.95))))

(defun rc/gptel-complete-observe--format-counts (alist)
  "Return a readable string from count ALIST."
  (if alist
      (mapconcat
       (lambda (pair) (format "%s=%s" (car pair) (cdr pair)))
       (sort (copy-sequence alist)
             (lambda (a b) (> (cdr a) (cdr b))))
       ", ")
    "none"))

(defun rc/gptel-complete-stats-report (&optional buffer)
  "Return a human-readable stats report for BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    (rc/gptel-complete-observe--ensure-local)
    (rc/gptel-complete-observe--ensure-global)
    (let* ((local rc/gptel-complete-observe-since-reset)
           (global rc/gptel-complete-global-observe-stats)
           (local-latency
            (rc/gptel-complete-observe--latency-summary
             (rc/gptel-complete-request-timelines (current-buffer))))
           (global-latency
            (rc/gptel-complete-observe--latency-summary
             (rc/gptel-complete-request-timelines nil t))))
      (string-join
       (list
        (format "AI Complete Stats: %s" (buffer-name))
        ""
        "Current Buffer (since reset):"
        (format "  requests=%s succeeded=%s failed=%s aborted=%s superseded=%s"
                (plist-get local :request-count)
                (plist-get local :request-succeeded-count)
                (plist-get local :request-failed-count)
                (plist-get local :request-aborted-count)
                (plist-get local :request-superseded-count))
        (format "  accept full=%s partial=%s"
                (plist-get local :accepted-full-count)
                (plist-get local :accepted-partial-count))
        (format "  ignore move=%s edit=%s disagree=%s superseded=%s reject=%s"
                (plist-get local :ignored-point-move-count)
                (plist-get local :ignored-buffer-edit-count)
                (plist-get local :ignored-typing-disagreed-count)
                (plist-get local :ignored-superseded-count)
                (plist-get local :rejected-user-count))
        (format "  cache exact=%s prefix=%s miss=%s"
                (plist-get local :cache-exact-hit-count)
                (plist-get local :cache-prefix-hit-count)
                (plist-get local :cache-miss-count))
        (format "  divergence temp=%s restored=%s"
                (plist-get local :temporarily-diverged-count)
                (plist-get local :restored-after-delete-count))
        (format "  latency first p50=%s p95=%s complete p50=%s p95=%s"
                (or (plist-get local-latency :first-p50) "n/a")
                (or (plist-get local-latency :first-p95) "n/a")
                (or (plist-get local-latency :complete-p50) "n/a")
                (or (plist-get local-latency :complete-p95) "n/a"))
        (format "  trigger-sources: %s"
                (rc/gptel-complete-observe--format-counts
                 (plist-get local :trigger-source-counts)))
        (format "  blocked-reasons: %s"
                (rc/gptel-complete-observe--format-counts
                 (plist-get local :blocked-reason-counts)))
        ""
        "Global Lifetime:"
        (format "  requests=%s succeeded=%s failed=%s aborted=%s superseded=%s"
                (plist-get global :request-count)
                (plist-get global :request-succeeded-count)
                (plist-get global :request-failed-count)
                (plist-get global :request-aborted-count)
                (plist-get global :request-superseded-count))
        (format "  accept full=%s partial=%s"
                (plist-get global :accepted-full-count)
                (plist-get global :accepted-partial-count))
        (format "  cache exact=%s prefix=%s miss=%s"
                (plist-get global :cache-exact-hit-count)
                (plist-get global :cache-prefix-hit-count)
                (plist-get global :cache-miss-count))
        (format "  latency first p50=%s p95=%s complete p50=%s p95=%s"
                (or (plist-get global-latency :first-p50) "n/a")
                (or (plist-get global-latency :first-p95) "n/a")
                (or (plist-get global-latency :complete-p50) "n/a")
                (or (plist-get global-latency :complete-p95) "n/a"))
        (format "  trigger-sources: %s"
                (rc/gptel-complete-observe--format-counts
                 (plist-get global :trigger-source-counts))))
       "\n"))))

(defun rc/gptel-stats (&optional buffer)
  "Show current buffer and global completion stats for BUFFER."
  (interactive)
  (let ((report (rc/gptel-complete-stats-report buffer)))
    (if (called-interactively-p 'interactive)
        (with-help-window "*AI Complete Stats*"
          (princ report))
      report)))

(defun rc/gptel-complete-observe--redact-string (value &optional raw)
  "Return VALUE redacted unless RAW is non-nil."
  (cond
   ((not (stringp value)) value)
   (raw value)
   ((<= (length value) 40) value)
   (t (concat (substring value 0 40) "…[redacted]"))))

(defun rc/gptel-complete-observe--sanitize-plist (plist &optional raw)
  "Return sanitized copy of PLIST.
Prompt-heavy fields are redacted unless RAW is non-nil."
  (let ((copy (copy-tree plist)))
    (dolist (key '(:prompt :system :text :before :after :full :completion-text :display))
      (when (plist-member copy key)
        (setq copy (plist-put copy key
                              (rc/gptel-complete-observe--redact-string
                               (plist-get copy key)
                               raw)))))
    copy))

(defun rc/gptel-complete-observe--request-history-export (&optional buffer raw)
  "Return sanitized complete request history for BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    (mapcar
     (lambda (entry)
       (rc/gptel-complete-observe--sanitize-plist
        (copy-tree entry)
        raw))
     (seq-filter
      (lambda (entry)
        (eq (plist-get entry :action-kind) 'complete))
      (or (rc/gptel-action-request-history) nil)))))

(defun rc/gptel-complete-observe-export-data (&optional buffer raw)
  "Return exportable observability payload for BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    (list :buffer (buffer-name)
          :major-mode major-mode
          :since-reset (rc/gptel-complete-current-buffer-observe-stats)
          :global-lifetime (rc/gptel-complete-global-observe-stats)
          :request-timelines (rc/gptel-complete-request-timelines (current-buffer))
          :recent-trace
          (mapcar (lambda (entry)
                    (rc/gptel-complete-observe--sanitize-plist entry raw))
                  (rc/gptel-complete-recent-trace (current-buffer)))
          :request-history
          (rc/gptel-complete-observe--request-history-export (current-buffer) raw))))

(defun rc/gptel-complete-observe--markdown-table (rows)
  "Render ROWS as a compact Markdown table."
  (let ((header "| ts | kind | event | state | request | source | end |\n| --- | --- | --- | --- | --- | --- | --- |"))
    (concat
     header
     "\n"
     (mapconcat
      (lambda (entry)
        (format "| %s | %s | %s | %s | %s | %s | %s |"
                (or (plist-get entry :timestamp) "")
                (or (plist-get entry :kind) "")
                (or (plist-get entry :event) "")
                (or (plist-get entry :state) "")
                (or (plist-get entry :request-id) "")
                (or (plist-get entry :source)
                    (plist-get entry :request-source)
                    "")
                (or (plist-get entry :end-reason) "")))
      rows
      "\n"))))

(defun rc/gptel-export-recent-ai-trace (&optional format raw buffer)
  "Export recent complete trace for BUFFER.
FORMAT defaults to `elisp'. When RAW is non-nil, disable prompt redaction."
  (interactive)
  (let* ((target (or buffer (current-buffer)))
         (data (rc/gptel-complete-observe-export-data target raw))
         (payload
          (pcase (or format 'elisp)
            ('markdown
             (string-join
              (list
               (format "# AI Trace: %s" (plist-get data :buffer))
               ""
               "## Recent Trace"
               (rc/gptel-complete-observe--markdown-table
                (plist-get data :recent-trace)))
              "\n"))
            (_ (pp-to-string data)))))
    (if (called-interactively-p 'interactive)
        (with-help-window "*AI Recent Trace*"
          (princ payload))
      payload)))

(defun rc/gptel-complete-replay-trace-summary (&optional data)
  "Return replay summary plist from exported trace DATA."
  (let* ((payload (cond
                   ((null data)
                    (rc/gptel-complete-observe-export-data (current-buffer) nil))
                   ((stringp data)
                    (car (read-from-string data)))
                   (t data)))
         (trace (copy-tree (plist-get payload :recent-trace)))
         request-starts callbacks transitions finals suppressions timers)
    (dolist (entry trace)
      (pcase (plist-get entry :kind)
        ('lifecycle
         (when (eq (plist-get entry :event) 'request-started)
           (push entry request-starts))
         (when (memq (plist-get entry :event) '(visible candidate-visible followup-visible))
           (push entry callbacks))
         (when (eq (plist-get entry :event) 'finalized)
           (push entry finals)))
        ('suppress
         (push entry suppressions))
        ('timer
         (push entry timers)))
      (when (plist-get entry :previous-state)
        (push entry transitions)))
    (list :buffer (plist-get payload :buffer)
          :major-mode (plist-get payload :major-mode)
          :request-start-count (length request-starts)
          :callback-order (nreverse
                           (mapcar (lambda (entry)
                                     (list :event (plist-get entry :event)
                                           :request-id (plist-get entry :request-id)
                                           :state (plist-get entry :state)))
                                   callbacks))
          :state-transitions (nreverse
                              (mapcar (lambda (entry)
                                        (list :from (plist-get entry :previous-state)
                                              :to (plist-get entry :state)
                                              :event (plist-get entry :event)
                                              :request-id (plist-get entry :request-id)))
                                      transitions))
          :final-end-reason (plist-get (car finals) :end-reason)
          :final-state (plist-get (car finals) :state)
          :suppress-reasons (nreverse
                             (mapcar (lambda (entry)
                                       (list :reason (plist-get entry :reason)
                                             :trigger-kind (plist-get entry :trigger-kind)
                                             :yield-target (plist-get entry :yield-target)
                                             :org-src (plist-get entry :org-src)))
                                     suppressions))
          :timer-events (nreverse
                         (mapcar (lambda (entry)
                                   (list :event (plist-get entry :event)
                                         :trigger-kind (plist-get entry :trigger-kind)
                                         :token (plist-get entry :token)))
                                 timers)))))

(defun rc/gptel--format-replay-lines (summary)
  "Return formatted replay lines from SUMMARY."
  (string-join
   (delq nil
         (list
          (format "AI Trace Replay: %s" (or (plist-get summary :buffer) "unknown"))
          (format "major-mode: %s" (or (plist-get summary :major-mode) 'unknown))
          (format "request-starts: %s" (or (plist-get summary :request-start-count) 0))
          (format "final-state: %s" (or (plist-get summary :final-state) 'none))
          (format "final-end-reason: %s" (or (plist-get summary :final-end-reason) 'none))
          (format "suppressions: %s"
                  (if-let ((items (plist-get summary :suppress-reasons)))
                      (mapconcat
                       (lambda (entry)
                         (format "%s/%s"
                                 (or (plist-get entry :trigger-kind) 'unknown)
                                 (or (plist-get entry :reason) 'none)))
                       items
                       ", ")
                    "none"))
          (format "timers: %s"
                  (if-let ((items (plist-get summary :timer-events)))
                      (mapconcat
                       (lambda (entry)
                         (format "%s/%s"
                                 (or (plist-get entry :trigger-kind) 'unknown)
                                 (or (plist-get entry :event) 'none)))
                       items
                       ", ")
                    "none"))))
   "\n"))

(defun rc/gptel-replay-ai-trace (&optional data buffer)
  "Replay exported inline-complete trace DATA for BUFFER.
When DATA is nil, replay current BUFFER's recent trace."
  (interactive)
  (let ((summary (with-current-buffer (or buffer (current-buffer))
                   (rc/gptel-complete-replay-trace-summary data))))
    (if (called-interactively-p 'interactive)
        (with-help-window "*AI Trace Replay*"
          (princ (rc/gptel--format-replay-lines summary)))
      summary)))

(provide 'ai-complete-observe-rc)
;;; ai-complete-observe-rc.el ends here
