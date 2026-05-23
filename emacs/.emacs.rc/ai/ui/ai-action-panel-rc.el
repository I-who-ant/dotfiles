;;; ai-action-panel-rc.el --- Unified AI action panel -*- lexical-binding: t; -*-

;;; Code:

(require 'tabulated-list)

(defvar rc/gptel-action-panel-buffer-name "*AI Actions*"
  "Buffer name used by the unified AI action panel.")

(defun rc/gptel-action-panel--shorten (value width)
  "Return VALUE shortened to WIDTH with ellipsis when needed."
  (let ((text (format "%s" (or value ""))))
    (if (or (not (integerp width))
            (<= (length text) width))
        text
      (concat (substring text 0 (max 0 (- width 1))) "…"))))

(defun rc/gptel-action-panel--source-label (snapshot)
  "Return a concise source label for SNAPSHOT."
  (let* ((detail (plist-get snapshot :detail))
         (request-source (plist-get detail :request-source))
         (trigger-source (plist-get detail :trigger-source))
         (cache-source (plist-get detail :cache-source)))
    (cond
     ((eq request-source 'cache)
      (format "cache:%s" (or cache-source "unknown")))
     ((eq request-source 'manual) "manual")
     ((eq request-source 'auto) "auto")
     ((eq request-source 'followup) "follow")
     ((eq request-source 'region) "region")
     ((memq trigger-source '(lsp-suggestions signature-help flymake-diagnostics))
      (pcase trigger-source
        ('lsp-suggestions "lsp")
        ('signature-help "sig")
        ('flymake-diagnostics "fly")
        (_ (symbol-name trigger-source))))
     (request-source
      (symbol-name request-source))
     (t ""))))

(defun rc/gptel-action-panel--status-label (snapshot)
  "Return a concise status label for SNAPSHOT."
  (let* ((detail (plist-get snapshot :detail))
         (state (or (plist-get snapshot :state) 'idle))
         (end-reason (plist-get snapshot :end-reason))
         (visible (plist-get snapshot :visible))
         (display-phase (plist-get snapshot :display-phase))
         (requesting (plist-get snapshot :requesting-indicator-visible))
         (suppress-reason (plist-get detail :environment-suppress-reason))
         (cooldown-active (plist-get detail :cooldown-active))
         (cooldown-summary (plist-get detail :cooldown-summary)))
    (string-join
     (delq nil
           (list (symbol-name state)
                 (when visible "vis")
                 (when requesting "req")
                 (when (and display-phase (not (eq display-phase 'idle)))
                   (format "disp:%s" display-phase))
                 (when suppress-reason (format "deny:%s" suppress-reason))
                 (when cooldown-active
                   (format "cool:%s" (or cooldown-summary "active")))
                 (and end-reason
                      (format "end:%s"
                              (rc/gptel-action-panel--shorten end-reason 10)))))
     " ")))

(defun rc/gptel-action-panel--signal-label (snapshot)
  "Return a compact metrics label for SNAPSHOT."
  (let* ((detail (plist-get snapshot :detail))
         (candidate-count (or (plist-get detail :candidate-count) 0))
         (next-edit-count (or (plist-get detail :next-edit-queue-size)
                              (plist-get detail :followup-queue-size)
                              0))
         (accepted-kind (plist-get detail :accepted-kind))
         (accepted-length (or (plist-get detail :accepted-length) 0)))
    (string-join
     (delq nil
           (list
            (when (> candidate-count 0) (format "cand:%s" candidate-count))
            (when (> next-edit-count 0) (format "next:%s" next-edit-count))
            (when accepted-kind (format "acc:%s/%s" accepted-kind accepted-length))))
     " ")))

(defun rc/gptel-action-panel--next-label (snapshot)
  "Return a concise next-action label for SNAPSHOT."
  (let* ((detail (plist-get snapshot :detail))
         (kind (or (plist-get detail :next-action-kind) 'none))
         (count (or (plist-get detail :next-action-count) 0))
         (restore (plist-get detail :restore-available))
         (cont-kind (plist-get detail :continuation-next-step))
         (cont-reason (plist-get detail :continuation-next-reason)))
    (or (and cont-kind
             (not (eq cont-kind 'none))
             (not (eq cont-kind 'idle))
             (format "%s:%s" cont-kind (or cont-reason 'none)))
        (pcase kind
          ('restore-available
           (format "restore/%s" (max 0 count)))
          ('next-location
           (format "jump/%s" (max 0 count)))
          ('next-edit
           (format "next-edit/%s" (max 0 count)))
          ('followup
           (format "followup/%s" (max 0 count)))
          ('candidate-cycle
           (format "candidate/%s" (max 0 count)))
          ('cache-reuse
           (if restore "reuse+restore" "reuse"))
          (_
           (if restore "restore"
             (and cont-reason
                  (not (memq cont-reason '(nil none)))
                  (format "idle:%s" cont-reason))))))))

(defun rc/gptel-action-panel--issue-label (snapshot)
  "Return a readable issue/visibility label for SNAPSHOT."
  (let ((error (or (plist-get snapshot :last-error) ""))
        (visible (plist-get snapshot :visible)))
    (if (string-empty-p error)
        (if visible "visible" "quiet")
      error)))

(defun rc/gptel-action-panel--entry (snapshot)
  "Return one tabulated list entry for SNAPSHOT."
  (let* ((buffer (plist-get snapshot :buffer))
         (detail (plist-get snapshot :detail))
         (target (or (plist-get detail :file)
                     (plist-get detail :root)
                     (and (buffer-live-p buffer)
                          (buffer-name buffer))
                     "")))
    (list snapshot
          (vector
           (rc/gptel-action-panel--shorten
            (symbol-name (or (plist-get snapshot :action-kind) 'unknown)) 10)
           (rc/gptel-action-panel--shorten (or (plist-get snapshot :title) "") 30)
           (rc/gptel-action-panel--shorten
            (if (buffer-live-p buffer) (buffer-name buffer) "(dead)") 22)
           (rc/gptel-action-panel--shorten (or (plist-get snapshot :request-id) "none") 16)
           (rc/gptel-action-panel--shorten (rc/gptel-action-panel--source-label snapshot) 18)
           (rc/gptel-action-panel--shorten (rc/gptel-action-panel--status-label snapshot) 28)
           (rc/gptel-action-panel--shorten (rc/gptel-action-panel--signal-label snapshot) 24)
           (rc/gptel-action-panel--shorten (rc/gptel-action-panel--next-label snapshot) 18)
           (rc/gptel-action-panel--shorten target 28)
           (rc/gptel-action-panel--shorten
            (rc/gptel-action-panel--issue-label snapshot) 22)))))

(defun rc/gptel-action-panel-entries ()
  "Return current unified action panel entries."
  (mapcar #'rc/gptel-action-panel--entry
          (or (and (fboundp 'rc/gptel-action-snapshots)
                   (rc/gptel-action-snapshots))
              nil)))

(define-derived-mode rc/gptel-action-panel-mode tabulated-list-mode "AI-Actions"
  "Major mode for the unified AI action panel."
  (setq tabulated-list-format [("Kind" 12 t)
                               ("Title" 30 t)
                               ("Buffer" 22 t)
                               ("Request" 16 t)
                               ("Source" 18 t)
                               ("Status" 28 t)
                               ("Signal" 24 t)
                               ("Next" 18 t)
                               ("Target" 28 t)
                               ("Issue" 22 t)])
  (setq tabulated-list-padding 2)
  (keymap-set rc/gptel-action-panel-mode-map "g" #'rc/gptel-action-panel-revert)
  (keymap-set rc/gptel-action-panel-mode-map "RET" #'rc/gptel-action-panel-visit)
  (keymap-set rc/gptel-action-panel-mode-map "i" #'rc/gptel-action-panel-inspect)
  (keymap-set rc/gptel-action-panel-mode-map "q" #'quit-window)
  (tabulated-list-init-header)
  (setq header-line-format
        "g 刷新  RET 跳转 buffer  i inspector  q 退出    inline: TAB accept  M-f word  M-l line  M-RET next-edit  M-j jump  C-g clear"))

(defun rc/gptel-action-panel-refresh ()
  "Refresh unified action panel entries."
  (setq tabulated-list-entries (rc/gptel-action-panel-entries)))

(defun rc/gptel-action-panel-current-snapshot ()
  "Return current snapshot at point."
  (or (tabulated-list-get-id)
      (user-error "当前行没有 action snapshot")))

(defun rc/gptel-action-panel-visit ()
  "Visit buffer referenced by current action snapshot."
  (interactive)
  (let ((buffer (plist-get (rc/gptel-action-panel-current-snapshot) :buffer)))
    (unless (buffer-live-p buffer)
      (user-error "当前 action 对应 buffer 已不存在"))
    (pop-to-buffer buffer)))

(defun rc/gptel-action-panel-inspect ()
  "Open unified inspector for current action snapshot."
  (interactive)
  (let ((buffer (plist-get (rc/gptel-action-panel-current-snapshot) :buffer)))
    (unless (buffer-live-p buffer)
      (user-error "当前 action 对应 buffer 已不存在"))
    (with-current-buffer buffer
      (rc/gptel-describe-action-state))))

(defun rc/gptel-action-panel-revert ()
  "Revert unified action panel."
  (interactive)
  (rc/gptel-action-panel-refresh)
  (tabulated-list-print t))

(defun rc/gptel-action-panel ()
  "Open the unified AI action panel."
  (interactive)
  (let ((buffer (get-buffer-create rc/gptel-action-panel-buffer-name)))
    (with-current-buffer buffer
      (rc/gptel-action-panel-mode)
      (unless (eq major-mode 'rc/gptel-action-panel-mode)
        (rc/gptel-action-panel-mode))
      (let ((inhibit-read-only t))
        (rc/gptel-action-panel-revert)))
    (pop-to-buffer buffer)))

(provide 'ai-action-panel-rc)
;;; ai-action-panel-rc.el ends here
