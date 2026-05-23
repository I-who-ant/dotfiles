;;; ai-action-state-rc.el --- Shared AI action snapshot helpers -*- lexical-binding: t; -*-

;;; Code:

(require 'seq)
(require 'subr-x)

(defun rc/gptel-action-snapshot-p (object)
  "Return non-nil when OBJECT looks like an action snapshot plist."
  (and (listp object)
       (plist-member object :action-kind)
       (plist-member object :buffer)
       (plist-member object :state)))

(defun rc/gptel-action-title (snapshot)
  "Return readable title for action SNAPSHOT."
  (or (plist-get snapshot :title)
      (format "%s:%s"
              (or (plist-get snapshot :action-kind) 'unknown)
              (buffer-name (plist-get snapshot :buffer)))))

(defun rc/gptel-action-snapshot-score (snapshot)
  "Return priority score for SNAPSHOT."
  (+ (if (plist-get snapshot :visible) 40 0)
     (if (plist-get snapshot :request-id) 20 0)
     (if (memq (plist-get snapshot :state) '(requesting visible ready applied)) 10 0)
     (if (plist-get snapshot :last-error) 5 0)))

(defun rc/gptel-action--normalize-snapshot (snapshot)
  "Return SNAPSHOT normalized to the shared read-only shape."
  (when (rc/gptel-action-snapshot-p snapshot)
    (list :action-kind (plist-get snapshot :action-kind)
          :title (rc/gptel-action-title snapshot)
          :buffer (plist-get snapshot :buffer)
          :request-id (plist-get snapshot :request-id)
          :state (or (plist-get snapshot :state) 'idle)
          :end-reason (plist-get snapshot :end-reason)
          :visible (plist-get snapshot :visible)
          :display-phase (plist-get snapshot :display-phase)
          :requesting-indicator-visible
          (plist-get snapshot :requesting-indicator-visible)
          :last-error (plist-get snapshot :last-error)
          :backend (plist-get snapshot :backend)
          :model (plist-get snapshot :model)
          :profile (plist-get snapshot :profile)
          :stats (plist-get snapshot :stats)
          :history (plist-get snapshot :history)
          :transitions (plist-get snapshot :transitions)
          :detail (plist-get snapshot :detail))))

(defun rc/gptel-complete-session-meaningful-p (&optional buffer)
  "Return non-nil when BUFFER has meaningful complete state."
  (with-current-buffer (or buffer (current-buffer))
    (let ((state (and (fboundp 'rc/gptel-complete-session-state)
                      (rc/gptel-complete-session-state))))
      (and state
           (or (bound-and-true-p gptel-autocomplete-mode)
               (plist-get state :visible)
               (plist-get state :request-id)
               (plist-get state :last-error)
               (plist-get state :lifecycle-history)
               (not (eq (plist-get state :state) 'idle)))))))

(defun rc/gptel-complete-action-snapshot (&optional buffer)
  "Return shared snapshot for complete state in BUFFER, else nil."
  (with-current-buffer (or buffer (current-buffer))
    (when (and (fboundp 'rc/gptel-sync-complete-session-state)
               (fboundp 'rc/gptel-complete-session-state)
               (rc/gptel-complete-session-meaningful-p (current-buffer)))
      (when (or (fboundp 'gptel-autocomplete-state)
                (fboundp 'gptel-autocomplete-current-suggestion))
        (rc/gptel-sync-complete-session-state))
      (let ((state (copy-sequence (rc/gptel-complete-session-state))))
        (rc/gptel-action--normalize-snapshot
         (list :action-kind 'complete
               :title (format "complete:%s" (buffer-name))
               :buffer (current-buffer)
               :request-id (plist-get state :request-id)
               :state (plist-get state :state)
               :end-reason (plist-get state :end-reason)
               :visible (plist-get state :visible)
               :display-phase (plist-get state :display-phase)
               :requesting-indicator-visible
               (plist-get state :requesting-indicator-visible)
               :last-error (plist-get state :last-error)
               :backend (and (boundp 'gptel-backend) gptel-backend)
               :model (and (boundp 'gptel-model) gptel-model)
               :profile (plist-get state :current-profile)
               :stats (plist-get state :stats)
               :history (or (and (fboundp 'rc/gptel-complete-shared-lifecycle-history)
                                 (rc/gptel-complete-shared-lifecycle-history (current-buffer)))
                            (plist-get state :lifecycle-history))
               :transitions (plist-get state :state-history)
               :detail
               (list :suggestion-id (plist-get state :suggestion-id)
                     :request-source (plist-get state :request-source)
                     :trigger-source (plist-get state :trigger-source)
                     :cache-source (plist-get state :cache-source)
                     :candidate-count (plist-get state :candidate-count)
                     :candidate-index (plist-get state :candidate-index)
                     :next-edit-id (plist-get state :next-edit-id)
                     :next-edit-queue-size (plist-get state :next-edit-queue-size)
                     :cursor-prediction-target-id
                     (plist-get state :cursor-prediction-target-id)
                     :cursor-prediction-target-point
                     (plist-get state :cursor-prediction-target-point)
                     :cursor-prediction-target-available
                     (plist-get state :cursor-prediction-target-available)
                     :next-action-kind (plist-get state :next-action-kind)
                     :next-action-count (plist-get state :next-action-count)
                     :restore-available (plist-get state :restore-available)
                     :divergence-distance (plist-get state :divergence-distance)
                     :cache-candidate-count (plist-get state :cache-candidate-count)
                     :followup-queue-size (plist-get state :followup-queue-size)
                     :cache-followup-count (plist-get state :cache-followup-count)
                     :environment-auto-allow (plist-get state :environment-auto-allow)
                     :environment-manual-allow (plist-get state :environment-manual-allow)
                     :environment-suppress-reason
                     (plist-get state :environment-suppress-reason)
                     :environment-yield-target
                     (plist-get state :environment-yield-target)
                     :environment-org-src (plist-get state :environment-org-src)
                     :continuation-next-step
                     (plist-get state :continuation-next-step)
                     :continuation-next-reason
                     (plist-get state :continuation-next-reason)
                     :cooldown-active (plist-get state :cooldown-active)
                     :cooldown-summary (plist-get state :cooldown-summary)
                     :accepted-length (plist-get state :accepted-length)
                     :accepted-kind (plist-get state :accepted-kind)
                     :last-command-kind (plist-get state :last-command-kind)
                     :last-visible-text (plist-get state :last-visible-text)
                     :current-profile (plist-get state :current-profile)
                     :cache-size (plist-get state :cache-size)
                     :superseded-ids (plist-get state :superseded-ids))))))))

(defun rc/gptel-action-current-snapshot (&optional buffer)
  "Return current shared snapshot for BUFFER, preferring the most relevant action."
  (with-current-buffer (or buffer (current-buffer))
    (let* ((candidates
            (delq nil
                  (list
                   (and (fboundp 'rc/gptel-ask-action-snapshot)
                        (rc/gptel-ask-action-snapshot (current-buffer)))
                   (and (fboundp 'rc/gptel-rewrite-action-snapshot)
                        (rc/gptel-rewrite-action-snapshot (current-buffer)))
                   (rc/gptel-complete-action-snapshot (current-buffer))
                   (and (boundp 'rc/gptel-current-ask-buffer)
                        (buffer-live-p rc/gptel-current-ask-buffer)
                        (fboundp 'rc/gptel-ask-action-snapshot)
                        (rc/gptel-ask-action-snapshot rc/gptel-current-ask-buffer))))))
      (car (sort candidates
                 (lambda (a b)
                   (> (rc/gptel-action-snapshot-score a)
                      (rc/gptel-action-snapshot-score b))))))))

(defun rc/gptel-action-snapshots ()
  "Return all meaningful shared action snapshots from live buffers."
  (let ((seen (make-hash-table :test #'equal))
        snapshots)
    (dolist (buffer (buffer-list))
      (when (fboundp 'rc/gptel-ask-action-snapshot)
        (let ((snapshot (rc/gptel-ask-action-snapshot buffer)))
          (when snapshot
            (puthash (list (plist-get snapshot :action-kind)
                           (plist-get snapshot :buffer))
                     snapshot
                     seen))))
      (when (fboundp 'rc/gptel-rewrite-action-snapshot)
        (let ((snapshot (rc/gptel-rewrite-action-snapshot buffer)))
          (when snapshot
            (puthash (list (plist-get snapshot :action-kind)
                           (plist-get snapshot :buffer))
                     snapshot
                     seen))))
      (let ((snapshot (rc/gptel-complete-action-snapshot buffer)))
        (when snapshot
          (puthash (list (plist-get snapshot :action-kind)
                         (plist-get snapshot :buffer))
                   snapshot
                   seen))))
    (maphash (lambda (_ value) (push value snapshots)) seen)
    (sort snapshots
          (lambda (a b)
            (> (rc/gptel-action-snapshot-score a)
               (rc/gptel-action-snapshot-score b))))))

(provide 'ai-action-state-rc)
;;; ai-action-state-rc.el ends here
