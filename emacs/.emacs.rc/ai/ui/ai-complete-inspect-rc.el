;;; ai-complete-inspect-rc.el --- Inline completion inspector UI -*- lexical-binding: t; -*-

;;; Code:

(require 'seq)
(require 'subr-x)

(defun rc/gptel-complete--section (title lines)
  "Return formatted section with TITLE and LINES."
  (when (seq-some (lambda (line) (and line (not (string-empty-p line)))) lines)
    (string-join
     (cons (format "%s:" title)
           (mapcar (lambda (line) (concat "  " line))
                   (delq nil lines)))
     "\n")))

(defun rc/gptel-complete-state-summary ()
  "Return a formatted summary string for the current inline completion state."
  (let* ((state (rc/gptel-complete-session-state))
         (last-event (plist-get state :last-lifecycle-event))
         (last-event-name (plist-get last-event :event))
         (last-event-request (plist-get last-event :request-id))
         (stats (plist-get state :stats))
         (auto-diag (and (boundp 'rc/gptel-complete-last-auto-trigger-check)
                         rc/gptel-complete-last-auto-trigger-check))
         (blocked-counts (and (fboundp 'rc/gptel-complete-auto-trigger-blocked-reason-counts)
                              (rc/gptel-complete-auto-trigger-blocked-reason-counts)))
         (last-success (and (fboundp 'rc/gptel-complete-last-successful-trigger-check)
                            (rc/gptel-complete-last-successful-trigger-check))))
    (string-join
     (delq nil
           (list
            (rc/gptel-complete--section
             "Overview"
             (list
              (format "buffer: %s" (buffer-name))
              (format "major-mode: %s" major-mode)
              (format "suggestion-id: %s" (or (plist-get state :suggestion-id) "none"))
              (format "state: %s" (or (plist-get state :state) 'idle))
              (format "end: %s" (or (plist-get state :end-reason) "none"))
              (format "visible: %s" (if (plist-get state :visible) "yes" "no"))
              (format "display-phase: %s" (or (plist-get state :display-phase) 'idle))
              (format "stale: %s" (if (plist-get state :display-stale) "yes" "no"))
              (format "requesting: %s"
                      (if (plist-get state :requesting-indicator-visible) "yes" "no"))
              (format "requesting-reason: %s"
                      (or (plist-get state :requesting-indicator-reason) "none"))
              (format "status-indicator: %s"
                      (or (plist-get state :status-indicator) "none"))))
            (rc/gptel-complete--section
             "Source & Next Action"
             (list
              (format "active-request: %s" (or (plist-get state :request-id) "none"))
              (format "request-source: %s" (or (plist-get state :request-source) "none"))
              (format "request-outcome: %s"
                      (or (plist-get state :request-logical-outcome) "none"))
              (format "transport-outcome: %s"
                      (or (plist-get state :request-transport-outcome) "none"))
              (format "supersede-strategy: %s"
                      (or (plist-get state :request-supersede-strategy) "none"))
              (format "trigger-source: %s" (or (plist-get state :trigger-source) "none"))
              (format "cache-source: %s" (or (plist-get state :cache-source) "none"))
              (format "next-action: %s"
                      (or (plist-get state :next-action-kind) 'none))
              (format "next-action-count: %s"
                      (or (plist-get state :next-action-count) 0))
              (format "next-edit-id: %s"
                      (or (plist-get state :next-edit-id) "none"))
              (format "next-edit-queue: %s"
                      (or (plist-get state :next-edit-queue-size) 0))
              (format "cursor-target-id: %s"
                      (or (plist-get state :cursor-prediction-target-id) "none"))
              (format "cursor-target-point: %s"
                      (or (plist-get state :cursor-prediction-target-point) "none"))
              (format "cursor-target-available: %s"
                      (if (plist-get state :cursor-prediction-target-available) "yes" "no"))
              (format "restore-available: %s"
                      (if (plist-get state :restore-available) "yes" "no"))
              (format "divergence-distance: %s"
                      (or (plist-get state :divergence-distance) 0))
              (format "profile: %s" (or (plist-get state :current-profile) "none"))
              (format "last-command-kind: %s"
                      (or (plist-get state :last-command-kind) "none"))
              (format "last-event: %s%s"
                      (or last-event-name "none")
                      (if last-event-request
                          (format " (%s)" last-event-request)
                        ""))))
            (rc/gptel-complete--section
             "Suggestion"
             (list
              (format "candidate: %s/%s"
                      (1+ (or (plist-get state :candidate-index) 0))
                      (or (plist-get state :candidate-count) 0))
              (format "next-edit-queue-size: %s"
                      (or (plist-get state :next-edit-queue-size) 0))
              (format "legacy-followup-queue: %s"
                      (or (plist-get state :followup-queue-size) 0))
              (format "cache-size: %s" (or (plist-get state :cache-size) 0))
              (format "cache-candidate-count: %s"
                      (or (plist-get state :cache-candidate-count) 0))
              (format "cache-next-edit-count: %s"
                      (or (plist-get state :cache-followup-count) 0))
              (format "accepted-kind: %s" (or (plist-get state :accepted-kind) "none"))
              (format "accepted-length: %s" (or (plist-get state :accepted-length) 0))
              (format "last-accept: %s" (or (plist-get state :last-accept-kind) "none"))
              (format "last-visible-text: %s"
                      (or (plist-get state :last-visible-text) "none"))
              (format "last-error: %s" (or (plist-get state :last-error) "none"))))
            (rc/gptel-complete--section
             "Auto Trigger"
             (list
              (format "auto-trigger: %s"
                      (if (bound-and-true-p rc/gptel-complete-auto-trigger-enabled)
                          "on" "off"))
              (format "auto-trigger-mode: %s"
                      (or (and (boundp 'rc/gptel-complete-auto-trigger-mode)
                               rc/gptel-complete-auto-trigger-mode)
                          'off))
              (format "match-kind: %s"
                      (or (plist-get auto-diag :trigger-match-kind) "none"))
              (format "trigger-source: %s"
                      (or (plist-get auto-diag :trigger-source) "none"))
              (format "source-rule-enabled: %s"
                      (if (plist-get (plist-get auto-diag :source-rule) :enabled) "yes" "no"))
              (format "blocked-reason: %s"
                      (or (plist-get auto-diag :blocked-reason) "none"))
              (format "blocked-reason-counts: %s"
                      (if blocked-counts
                          (mapconcat
                           (lambda (pair) (format "%s=%s" (car pair) (cdr pair)))
                           blocked-counts
                           ", ")
                        "none"))
              (format "last-success-source: %s"
                      (or (plist-get last-success :trigger-match-kind) "none"))
              (format "last-success-event: %s"
                      (or (plist-get last-success :event-char) "none"))
              (format "line-end-match: %s"
                      (if (plist-get auto-diag :line-end-match) "yes" "no"))
              (format "event: %s"
                      (or (plist-get auto-diag :event-char) "none"))
              (format "trigger-chars: %s"
                      (mapconcat (lambda (ch) (string ch))
                                 (or (plist-get auto-diag :trigger-chars) nil)
                                 " "))))
            (rc/gptel-complete--section
             "Counters"
             (list
              (format "forward-stable: %s" (or (plist-get state :forward-stable-count) 0))
              (format "restored: %s" (or (plist-get state :restored-count) 0))
              (format "temporarily-diverged: %s"
                      (or (plist-get state :temporarily-diverged-count) 0))
              (format "cache-hit: %s" (or (plist-get state :cache-hit-count) 0))
              (format "superseded: %s" (or (plist-get state :superseded-count) 0))
              (format "aborted: %s" (or (plist-get state :aborted-count) 0))
              (format "rejected: %s" (or (plist-get state :rejected-count) 0))
              (format "ignored: %s" (or (plist-get state :ignored-count) 0))
              (format "ignored-point-move: %s"
                      (or (plist-get state :ignored-point-move-count) 0))
              (format "ignored-buffer-edit: %s"
                      (or (plist-get state :ignored-buffer-edit-count) 0))
              (format "ignored-superseded: %s"
                      (or (plist-get state :ignored-superseded-count) 0))
              (format "ignored-typing-disagreed: %s"
                      (or (plist-get state :ignored-typing-disagreed-count) 0))
              (format "invalidated-move: %s"
                      (or (plist-get state :invalidated-move-count) 0))
              (format "invalidated-edit: %s"
                      (or (plist-get state :invalidated-edit-count) 0))
              (format "mode-disabled: %s"
                      (or (plist-get state :mode-disabled-count) 0))))
            (rc/gptel-complete--section
             "Continuation & Cooldown"
             (list
              (format "next-step: %s"
                      (or (plist-get state :continuation-next-step) 'idle))
              (format "next-reason: %s"
                      (or (plist-get state :continuation-next-reason) 'none))
              (format "override: %s"
                      (or (plist-get state :continuation-override) 'default))
              (format "chain-length/limit: %s/%s"
                      (or (plist-get state :continuation-chain-length) 0)
                      (or (plist-get state :continuation-chain-limit) 0))
              (format "stopped-by-limit: %s"
                      (or (plist-get state :continuation-stopped-by-limit-count) 0))
              (format "forced-stop-count: %s"
                      (or (plist-get state :forced-stop-count) 0))
              (format "forced-followup-count: %s"
                      (or (plist-get state :forced-followup-count) 0))
              (format "cooldown-active: %s"
                      (if (plist-get state :cooldown-active) "yes" "no"))
              (format "cooldown-summary: %s"
                      (or (plist-get state :cooldown-summary) "none"))
              (format "cooldown-reason: %s"
                      (or (plist-get state :cooldown-reason) 'none))
              (format "cooldown-hit-count: %s"
                      (or (plist-get state :cooldown-hit-count) 0))))
            (rc/gptel-complete--section
             "Editor Coordination"
             (list
              (format "environment-auto-allow: %s"
                      (if (plist-get state :environment-auto-allow) "yes" "no"))
              (format "environment-manual-allow: %s"
                      (if (plist-get state :environment-manual-allow) "yes" "no"))
              (format "environment-suppress-reason: %s"
                      (or (plist-get state :environment-suppress-reason) 'none))
              (format "environment-yield-target: %s"
                      (or (plist-get state :environment-yield-target) 'none))
              (format "environment-org-src: %s"
                      (if (plist-get state :environment-org-src) "yes" "no"))))
            (rc/gptel-complete--section
             "Stats"
             (list
              (format "request-count: %s" (or (plist-get stats :request-count) 0))
              (format "manual-requests: %s" (or (plist-get stats :manual-request-count) 0))
              (format "auto-requests: %s" (or (plist-get stats :auto-request-count) 0))
              (format "followup-requests: %s" (or (plist-get stats :followup-request-count) 0))
              (format "retry-requests: %s" (or (plist-get stats :retry-request-count) 0))
              (format "request-skipped: %s" (or (plist-get stats :request-skipped-count) 0))
              (format "visible-count: %s" (or (plist-get stats :visible-count) 0))
              (format "candidate-visible: %s"
                      (or (plist-get stats :candidate-visible-count) 0))
              (format "retry-count: %s" (or (plist-get stats :retry-count) 0))
              (format "failure-count: %s" (or (plist-get stats :failure-count) 0))
              (format "cache-store-count: %s" (or (plist-get stats :cache-store-count) 0))
              (format "cache-hit-count: %s" (or (plist-get stats :cache-hit-count) 0))
              (format "stats.forward-stable: %s"
                      (or (plist-get stats :forward-stable-count) 0))
              (format "accepted-full: %s" (or (plist-get stats :accepted-full-count) 0))
              (format "accepted-partial: %s" (or (plist-get stats :accepted-partial-count) 0))
              (format "candidate-cycles: %s" (or (plist-get stats :candidate-cycle-count) 0))))))
     "\n\n")))

(defun rc/gptel-complete-describe-state ()
  "Show current inline completion state in a temporary help buffer."
  (interactive)
  (rc/gptel-sync-complete-session-state)
  (with-help-window "*AI Complete State*"
    (princ (rc/gptel-complete-state-summary))
    (let ((recent-events (plist-get (rc/gptel-complete-session-state) :recent-events)))
      (when recent-events
        (princ "\n\nRecent suggestion events:\n")
        (dolist (event (seq-take recent-events 12))
          (princ
           (format "- %-18s state=%s request=%s source=%s next=%s end=%s\n"
                   (or (plist-get event :event) 'unknown)
                   (or (plist-get event :state) 'unknown)
                   (or (plist-get event :request-id) "none")
                   (or (plist-get event :source)
                       (plist-get event :trigger-source)
                       'none)
                   (or (plist-get event :next-action-kind) 'none)
                   (or (plist-get event :end-reason) "none"))))))
    (let ((history (plist-get (rc/gptel-complete-session-state) :lifecycle-history)))
      (when history
        (princ "\n\nRecent lifecycle events:\n")
        (dolist (event (seq-take history 12))
          (princ
           (format "- %-18s request=%s point=%s source=%s next=%s end=%s\n"
                   (or (plist-get event :event) 'unknown)
                   (or (plist-get event :request-id) "none")
                   (or (plist-get event :point) "n/a")
                   (or (plist-get event :source)
                       (plist-get event :trigger-source)
                       'none)
                   (or (plist-get event :next-action-kind) 'none)
                   (or (plist-get event :end-reason) "none"))))))
    (let ((state-history (plist-get (rc/gptel-complete-session-state) :state-history)))
      (when state-history
        (princ "\n\nRecent state transitions:\n")
        (dolist (entry (seq-take state-history 12))
          (princ
           (format "- %-18s <- %-18s event=%s source=%s kind=%s next=%s end=%s\n"
                   (or (plist-get entry :state) 'unknown)
                   (or (plist-get entry :previous-state) 'unknown)
                   (or (plist-get entry :event) 'direct)
                   (or (plist-get entry :source)
                       (plist-get entry :trigger-source)
                       'none)
                   (or (plist-get entry :command-kind) "-")
                   (or (plist-get entry :next-action-kind) 'none)
                   (or (plist-get entry :end-reason) "none"))))))
    (let ((trigger-history (and (boundp 'rc/gptel-complete-auto-trigger-history)
                                rc/gptel-complete-auto-trigger-history)))
      (when trigger-history
        (princ "\n\nRecent trigger checks:\n")
        (dolist (entry (seq-take trigger-history 12))
          (princ
           (format "- event=%-4s source=%-14s match=%-12s blocked=%s eligible=%s\n"
                   (or (plist-get entry :event-char) "n/a")
                   (or (plist-get entry :trigger-source) 'none)
                   (or (plist-get entry :trigger-match-kind) 'none)
                   (or (plist-get entry :blocked-reason) 'none)
                   (if (plist-get entry :eligible) "yes" "no"))))))))

(provide 'ai-complete-inspect-rc)
;;; ai-complete-inspect-rc.el ends here
