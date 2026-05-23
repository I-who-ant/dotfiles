;;; ai-complete-state-rc.el --- Inline completion session state -*- lexical-binding: t; -*-

;;; Code:

(require 'seq)
(require 'subr-x)

(defvar-local rc/gptel-complete-session-state nil
  "Buffer-local state plist for inline completion workflow.")

(defconst rc/gptel-complete-final-states
  '(ignored accepted rejected superseded cached reused followup-ready failed aborted idle)
  "Stable completion states exposed by the rc-layer.")

(defun rc/gptel-complete-normalize-request-id (request-id)
  "Normalize complete REQUEST-ID to a stable shared string form."
  (cond
   ((null request-id) nil)
   ((numberp request-id) (format "complete-%d" request-id))
   ((and (stringp request-id)
         (string-prefix-p "followup-" request-id))
    (format "complete-%s" request-id))
   ((and (stringp request-id)
         (string-match-p "\\`[0-9]+\\'" request-id))
    (format "complete-%s" request-id))
   (t request-id)))

(defun rc/gptel-complete-normalize-end-reason (end-reason)
  "Normalize END-REASON from gptel-autocomplete to the rc contract."
  (pcase end-reason
    ((or 'accepted-full 'accepted-word 'accepted-line
         'rejected-user
         'ignored-point-move
         'ignored-buffer-edit
         'ignored-typing-disagreed
         'ignored-superseded
         'failed-empty
         'failed-request
         'aborted-request
         'restored-after-delete
         'cleared-mode-disabled)
     end-reason)
    ('accepted-line-finished 'accepted-line)
    ('accepted-word-finished 'accepted-word)
    ('mode-disabled 'cleared-mode-disabled)
    ('user-reject 'rejected-user)
    ('new-request 'ignored-superseded)
    (_ end-reason)))

(defun rc/gptel-complete-normalize-state (state &optional end-reason)
  "Normalize completion STATE using END-REASON when needed."
  (let ((normalized-end (rc/gptel-complete-normalize-end-reason end-reason)))
    (pcase state
      ((or 'idle 'requesting 'visible
           'pending-accept 'pending-reject 'pending-request
           'pending-delete 'pending-move
           'partial-accepted 'temporarily-diverged
           'ignored 'accepted 'rejected 'superseded
           'cached 'reused 'followup-ready 'failed 'aborted)
       state)
      ('invalidated
       (if (memq normalized-end '(ignored-point-move
                                  ignored-buffer-edit
                                  ignored-typing-disagreed))
           'ignored
         'temporarily-diverged))
      ('mode-disabled 'idle)
      ('ready 'visible)
      (_
       (pcase normalized-end
         ((or 'accepted-full 'accepted-word 'accepted-line) 'accepted)
         ('rejected-user 'rejected)
         ((or 'ignored-point-move
              'ignored-buffer-edit
              'ignored-typing-disagreed) 'ignored)
         ('ignored-superseded 'superseded)
         ((or 'failed-empty 'failed-request) 'failed)
         ('aborted-request 'aborted)
         ('restored-after-delete 'visible)
         ('cleared-mode-disabled 'idle)
         (_ (or state 'idle)))))))

(defun rc/gptel-complete-normalize-lifecycle-event (event end-reason)
  "Normalize lifecycle EVENT using END-REASON."
  (or
   (pcase event
     ((or 'request-started
          'visible
          'candidate-visible
          'followup-visible
          'partial-accepted
          'temporarily-diverged
          'followup-ready
          'reused
          'cached
          'superseded
          'pre-command-accept
          'pre-command-reject
          'pre-command-request
          'pre-command-delete
          'pre-command-move
          'finalized)
      event)
     ((or 'forward-stable 'forward-stable-delete) 'visible)
     ('forward-stable-restored 'finalized)
     ('request-failed 'finalized)
     ('request-aborted 'finalized)
     ('rejected 'finalized)
     ('invalidated-move 'finalized)
     ('invalidated-edit 'finalized)
     ('mode-disabled 'finalized)
     ('accepted-finished 'finalized)
     ('accepted-line-finished 'finalized)
     ('accepted-word-finished 'finalized)
     (_ nil))
   (and end-reason 'finalized)
   event))

(defun rc/gptel-complete-normalize-entry (entry)
  "Normalize one lifecycle or transition ENTRY to the rc contract."
  (when (listp entry)
    (let* ((end-reason (rc/gptel-complete-normalize-end-reason
                        (plist-get entry :end-reason)))
           (event (rc/gptel-complete-normalize-lifecycle-event
                   (plist-get entry :event)
                   end-reason))
           (state (rc/gptel-complete-normalize-state
                   (plist-get entry :state)
                   end-reason))
           (previous-state (and (plist-member entry :previous-state)
                                (rc/gptel-complete-normalize-state
                                 (plist-get entry :previous-state)
                                 nil)))
           (rest nil)
           (cursor entry))
      (while cursor
        (let ((key (pop cursor))
              (value (pop cursor)))
          (unless (memq key '(:event :state :end-reason :previous-state))
            (setq rest (append rest (list key value))))))
      (append
       (list :event event
             :state state
             :end-reason end-reason)
       (when (plist-member entry :request-id)
         (list :request-id
               (rc/gptel-complete-normalize-request-id
                (plist-get entry :request-id))))
       (when (plist-member entry :previous-state)
         (list :previous-state previous-state))
       rest))))

(defun rc/gptel-complete-normalize-history (history)
  "Normalize completion HISTORY entries to the rc contract."
  (delq nil (mapcar #'rc/gptel-complete-normalize-entry history)))

(defun rc/gptel-complete-fill-history-request-id (history request-id)
  "Fill missing REQUEST-ID in completion HISTORY entries."
  (mapcar
   (lambda (entry)
     (if (or (not request-id)
             (not (listp entry))
             (plist-get entry :request-id))
         entry
       (append entry (list :request-id request-id))))
   history))

(defun rc/gptel-complete-current-suggestion-snapshot ()
  "Return a normalized copy of the current public suggestion object."
  (when (fboundp 'gptel-autocomplete-current-suggestion)
    (let ((suggestion (gptel-autocomplete-current-suggestion)))
      (when (listp suggestion)
        (let* ((copy (copy-tree suggestion))
               (end-reason (rc/gptel-complete-normalize-end-reason
                            (plist-get copy :last-end-reason))))
          (plist-put copy :request-id
                     (rc/gptel-complete-normalize-request-id
                      (plist-get copy :request-id)))
          (plist-put copy :superseded-by
                     (rc/gptel-complete-normalize-request-id
                      (plist-get copy :superseded-by)))
          (plist-put copy :state
                     (rc/gptel-complete-normalize-state
                      (plist-get copy :state)
                      end-reason))
          (plist-put copy :last-end-reason end-reason)
          (plist-put copy :recent-events
                     (rc/gptel-complete-normalize-history
                      (plist-get copy :recent-events)))
          copy)))))

(defun rc/gptel-complete-session-reset ()
  "Reset buffer-local inline completion session state."
  (setq rc/gptel-complete-session-state
        (list :visible nil
              :state 'idle
              :end-reason nil
              :suggestion-id nil
              :suggestion nil
              :state-history nil
              :request-id nil
              :request-source nil
              :request-logical-outcome nil
              :request-transport-outcome nil
              :request-supersede-strategy nil
              :trigger-source nil
              :last-result nil
              :last-lifecycle-event nil
              :lifecycle-history nil
              :current-profile nil
              :superseded-ids nil
              :cache-size 0
              :cache-source nil
              :cache-followup-count 0
              :cache-candidate-count 0
              :candidate-count 0
              :candidate-index 0
              :next-edit-id nil
              :next-edit-queue-size 0
              :cursor-prediction-target-id nil
              :cursor-prediction-target-point nil
              :cursor-prediction-target-available nil
              :next-action-kind 'none
              :next-action-count 0
              :restore-available nil
              :divergence-distance 0
              :last-error nil
              :last-visible-text nil
              :last-command-kind nil
              :display-phase 'idle
              :display-stale nil
              :requesting-indicator-visible nil
              :requesting-indicator-reason nil
              :status-indicator nil
              :environment-auto-allow nil
              :environment-manual-allow nil
              :environment-suppress-reason nil
              :environment-yield-target nil
              :environment-org-src nil
              :accepted-length 0
              :accepted-kind nil
              :recent-events nil
              :stats nil
              :accepted-count 0
              :partial-accepted-count 0
              :auto-triggered-count 0
              :followup-triggered-count 0
              :followup-queue-size 0
              :forward-stable-count 0
              :restored-count 0
              :temporarily-diverged-count 0
              :cache-hit-count 0
              :superseded-count 0
              :aborted-count 0
              :rejected-count 0
              :ignored-count 0
              :ignored-point-move-count 0
              :ignored-buffer-edit-count 0
              :ignored-superseded-count 0
              :ignored-typing-disagreed-count 0
              :invalidated-move-count 0
              :invalidated-edit-count 0
              :mode-disabled-count 0
              :last-accept-kind nil
              :last-accept nil)))

(defun rc/gptel-complete-session-state ()
  "Return current inline completion session state, creating defaults if needed."
  (unless (listp rc/gptel-complete-session-state)
    (rc/gptel-complete-session-reset))
  rc/gptel-complete-session-state)

(defun rc/gptel-complete-session-update (&rest pairs)
  "Update current inline completion session state using PAIRS."
  (let ((state (copy-sequence (rc/gptel-complete-session-state))))
    (while pairs
      (setq state (plist-put state (pop pairs) (pop pairs))))
    (setq rc/gptel-complete-session-state state)))

(defun rc/gptel-complete-normalize-trigger-source (suggestion request-meta)
  "Return stable trigger source for SUGGESTION and REQUEST-META.
Do not leak stale auto-trigger diagnostics into manual or cache-backed requests."
  (let* ((request-source (plist-get suggestion :request-source))
         (detail-trigger (plist-get request-meta :trigger-source))
         (last-check-trigger
          (and (boundp 'rc/gptel-complete-last-auto-trigger-check)
               (plist-get rc/gptel-complete-last-auto-trigger-check :trigger-source))))
    (cond
     (detail-trigger detail-trigger)
     ((memq request-source '(followup
                             cache-refresh
                             post-jump-retrigger
                             lsp-suggestions
                             signature-help
                             flymake-diagnostics))
      request-source)
     ((eq request-source 'auto)
      (or last-check-trigger 'auto-typing))
     (t nil))))

(defun rc/gptel-sync-complete-session-state ()
  "Synchronize local session state from gptel-autocomplete buffer state."
  (let* ((suggestion (rc/gptel-complete-current-suggestion-snapshot))
         (end-reason (rc/gptel-complete-normalize-end-reason
                      (and (fboundp 'gptel-autocomplete-end-reason)
                           (gptel-autocomplete-end-reason))))
         (request-id
          (rc/gptel-complete-normalize-request-id
           (or (and (fboundp 'gptel-autocomplete-active-request-id)
                    (gptel-autocomplete-active-request-id))
               (plist-get suggestion :request-id)
               (plist-get (and (fboundp 'gptel-autocomplete-last-result)
                               (gptel-autocomplete-last-result))
                          :request-id))))
         (state-history
          (rc/gptel-complete-fill-history-request-id
           (rc/gptel-complete-normalize-history
            (or (and (fboundp 'gptel-autocomplete-state-history)
                     (gptel-autocomplete-state-history))
                nil))
           request-id))
         (lifecycle-history
          (rc/gptel-complete-fill-history-request-id
           (rc/gptel-complete-normalize-history
            (or (and (fboundp 'gptel-autocomplete-lifecycle-history)
                     (gptel-autocomplete-lifecycle-history))
                nil))
           request-id))
         (last-reused
          (seq-find (lambda (entry)
                      (eq (plist-get entry :event) 'reused))
                    lifecycle-history))
         (state (rc/gptel-complete-normalize-state
                 (or (and (fboundp 'gptel-autocomplete-state)
                          (gptel-autocomplete-state))
                     (plist-get suggestion :state)
                     'idle)
                 end-reason))
         (request-meta
          (or (and (fboundp 'gptel-autocomplete-current-request-metadata)
                   (gptel-autocomplete-current-request-metadata))
              (and (fboundp 'rc/gptel-action-last-request)
                   (plist-get (rc/gptel-action-last-request) :detail))))
         (env-policy
          (and (fboundp 'rc/gptel-complete-environment-policy)
               (rc/gptel-complete-environment-policy 'auto))))
    (rc/gptel-complete-session-update
     :visible (and (fboundp 'gptel-autocomplete-visible-p)
                   (gptel-autocomplete-visible-p))
     :display-phase (and (fboundp 'gptel-autocomplete-display-phase)
                         (gptel-autocomplete-display-phase))
     :display-stale (and (fboundp 'gptel-autocomplete-stale-p)
                         (gptel-autocomplete-stale-p))
     :requesting-indicator-visible
     (and (fboundp 'gptel-autocomplete-requesting-indicator-visible-p)
          (gptel-autocomplete-requesting-indicator-visible-p))
     :requesting-indicator-reason
     (and (fboundp 'gptel-autocomplete-requesting-indicator-reason)
          (gptel-autocomplete-requesting-indicator-reason))
     :status-indicator (and (fboundp 'gptel-autocomplete-status-indicator)
                            (gptel-autocomplete-status-indicator))
     :environment-auto-allow (and env-policy (plist-get env-policy :auto-allow))
     :environment-manual-allow (and env-policy (plist-get env-policy :manual-allow))
     :environment-suppress-reason (and env-policy (plist-get env-policy :blocked-reason))
     :environment-yield-target (and env-policy (plist-get env-policy :yield-target))
     :environment-org-src (and env-policy (plist-get env-policy :org-src))
     :suggestion-id (plist-get suggestion :id)
     :suggestion suggestion
     :state state
     :end-reason end-reason
     :state-history state-history
     :request-id request-id
     :request-source (plist-get suggestion :request-source)
     :request-logical-outcome
     (plist-get request-meta :logical-outcome)
     :request-transport-outcome
     (or (plist-get request-meta :transport-outcome)
         (plist-get request-meta :timed-out))
     :request-supersede-strategy
     (plist-get request-meta :supersede-strategy)
     :trigger-source (rc/gptel-complete-normalize-trigger-source
                      suggestion request-meta)
     :cache-source (plist-get last-reused :source)
     :last-result (and (fboundp 'gptel-autocomplete-last-result)
                       (gptel-autocomplete-last-result))
     :last-visible-text (and (fboundp 'gptel-autocomplete-last-visible-text)
                             (gptel-autocomplete-last-visible-text))
     :last-command-kind (or (and (fboundp 'gptel-autocomplete-last-command-kind)
                                 (gptel-autocomplete-last-command-kind))
                            (plist-get suggestion :last-command-kind))
     :accepted-length (or (plist-get suggestion :accepted-length) 0)
     :accepted-kind (plist-get suggestion :accepted-kind)
     :last-lifecycle-event (car-safe lifecycle-history)
     :lifecycle-history lifecycle-history
     :recent-events
     (rc/gptel-complete-fill-history-request-id
      (plist-get suggestion :recent-events)
      request-id)
     :cache-size (and (fboundp 'gptel-autocomplete-cache-size)
                      (gptel-autocomplete-cache-size))
     :candidate-count (or (and (fboundp 'gptel-autocomplete-candidate-count)
                               (gptel-autocomplete-candidate-count))
                          (plist-get suggestion :candidate-count)
                          0)
     :candidate-index (or (and (fboundp 'gptel-autocomplete-candidate-index)
                               (gptel-autocomplete-candidate-index))
                          (plist-get suggestion :candidate-index)
                          0)
     :next-edit-id
     (or (and (fboundp 'gptel-autocomplete-next-edit-id)
              (gptel-autocomplete-next-edit-id))
         (plist-get suggestion :next-edit-id))
     :next-edit-queue-size
     (or (and (fboundp 'gptel-autocomplete-next-edit-queue-size)
              (gptel-autocomplete-next-edit-queue-size))
         (length (or (plist-get suggestion :next-edit-queue) nil))
         0)
     :cursor-prediction-target-id
     (and (fboundp 'gptel-autocomplete-cursor-prediction-target-id)
          (gptel-autocomplete-cursor-prediction-target-id))
     :cursor-prediction-target-point
     (and (fboundp 'gptel-autocomplete-cursor-prediction-point)
          (gptel-autocomplete-cursor-prediction-point))
     :cursor-prediction-target-available
     (and (fboundp 'gptel-autocomplete-cursor-prediction-available-p)
          (gptel-autocomplete-cursor-prediction-available-p))
     :next-action-kind
     (or (and (fboundp 'gptel-autocomplete-next-action-kind)
              (gptel-autocomplete-next-action-kind))
         (plist-get (and (fboundp 'gptel-autocomplete-last-result)
                         (gptel-autocomplete-last-result))
                    :next-action-kind)
         'none)
     :next-action-count
     (or (and (fboundp 'gptel-autocomplete-next-action-count)
              (gptel-autocomplete-next-action-count))
         (plist-get (and (fboundp 'gptel-autocomplete-last-result)
                         (gptel-autocomplete-last-result))
                    :next-action-count)
         0)
     :restore-available
     (or (and (fboundp 'gptel-autocomplete-restore-available-p)
              (gptel-autocomplete-restore-available-p))
         (plist-get (and (fboundp 'gptel-autocomplete-last-result)
                         (gptel-autocomplete-last-result))
                    :restore-available)
         nil)
     :divergence-distance
     (or (and (fboundp 'gptel-autocomplete-divergence-distance)
              (gptel-autocomplete-divergence-distance))
         (plist-get (and (fboundp 'gptel-autocomplete-last-result)
                         (gptel-autocomplete-last-result))
                    :divergence-distance)
         0)
     :last-error (and (fboundp 'gptel-autocomplete-last-error)
                      (gptel-autocomplete-last-error))
     :stats (and (fboundp 'gptel-autocomplete-stats)
                 (copy-sequence (gptel-autocomplete-stats)))
     :current-profile (and (boundp 'rc/gptel-complete-current-profile)
                           rc/gptel-complete-current-profile)
     :followup-queue-size (or (and (fboundp 'gptel-autocomplete-followup-queue-size)
                                   (gptel-autocomplete-followup-queue-size))
                              (length (or (plist-get suggestion :followup-queue) nil))
                              0)
     :cache-followup-count (length (or (plist-get suggestion :followup-queue) nil))
     :cache-candidate-count (or (and (fboundp 'gptel-autocomplete-candidate-count)
                                     (gptel-autocomplete-candidate-count))
                                (plist-get suggestion :candidate-count)
                                0)
     :superseded-ids
     (and (fboundp 'gptel-autocomplete-superseded-request-ids)
          (mapcar #'rc/gptel-complete-normalize-request-id
                  (gptel-autocomplete-superseded-request-ids))))))

(defun rc/gptel-complete-accept-hook (payload)
  "Record completion acceptance PAYLOAD into local session state."
  (let* ((partial (plist-get payload :partial))
         (state (rc/gptel-complete-session-state))
         (accepted-count (or (plist-get state :accepted-count) 0))
         (partial-count (or (plist-get state :partial-accepted-count) 0)))
    (rc/gptel-complete-session-update
     :visible (and (fboundp 'gptel-autocomplete-visible-p)
                   (gptel-autocomplete-visible-p))
     :state (or (and (fboundp 'gptel-autocomplete-state)
                     (gptel-autocomplete-state))
                'idle)
     :request-id (plist-get payload :request-id)
     :last-result payload
     :last-accept payload
     :last-accept-kind (or (plist-get payload :accept-kind)
                           (and partial 'word)
                           'full)
     :accepted-kind (plist-get payload :accept-kind)
     :cache-size (and (fboundp 'gptel-autocomplete-cache-size)
                      (gptel-autocomplete-cache-size))
     :followup-queue-size (or (and (fboundp 'gptel-autocomplete-followup-queue-size)
                                   (gptel-autocomplete-followup-queue-size))
                              0)
     :accepted-count (if partial accepted-count (1+ accepted-count))
     :partial-accepted-count (if partial (1+ partial-count) partial-count))))

(defun rc/gptel-complete-lifecycle-hook (payload)
  "Merge lifecycle PAYLOAD into local inline completion session state."
  (let* ((entry (rc/gptel-complete-normalize-entry payload))
         (event (plist-get entry :event))
         (end-reason (plist-get entry :end-reason))
         (entry-state (plist-get entry :state))
         (state (rc/gptel-complete-session-state))
         (forward-count (or (plist-get state :forward-stable-count) 0))
         (restored-count (or (plist-get state :restored-count) 0))
         (temporarily-diverged-count
          (or (plist-get state :temporarily-diverged-count) 0))
         (cache-hit-count (or (plist-get state :cache-hit-count) 0))
         (superseded-count (or (plist-get state :superseded-count) 0))
         (aborted-count (or (plist-get state :aborted-count) 0))
         (rejected-count (or (plist-get state :rejected-count) 0))
         (ignored-count (or (plist-get state :ignored-count) 0))
         (ignored-point-move-count
          (or (plist-get state :ignored-point-move-count) 0))
         (ignored-buffer-edit-count
          (or (plist-get state :ignored-buffer-edit-count) 0))
         (ignored-superseded-count
          (or (plist-get state :ignored-superseded-count) 0))
         (ignored-typing-disagreed-count
          (or (plist-get state :ignored-typing-disagreed-count) 0))
         (invalidated-move-count
          (or (plist-get state :invalidated-move-count) 0))
         (invalidated-edit-count
          (or (plist-get state :invalidated-edit-count) 0))
         (mode-disabled-count (or (plist-get state :mode-disabled-count) 0)))
    (rc/gptel-sync-complete-session-state)
    (rc/gptel-complete-session-update
     :last-lifecycle-event entry
     :state (or entry-state (plist-get (rc/gptel-complete-session-state) :state))
     :cache-source
     (if (eq event 'reused)
         (plist-get entry :source)
       (plist-get (rc/gptel-complete-session-state) :cache-source))
     :cache-followup-count
     (if (eq event 'reused)
         (or (plist-get (rc/gptel-complete-session-state) :followup-queue-size) 0)
       (or (plist-get (rc/gptel-complete-session-state) :cache-followup-count) 0))
     :cache-candidate-count
     (if (eq event 'reused)
         (or (plist-get (rc/gptel-complete-session-state) :candidate-count) 0)
       (or (plist-get (rc/gptel-complete-session-state) :cache-candidate-count) 0))
     :forward-stable-count
     (if (and (eq event 'visible)
              (or (plist-member entry :typed)
                  (plist-member entry :prefix-length)))
         (1+ forward-count)
       forward-count)
     :restored-count
     (if (eq end-reason 'restored-after-delete)
         (1+ restored-count)
       restored-count)
     :temporarily-diverged-count
     (if (eq entry-state 'temporarily-diverged)
         (1+ temporarily-diverged-count)
       temporarily-diverged-count)
     :cache-hit-count
     (if (eq event 'reused) (1+ cache-hit-count) cache-hit-count)
     :superseded-count
     (if (eq entry-state 'superseded) (1+ superseded-count) superseded-count)
     :aborted-count
     (if (eq end-reason 'aborted-request) (1+ aborted-count) aborted-count)
     :rejected-count
     (if (eq end-reason 'rejected-user) (1+ rejected-count) rejected-count)
     :ignored-count
     (if (memq end-reason '(ignored-point-move
                            ignored-buffer-edit
                            ignored-superseded
                            ignored-typing-disagreed))
         (1+ ignored-count)
       ignored-count)
     :ignored-point-move-count
     (if (eq end-reason 'ignored-point-move)
         (1+ ignored-point-move-count)
       ignored-point-move-count)
     :ignored-buffer-edit-count
     (if (eq end-reason 'ignored-buffer-edit)
         (1+ ignored-buffer-edit-count)
       ignored-buffer-edit-count)
     :ignored-superseded-count
     (if (eq end-reason 'ignored-superseded)
         (1+ ignored-superseded-count)
       ignored-superseded-count)
     :ignored-typing-disagreed-count
     (if (eq end-reason 'ignored-typing-disagreed)
         (1+ ignored-typing-disagreed-count)
       ignored-typing-disagreed-count)
     :invalidated-move-count
     (if (eq end-reason 'ignored-point-move)
         (1+ invalidated-move-count)
       invalidated-move-count)
     :invalidated-edit-count
     (if (eq end-reason 'ignored-buffer-edit)
         (1+ invalidated-edit-count)
       invalidated-edit-count)
     :mode-disabled-count
     (if (eq end-reason 'cleared-mode-disabled)
         (1+ mode-disabled-count)
       mode-disabled-count))
    (when (fboundp 'rc/gptel-complete-record-cooldown-from-lifecycle)
      (rc/gptel-complete-record-cooldown-from-lifecycle entry))))

(provide 'ai-complete-state-rc)
;;; ai-complete-state-rc.el ends here
