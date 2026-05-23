;;; ai-complete-cooldown-rc.el --- Cooldown and continuation policy -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'ai-core-rc)

(defvar rc/gptel-complete-continuation-delay 0.3
  "Seconds to wait before running automatic post-accept continuation.")

(defvar rc/gptel-complete-auto-continuation-chain-limit 3
  "Maximum number of chained automatic continuations before forcing idle.")

(defvar rc/gptel-complete-cooldown-threshold 3
  "How many repeated auto-trigger ignores are required before cooldown starts.")

(defvar rc/gptel-complete-cooldown-prefix-length 80
  "How many characters of line prefix to hash into the cooldown key.")

(defvar rc/gptel-complete-auto-jump-to-next-location nil
  "Non-nil means full accept may immediately continue into next location flow.
When enabled, the runtime will only auto-jump when there is no queued next edit.")

(defvar rc/gptel-complete-auto-jump-retrigger t
  "Non-nil means auto-jump should also retrigger inline completion.")

(defvar-local rc/gptel-complete-continuation-timer nil
  "Pending automatic continuation timer in the current buffer.")

(defvar-local rc/gptel-complete-cooldown-table nil
  "Buffer-local cooldown table keyed by contextual completion shape.")

(defvar-local rc/gptel-complete-cooldown-hit-count 0
  "How many auto triggers were suppressed by cooldown in this buffer.")

(defvar-local rc/gptel-complete-auto-continuation-chain-length 0
  "Current chained automatic continuation length in this buffer.")

(defvar-local rc/gptel-complete-forced-stop-count 0
  "How many accepts explicitly forced post-accept stop in this buffer.")

(defvar-local rc/gptel-complete-forced-followup-count 0
  "How many accepts explicitly forced follow-up in this buffer.")

(defvar-local rc/gptel-complete-continuation-stopped-by-limit-count 0
  "How many times continuation was suppressed because chain limit was reached.")

(defvar-local rc/gptel-complete-last-policy-explain nil
  "Last post-accept continuation policy explanation plist.")

(defvar-local rc/gptel-complete-pending-accept-intent nil
  "Ephemeral accept intent for the next full-accept command.")

(defun rc/gptel-cancel-complete-continuation ()
  "Cancel any pending post-accept continuation timer."
  (when (timerp rc/gptel-complete-continuation-timer)
    (cancel-timer rc/gptel-complete-continuation-timer)
    (setq rc/gptel-complete-continuation-timer nil)))

(defun rc/gptel-complete-reset-continuation-chain ()
  "Reset chained automatic continuation state for the current buffer."
  (setq rc/gptel-complete-auto-continuation-chain-length 0))

(defun rc/gptel-complete--ensure-cooldown-table ()
  "Return current buffer cooldown table."
  (unless (hash-table-p rc/gptel-complete-cooldown-table)
    (setq rc/gptel-complete-cooldown-table (make-hash-table :test #'equal)))
  rc/gptel-complete-cooldown-table)

(defun rc/gptel-complete-line-shape-class ()
  "Return a coarse line-shape class for the current point."
  (let ((line (string-trim-right
               (buffer-substring-no-properties
                (line-beginning-position)
                (point)))))
    (cond
     ((string-empty-p (string-trim line)) 'blank)
     ((string-match-p "[=:,]\\s-*$" line) 'assignment-tail)
     ((string-match-p "[({[]\\s-*$" line) 'open-delimiter)
     ((string-match-p "[.>]\\s-*$" line) 'member-tail)
     ((string-match-p "[;})\\]]\\s-*$" line) 'closed-tail)
     (t 'generic-tail))))

(defun rc/gptel-complete-current-cooldown-key ()
  "Return the cooldown key for the current point context."
  (let* ((prefix (buffer-substring-no-properties
                  (max (line-beginning-position)
                       (- (point) rc/gptel-complete-cooldown-prefix-length))
                  (point)))
         (symbol (thing-at-point 'symbol t)))
    (list :mode major-mode
          :shape (rc/gptel-complete-line-shape-class)
          :symbol (and (stringp symbol) (substring-no-properties symbol))
          :prefix-hash (sxhash prefix))))

(defun rc/gptel-complete-cooldown-entry (&optional key)
  "Return cooldown entry for KEY or current context."
  (gethash (or key (rc/gptel-complete-current-cooldown-key))
           (rc/gptel-complete--ensure-cooldown-table)))

(defun rc/gptel-complete-cooldown-active-entry ()
  "Return current cooldown entry when it is active."
  (let ((entry (rc/gptel-complete-cooldown-entry)))
    (when (and (listp entry)
               (>= (or (plist-get entry :count) 0)
                   rc/gptel-complete-cooldown-threshold))
      entry)))

(defun rc/gptel-complete-cooldown-trackable-end-reason-p (end-reason)
  "Return non-nil when END-REASON should contribute to cooldown."
  (memq end-reason '(ignored-point-move
                     ignored-typing-disagreed
                     rejected-user)))

(defun rc/gptel-complete-record-cooldown-from-lifecycle (entry)
  "Update cooldown state from normalized lifecycle ENTRY."
  (let* ((end-reason (plist-get entry :end-reason))
         (state (rc/gptel-complete-session-state))
         (request-source (plist-get state :request-source)))
    (when (and (eq request-source 'auto)
               (rc/gptel-complete-cooldown-trackable-end-reason-p end-reason))
      (let* ((key (rc/gptel-complete-current-cooldown-key))
             (table (rc/gptel-complete--ensure-cooldown-table))
             (existing (gethash key table))
             (reason-counts (rc/gptel--alist-inc
                             (or (plist-get existing :reason-counts) nil)
                             end-reason))
             (updated (list :key key
                            :count (1+ (or (plist-get existing :count) 0))
                            :last-reason end-reason
                            :reason-counts reason-counts
                            :last-request-id (plist-get entry :request-id)
                            :updated-at (float-time))))
        (puthash key updated table)))))

(defun rc/gptel-complete-cooldown-summary (&optional entry)
  "Return a readable cooldown summary string for ENTRY."
  (let ((payload (or entry (rc/gptel-complete-cooldown-active-entry))))
    (when payload
      (format "%s/%s via %s"
              (or (plist-get payload :count) 0)
              rc/gptel-complete-cooldown-threshold
              (or (plist-get payload :last-reason) 'unknown)))))

(defun rc/gptel-complete-current-accept-intent ()
  "Return current accept intent symbol."
  (or rc/gptel-complete-pending-accept-intent 'default))

(defun rc/gptel-complete-note-accept-intent (intent)
  "Record one-shot accept INTENT for the next full accept."
  (setq rc/gptel-complete-pending-accept-intent intent))

(defun rc/gptel-complete-with-accept-intent (intent fn)
  "Run FN with one-shot accept INTENT."
  (let ((rc/gptel-complete-pending-accept-intent intent))
    (unwind-protect
        (funcall fn)
      (setq rc/gptel-complete-pending-accept-intent nil))))

(defun rc/gptel-complete-current-next-policy ()
  "Return last post-accept continuation policy explanation."
  (or rc/gptel-complete-last-policy-explain
      (list :kind 'idle
            :reason 'none
            :override 'default
            :chain-length rc/gptel-complete-auto-continuation-chain-length
            :chain-limit rc/gptel-complete-auto-continuation-chain-limit
            :cooldown-active (and (rc/gptel-complete-cooldown-active-entry) t))))

(defun rc/gptel-complete-current-next-policy-label ()
  "Return concise label for the current continuation policy."
  (let ((policy (rc/gptel-complete-current-next-policy)))
    (format "%s/%s"
            (or (plist-get policy :kind) 'idle)
            (or (plist-get policy :reason) 'none))))

(defun rc/gptel-complete-set-policy-explain (policy)
  "Persist continuation POLICY explanation into runtime locals."
  (setq rc/gptel-complete-last-policy-explain policy)
  (when (fboundp 'rc/gptel-complete-session-update)
    (rc/gptel-complete-session-update
     :continuation-next-step (or (plist-get policy :kind) 'idle)
     :continuation-next-reason (plist-get policy :reason)
     :continuation-override (or (plist-get policy :override) 'default)
     :continuation-chain-length rc/gptel-complete-auto-continuation-chain-length
     :continuation-chain-limit rc/gptel-complete-auto-continuation-chain-limit
     :cooldown-active (and (rc/gptel-complete-cooldown-active-entry) t)
     :cooldown-reason (plist-get (rc/gptel-complete-cooldown-active-entry) :last-reason)
     :cooldown-summary (rc/gptel-complete-cooldown-summary)
     :cooldown-hit-count rc/gptel-complete-cooldown-hit-count
     :forced-stop-count rc/gptel-complete-forced-stop-count
     :forced-followup-count rc/gptel-complete-forced-followup-count
     :continuation-stopped-by-limit-count
     rc/gptel-complete-continuation-stopped-by-limit-count)))

(defun rc/gptel-complete-compute-next-policy (payload)
  "Return a policy plist describing the next step after accepting PAYLOAD.
Keys returned: :kind :reason :override :chain-length :chain-limit
:cooldown-active.  :kind is one of `followup', `jump' or `idle'."
  (let* ((intent (rc/gptel-complete-current-accept-intent))
         (partial (plist-get payload :partial))
         (next-edit-pending
          (and (fboundp 'gptel-autocomplete-next-edit-queue-size)
               (> (gptel-autocomplete-next-edit-queue-size) 0)))
         (cursor-target
          (and rc/gptel-complete-auto-jump-to-next-location
               (bound-and-true-p gptel-autocomplete-mode)
               (fboundp 'gptel-autocomplete-cursor-prediction-available-p)
               (gptel-autocomplete-cursor-prediction-available-p)))
         (followup-ok (rc/gptel-complete-followup-eligible-p payload))
         (cooldown (and (rc/gptel-complete-cooldown-active-entry) t))
         (chain-len rc/gptel-complete-auto-continuation-chain-length)
         (chain-limit rc/gptel-complete-auto-continuation-chain-limit)
         (over-limit (>= chain-len chain-limit))
         (override (cond
                    ((eq intent 'force-stop) 'force-stop)
                    ((eq intent 'force-followup) 'force-followup)
                    (t 'default)))
         kind reason)
    (cond
     ((eq intent 'force-stop)
      (setq kind 'idle reason 'forced-stop))
     (partial
      (setq kind 'idle reason 'partial-accept))
     ((eq intent 'force-followup)
      (setq kind 'followup reason 'forced))
     (next-edit-pending
      (setq kind 'idle reason 'has-next-edit))
     (over-limit
      (setq kind 'idle reason 'chain-limit-reached))
     (cooldown
      (setq kind 'idle reason 'cooldown))
     (cursor-target
      (setq kind 'jump reason 'cursor-prediction))
     (followup-ok
      (setq kind 'followup reason 'auto))
     (t
      (setq kind 'idle reason 'no-eligible-step)))
    (list :kind kind
          :reason reason
          :override override
          :chain-length chain-len
          :chain-limit chain-limit
          :cooldown-active cooldown)))

(defun rc/gptel-complete--apply-intent-counters (policy)
  "Update buffer-local intent counters from POLICY."
  (let ((override (plist-get policy :override))
        (reason (plist-get policy :reason)))
    (cond
     ((eq override 'force-stop)
      (cl-incf rc/gptel-complete-forced-stop-count))
     ((eq override 'force-followup)
      (cl-incf rc/gptel-complete-forced-followup-count)))
    (when (eq reason 'chain-limit-reached)
      (cl-incf rc/gptel-complete-continuation-stopped-by-limit-count))))

(defun rc/gptel-complete-after-accept-trigger (payload)
  "Schedule a follow-up completion after accepting PAYLOAD when suitable."
  (let* ((policy (rc/gptel-complete-compute-next-policy payload))
         (kind (plist-get policy :kind)))
    (rc/gptel-complete--apply-intent-counters policy)
    (rc/gptel-complete-set-policy-explain policy)
    (rc/gptel-cancel-complete-continuation)
    (cond
     ((eq kind 'followup)
      (rc/gptel-cancel-complete-followup)
      (setq rc/gptel-complete-continuation-timer
            (run-with-timer
             rc/gptel-complete-continuation-delay
             nil
             (lambda (buffer)
               (when (buffer-live-p buffer)
                 (with-current-buffer buffer
                   (setq rc/gptel-complete-continuation-timer nil)
                   (cl-incf rc/gptel-complete-auto-continuation-chain-length)
                   (rc/gptel-complete-set-policy-explain
                    (plist-put (copy-tree policy)
                               :chain-length
                               rc/gptel-complete-auto-continuation-chain-length))
                   (setq rc/gptel-complete-followup-timer
                         (run-with-timer
                          rc/gptel-complete-followup-delay
                          nil
                          #'rc/gptel-run-complete-followup
                          buffer)))))
             (current-buffer))))
     ((eq kind 'jump)
      (setq rc/gptel-complete-continuation-timer
            (run-with-timer
             rc/gptel-complete-continuation-delay
             nil
             (lambda (buffer)
               (when (buffer-live-p buffer)
                 (with-current-buffer buffer
                   (setq rc/gptel-complete-continuation-timer nil)
                   (cl-incf rc/gptel-complete-auto-continuation-chain-length)
                   (rc/gptel-complete-set-policy-explain
                    (plist-put (copy-tree policy)
                               :chain-length
                               rc/gptel-complete-auto-continuation-chain-length))
                   (rc/gptel-go-to-next-location
                    rc/gptel-complete-auto-jump-retrigger))))
             (current-buffer))))
     (t
      (rc/gptel-complete-reset-continuation-chain)))
    (setq rc/gptel-complete-pending-accept-intent nil)))

(defun rc/gptel-complete-after-accept-next-step (payload)
  "Return the preferred automatic next step after accepting PAYLOAD.
Possible return values are nil, `followup' or `jump'."
  (let ((kind (plist-get (rc/gptel-complete-compute-next-policy payload) :kind)))
    (and (memq kind '(followup jump)) kind)))

(defun rc/gptel-complete-after-accept-jump (payload)
  "Compatibility shim for older hook wiring after accepting PAYLOAD.
Jump continuation is now scheduled by `rc/gptel-complete-after-accept-trigger'."
  (ignore payload)
  nil)

(defun rc/gptel-complete-accept-with-intent (intent &optional arg)
  "Run normal accept-completion command with one-shot INTENT.
ARG mirrors any prefix argument the binding received."
  (rc/gptel-complete-with-accept-intent
   intent
   (lambda ()
     (let ((current-prefix-arg arg))
       (call-interactively #'gptel-accept-completion)))))

(provide 'ai-complete-cooldown-rc)
;;; ai-complete-cooldown-rc.el ends here
