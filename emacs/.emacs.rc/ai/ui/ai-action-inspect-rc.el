;;; ai-action-inspect-rc.el --- Shared AI action inspector -*- lexical-binding: t; -*-

;;; Code:

(require 'seq)
(require 'subr-x)

(defun rc/gptel-action--section (title lines)
  "Return one formatted section using TITLE and LINES."
  (when (seq-some (lambda (line) (and line (not (string-empty-p line)))) lines)
    (string-join
     (cons (format "%s:" title)
           (mapcar (lambda (line) (concat "  " line))
                   (delq nil lines)))
     "\n")))

(defun rc/gptel-action--detail-lines (detail)
  "Return generic formatted lines for DETAIL plist."
  (when (listp detail)
    (seq-map
     (lambda (pair)
       (format "- %s: %s" (substring (symbol-name (car pair)) 1) (cdr pair)))
     (seq-partition detail 2))))

(defun rc/gptel-action--detail-renderer (snapshot)
  "Return detail lines for SNAPSHOT using action-aware rendering."
  (let ((detail (plist-get snapshot :detail)))
    (pcase (plist-get snapshot :action-kind)
      ('ask
       (list
        (format "- session-id: %s" (or (plist-get detail :session-id) "none"))
        (format "- file: %s" (or (plist-get detail :file) "none"))
        (format "- save-file: %s" (or (plist-get detail :save-file) "none"))
        (format "- turn-count: %s" (or (plist-get detail :turn-count) 0))
        (format "- question-count: %s" (or (plist-get detail :question-count) 0))
        (format "- source-count: %s" (or (plist-get detail :source-count) 0))))
      ('complete
       (list
        (format "- suggestion-id: %s" (or (plist-get detail :suggestion-id) "none"))
        (format "- request-source: %s" (or (plist-get detail :request-source) "none"))
        (format "- trigger-source: %s" (or (plist-get detail :trigger-source) "none"))
        (format "- cache-source: %s" (or (plist-get detail :cache-source) "none"))
        (format "- next-action: %s" (or (plist-get detail :next-action-kind) 'none))
        (format "- next-action-count: %s" (or (plist-get detail :next-action-count) 0))
        (format "- next-edit-id: %s" (or (plist-get detail :next-edit-id) "none"))
        (format "- next-edit-queue: %s" (or (plist-get detail :next-edit-queue-size) 0))
        (format "- cursor-target-id: %s"
                (or (plist-get detail :cursor-prediction-target-id) "none"))
        (format "- cursor-target-point: %s"
                (or (plist-get detail :cursor-prediction-target-point) "none"))
        (format "- cursor-target-available: %s"
                (if (plist-get detail :cursor-prediction-target-available) "yes" "no"))
        (format "- restore-available: %s"
                (if (plist-get detail :restore-available) "yes" "no"))
        (format "- divergence-distance: %s"
                (or (plist-get detail :divergence-distance) 0))
        (format "- candidate: %s/%s"
                (1+ (or (plist-get detail :candidate-index) 0))
                (or (plist-get detail :candidate-count) 0))
        (format "- cache-candidate-count: %s" (or (plist-get detail :cache-candidate-count) 0))
        (format "- legacy-followup-queue: %s" (or (plist-get detail :followup-queue-size) 0))
        (format "- cache-next-edit-count: %s" (or (plist-get detail :cache-followup-count) 0))
        (format "- accepted-length: %s" (or (plist-get detail :accepted-length) 0))
        (format "- accepted-kind: %s" (or (plist-get detail :accepted-kind) "none"))
        (format "- profile: %s" (or (plist-get detail :current-profile) "none"))
        (format "- cache-size: %s" (or (plist-get detail :cache-size) 0))
        (format "- last-command-kind: %s" (or (plist-get detail :last-command-kind) "none"))))
      ('rewrite
       (list
        (format "- rewrite-id: %s" (or (plist-get detail :rewrite-id) "none"))
        (format "- mode: %s" (or (plist-get detail :mode) "none"))
        (format "- region: %s" (or (plist-get detail :region) "none"))
        (format "- result: %s" (or (plist-get detail :result) "none"))))
      (_
       (rc/gptel-action--detail-lines detail)))))

(defun rc/gptel-action--history-line (entry)
  "Return readable history line for ENTRY."
  (cond
   ((stringp entry) entry)
   ((listp entry)
    (format "- %-18s state=%s request=%s source=%s next=%s end=%s"
            (or (plist-get entry :event) 'unknown)
            (or (plist-get entry :state) "n/a")
            (or (plist-get entry :request-id) "none")
            (or (plist-get entry :source)
                (plist-get entry :trigger-source)
                'none)
            (or (plist-get entry :next-action-kind) 'none)
            (or (plist-get entry :end-reason) "none")))
   (t
    (format "- %s" entry))))

(defun rc/gptel-action-state-summary (snapshot)
  "Return formatted summary string for shared action SNAPSHOT."
  (let* ((stats (plist-get snapshot :stats))
         (detail (plist-get snapshot :detail)))
    (string-join
     (delq nil
           (list
            (rc/gptel-action--section
             "Overview"
             (list
              (format "kind: %s" (plist-get snapshot :action-kind))
              (format "title: %s" (plist-get snapshot :title))
              (format "buffer: %s" (buffer-name (plist-get snapshot :buffer)))))
            (rc/gptel-action--section
             "Source & Next Action"
             (list
              (format "request: %s" (or (plist-get snapshot :request-id) "none"))
              (format "state: %s" (or (plist-get snapshot :state) 'idle))
              (format "end: %s" (or (plist-get snapshot :end-reason) "none"))
              (format "visible: %s" (if (plist-get snapshot :visible) "yes" "no"))
              (format "source: %s" (or (plist-get detail :request-source) "none"))
              (format "trigger-source: %s" (or (plist-get detail :trigger-source) "none"))
              (when (plist-get detail :cache-source)
                (format "cache-source: %s" (plist-get detail :cache-source)))
              (format "next-action: %s"
                      (or (plist-get detail :next-action-kind) 'none))
              (format "next-action-count: %s"
                      (or (plist-get detail :next-action-count) 0))
              (format "restore-available: %s"
                      (if (plist-get detail :restore-available) "yes" "no"))
              (format "divergence-distance: %s"
                      (or (plist-get detail :divergence-distance) 0))
              (format "profile: %s" (or (plist-get snapshot :profile) "none"))))
            (rc/gptel-action--section
             "Backend"
             (list
              (format "backend: %s" (or (plist-get snapshot :backend) "none"))
              (format "model: %s" (or (plist-get snapshot :model) "none"))
              (format "last-error: %s" (or (plist-get snapshot :last-error) "none"))))
            (and stats
                 (rc/gptel-action--section
                  "Stats"
                  (list
                   (format "requests: %s" (or (plist-get stats :request-count) 0))
                   (format "failures: %s" (or (plist-get stats :failure-count) 0)))))))
     "\n\n")))

(defun rc/gptel-action--transition-line (entry)
  "Return readable transition line for ENTRY."
  (cond
   ((not (listp entry))
    (format "- %s" entry))
   (t
    (format "- %-18s <- %-18s event=%s source=%s next=%s end=%s"
            (or (plist-get entry :state) 'unknown)
            (or (plist-get entry :previous-state) 'unknown)
            (or (plist-get entry :event) 'direct)
            (or (plist-get entry :source)
                (plist-get entry :trigger-source)
                'none)
            (or (plist-get entry :next-action-kind) 'none)
            (or (plist-get entry :end-reason) "none")))))

(defun rc/gptel-action--snapshot-line (snapshot current-buffer)
  "Return compact active snapshot line for SNAPSHOT relative to CURRENT-BUFFER."
  (let* ((detail (plist-get snapshot :detail))
         (buffer (plist-get snapshot :buffer))
         (same-buffer (eq buffer current-buffer))
         (kind (or (plist-get snapshot :action-kind) 'unknown))
         (state (or (plist-get snapshot :state) 'idle))
         (request-id (or (plist-get snapshot :request-id) "none"))
         (source (or (plist-get detail :request-source)
                     (plist-get detail :trigger-source)
                     'none))
         (next (or (plist-get detail :next-action-kind) 'none)))
    (format "- %s %-9s %-22s state=%-12s request=%-12s source=%-10s next=%s"
            (if same-buffer "*" " ")
            kind
            (buffer-name buffer)
            state
            request-id
            source
            next)))

(defun rc/gptel-describe-action-state ()
  "Show current unified AI action state in a temporary help buffer."
  (interactive)
  (let ((snapshot (and (fboundp 'rc/gptel-action-current-snapshot)
                       (rc/gptel-action-current-snapshot))))
    (unless snapshot
      (user-error "当前没有可展示的 AI action state"))
    (with-help-window "*AI Action State*"
      (princ (rc/gptel-action-state-summary snapshot))
      (let ((detail-lines (rc/gptel-action--detail-renderer snapshot)))
        (when detail-lines
          (princ "\n\nDetail:\n")
          (dolist (line detail-lines)
            (princ (concat line "\n")))))
      (let ((history (plist-get snapshot :history)))
        (when history
          (princ "\nRecent History:\n")
          (dolist (entry (seq-take history 12))
            (princ (concat (rc/gptel-action--history-line entry) "\n")))))
      (let ((transitions (plist-get snapshot :transitions)))
        (when transitions
          (princ "\nRecent State Transitions:\n")
          (dolist (entry (seq-take transitions 12))
            (princ (concat (rc/gptel-action--transition-line entry) "\n")))))
      (let ((snapshots (and (fboundp 'rc/gptel-action-snapshots)
                            (rc/gptel-action-snapshots))))
        (when snapshots
          (princ "\nAll Active Snapshots:\n")
          (princ "  `*` 表示当前 buffer\n")
          (dolist (item (seq-take snapshots 15))
            (princ
             (concat
              (rc/gptel-action--snapshot-line item (current-buffer))
              "\n"))))))))

(provide 'ai-action-inspect-rc)
;;; ai-action-inspect-rc.el ends here
