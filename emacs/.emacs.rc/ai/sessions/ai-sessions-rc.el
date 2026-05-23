;;; ai-sessions-rc.el --- AI session registry and panel  -*- lexical-binding: t; -*-

;;; Code:

(require 'tabulated-list)

(defvar rc/gptel-chat-session-history nil
  "Minibuffer history for chat session selection.")

(defvar rc/gptel-session-panel-buffer-name "*AI Sessions*"
  "Buffer name used by the unified AI session panel.")

(defvar rc/gptel-session-panel-history nil
  "Minibuffer history used by the AI session panel.")

(defconst rc/gptel-session-panel-preview-lines 5
  "Default number of preview lines shown initially.")

(defvar-local rc/gptel-session-panel-type 'ask
  "Current session type shown in the unified session panel.")

(defvar-local rc/gptel-session-panel-preview-target nil
  "Session currently expanded for inline preview.")

(defvar-local rc/gptel-session-panel-preview-active nil
  "Non-nil when point is navigating inline preview text.")

(defvar-local rc/gptel-session-panel-preview-offset 0
  "Current starting line offset of inline preview.")

(defvar-local rc/gptel-session-panel-root-directory nil
  "Directory root currently tracked by the session panel.")

;;;; Panel refresh and index sync

(defun rc/gptel-refresh-open-session-panels (&optional root)
  "Refresh all open AI session panels, optionally scoped to ROOT."
  (let ((panel (get-buffer rc/gptel-session-panel-buffer-name)))
    (when (buffer-live-p panel)
      (with-current-buffer panel
        (when (derived-mode-p 'rc/gptel-session-panel-mode)
          (when (or (null root)
                    (null rc/gptel-session-panel-root-directory)
                    (equal (file-truename (rc/gptel-current-session-root root))
                           (file-truename
                            (rc/gptel-current-session-root
                             rc/gptel-session-panel-root-directory))))
            (let ((target (ignore-errors (rc/gptel-session-panel-current-target)))
                  (line (line-number-at-pos)))
              (rc/gptel-session-panel-revert)
              (when target
                (or (rc/gptel-session-panel-goto-entry target)
                    (goto-char (point-min))
                    (forward-line (max 0 (1- line))))))))))))

(defun rc/gptel-current-ask-entry-save-file ()
  "Return save file of current active ask session, else nil."
  (when (and (buffer-live-p rc/gptel-current-ask-buffer)
             (buffer-local-value 'rc/gptel-ask-session-save-file
                                 rc/gptel-current-ask-buffer))
    (buffer-local-value 'rc/gptel-ask-session-save-file
                        rc/gptel-current-ask-buffer)))

(defun rc/gptel-session-panel-root ()
  "Return current directory-local root for ask sessions."
  (rc/gptel-current-session-root
   (or rc/gptel-session-panel-root-directory
       default-directory)))

(defun rc/gptel-ask-index-entries (&optional root)
  "Return serialized ask session entries for ROOT."
  (or (rc/gptel-read-elisp-file (rc/gptel-session-index-file root))
      '()))

(defun rc/gptel-build-ask-index-entry-from-meta (meta)
  "Return one ask index entry built from META."
  (let* ((turns (plist-get meta :turns))
         (question-count (if (listp turns)
                             (length turns)
                           (or (plist-get meta :question-count) 0))))
    (list :id (or (plist-get meta :id) 0)
          :root (plist-get meta :root)
          :file (plist-get meta :file)
          :save-file (plist-get meta :save-file)
          :meta-file (and (plist-get meta :save-file)
                          (rc/gptel-session-meta-file (plist-get meta :save-file)))
          :question-count question-count
          :updated-at (plist-get meta :updated-at)
          :title (or (plist-get meta :title)
                     (and (plist-get meta :save-file)
                          (file-name-base (plist-get meta :save-file)))))))

(defun rc/gptel-ensure-ask-index-for-root (&optional root)
  "Ensure current directory ask sessions under ROOT are present in index."
  (let* ((root (rc/gptel-current-session-root root))
         (sessions-dir (rc/gptel-session-md-dir root))
         (index-file (rc/gptel-session-index-file root))
         (existing (or (rc/gptel-read-elisp-file index-file) '()))
         refreshed)
    (when (file-directory-p sessions-dir)
      (dolist (save-file (directory-files sessions-dir t "\\.md\\'"))
        (let* ((meta (rc/gptel-ensure-ask-meta-file save-file))
               (entry (rc/gptel-build-ask-index-entry-from-meta meta)))
          (push entry refreshed))))
    (setq refreshed
          (seq-filter
           (lambda (item)
             (let ((save-file (plist-get item :save-file)))
               (and save-file (file-exists-p save-file))))
           refreshed))
    (when (and (null refreshed) existing)
      (setq refreshed
            (seq-filter
             (lambda (item)
               (let ((save-file (plist-get item :save-file)))
                 (and save-file (file-exists-p save-file))))
             existing)))
    (when refreshed
      (setq refreshed
            (sort refreshed
                  (lambda (a b)
                    (string> (or (plist-get a :updated-at) "")
                             (or (plist-get b :updated-at) "")))))
      (rc/gptel-write-elisp-file index-file refreshed))
    refreshed))

(defun rc/gptel-find-live-ask-buffer (save-file)
  "Return live ask buffer corresponding to SAVE-FILE, else nil."
  (seq-find
   (lambda (buffer)
     (and (rc/gptel-ask-session-valid-p buffer)
          (equal (buffer-local-value 'rc/gptel-ask-session-save-file buffer)
                 save-file)))
   (buffer-list)))

(defun rc/gptel-chat-session-buffers ()
  "Return all live gptel chat buffers."
  (rc/gptel-ensure-core)
  (seq-filter
   (lambda (buffer)
     (and (buffer-live-p buffer)
          (buffer-local-value 'gptel-mode buffer)))
     (buffer-list)))

;;;; Panel rendering

(defun rc/gptel-session-panel-tab-label (type)
  "Return a formatted tab label for TYPE."
  (let ((active (eq rc/gptel-session-panel-type type)))
    (propertize
     (format "[%s]" (upcase (symbol-name type)))
     'face (if active 'mode-line-emphasis 'shadow))))

(defun rc/gptel-session-panel-help-line ()
  "Return the help line shown at the top of the session panel."
  (string-join
   (list
    (format "Tabs %s %s"
            (rc/gptel-session-panel-tab-label 'ask)
            (rc/gptel-session-panel-tab-label 'chat))
    "TAB/C-f/C-b 切换"
    "RET 激活"
    "C-RET 显示"
    "SPC 预览"
    "f 源文件"
    "m 会话文件"
    "r 重命名"
    "D 删除"
    "n 新建 chat"
    "s 进入 send"
    "k 中断"
    "g 刷新"
    "q 退出")
   "   "))

(defun rc/gptel-session-panel-title ()
  "Return title string for current AI session panel type."
  (format "*AI Sessions:%s*" (upcase (symbol-name rc/gptel-session-panel-type))))

(defun rc/gptel-session-entry-status (buffer)
  "Return status string for BUFFER."
  (cond
   ((ignore-errors (rc/gptel-buffer-active-request-p buffer)) "running")
   ((and (eq rc/gptel-session-panel-type 'ask)
         (buffer-live-p rc/gptel-current-ask-buffer)
         (eq buffer rc/gptel-current-ask-buffer))
    "active")
   ((buffer-modified-p buffer) "modified")
   (t "loaded")))

(defun rc/gptel-session-panel-ensure-ask-buffer (target)
  "Return a materialized live ask buffer for TARGET."
  (let* ((entry (rc/gptel-session-panel-target-entry target))
         (buffer (rc/gptel-activate-ask-session entry)))
    (when (and (buffer-live-p buffer)
               (zerop (buffer-size buffer)))
      (let ((state (rc/gptel-load-ask-session-state entry)))
        (with-current-buffer buffer
          (setq rc/gptel-ask-session-id (plist-get state :id)
                rc/gptel-ask-session-root (plist-get state :root)
                rc/gptel-ask-session-file (plist-get state :file)
                rc/gptel-ask-session-source (plist-get state :source)
                rc/gptel-ask-session-turns (plist-get state :turns)
                rc/gptel-ask-session-history (plist-get state :history)
                rc/gptel-ask-session-question-count (plist-get state :question-count)
                rc/gptel-ask-session-source-count (plist-get state :source-count)
                rc/gptel-ask-session-save-file (plist-get state :save-file))
          (rc/gptel-render-ask-session-buffer
           buffer
           rc/gptel-ask-session-source
           rc/gptel-ask-session-turns))))
    buffer))

(defun rc/gptel-ask-session-entry (entry)
  "Build one tabulated entry from serialized ask ENTRY."
  (let* ((save-file (plist-get entry :save-file))
         (live-buffer (and save-file (rc/gptel-find-live-ask-buffer save-file)))
         (current-mark (if (equal save-file (rc/gptel-current-ask-entry-save-file))
                           "*"
                         " "))
         (title (or (plist-get entry :title)
                    (and save-file (file-name-base save-file))
                    "ask"))
         (target (or (plist-get entry :file)
                     (plist-get entry :root)
                     ""))
         (count (number-to-string (or (plist-get entry :question-count) 0)))
         (status (cond
                  ((equal save-file (rc/gptel-current-ask-entry-save-file))
                   "active")
                  (live-buffer
                   (rc/gptel-session-entry-status live-buffer))
                  (t
                   "saved"))))
    (list entry (vector current-mark title target count status))))

(defun rc/gptel-chat-session-entry (buffer)
  "Build one tabulated entry for chat BUFFER."
  (with-current-buffer buffer
    (list buffer
          (vector " "
                  (buffer-name buffer)
                  (format "%s/%s"
                          (if (boundp 'gptel-backend)
                              (gptel-backend-name gptel-backend)
                            "?")
                          (or (and (boundp 'gptel-model) gptel-model) "?"))
                  "-"
                  (rc/gptel-session-entry-status buffer)))))

(defun rc/gptel-session-panel-entries ()
  "Return entries for the current AI session panel type."
  (pcase rc/gptel-session-panel-type
    ('ask (mapcar #'rc/gptel-ask-session-entry
                  (rc/gptel-ask-index-entries (rc/gptel-session-panel-root))))
    ('chat (mapcar #'rc/gptel-chat-session-entry
                   (rc/gptel-chat-session-buffers)))
    (_ nil)))

(define-derived-mode rc/gptel-session-panel-mode tabulated-list-mode "AI-Sessions"
  "Major mode for the unified AI session panel."
  (setq tabulated-list-format [("Cur" 4 t)
                               ("Session" 36 t)
                               ("Target" 44 t)
                               ("Count" 8 t)
                               ("Status" 12 t)])
  (setq tabulated-list-padding 2)
  (setq header-line-format '(:eval (rc/gptel-session-panel-help-line)))
  (tabulated-list-init-header))

;;;; Preview navigation

(defun rc/gptel-session-panel-refresh ()
  "Refresh current session panel entries."
  (setq rc/gptel-session-panel-preview-active nil)
  (setq rc/gptel-session-panel-preview-offset 0)
  (when (eq rc/gptel-session-panel-type 'ask)
    (rc/gptel-ensure-ask-index-for-root (rc/gptel-session-panel-root)))
  (setq tabulated-list-entries (rc/gptel-session-panel-entries)))

(defun rc/gptel-session-panel-current-target ()
  "Return current session target."
  (or (get-text-property (point) 'rc/gptel-session-preview-owner)
      (tabulated-list-get-id)
      (user-error "当前行没有 session")))

(defun rc/gptel-session-panel-target-save-file (target)
  "Return save file path for ask TARGET, else nil."
  (cond
   ((bufferp target)
    (and (rc/gptel-ask-session-valid-p target)
         (buffer-local-value 'rc/gptel-ask-session-save-file target)))
   ((listp target)
    (plist-get target :save-file))
   (t nil)))

(defun rc/gptel-session-panel-target-root (target)
  "Return root path for TARGET."
  (cond
   ((bufferp target)
    (and (rc/gptel-ask-session-valid-p target)
         (buffer-local-value 'rc/gptel-ask-session-root target)))
   ((listp target)
    (plist-get target :root))
   (t nil)))

(defun rc/gptel-session-panel-target-source-file (target)
  "Return source file path for TARGET."
  (cond
   ((bufferp target)
    (and (rc/gptel-ask-session-valid-p target)
         (buffer-local-value 'rc/gptel-ask-session-file target)))
   ((listp target)
    (plist-get target :file))
   (t nil)))

(defun rc/gptel-session-panel-target-meta-file (target)
  "Return meta file path for TARGET."
  (let ((save-file (rc/gptel-session-panel-target-save-file target)))
    (and save-file (rc/gptel-session-meta-file save-file))))

(defun rc/gptel-session-panel-target-entry (target)
  "Return serialized ask entry plist for TARGET."
  (cond
   ((bufferp target)
    (rc/gptel-ask-index-entry target))
   ((listp target) target)
   (t
    (user-error "当前 ask session 无法恢复"))))

(defun rc/gptel-session-panel-preview-text (target)
  "Return raw preview text for TARGET."
  (cond
   ((bufferp target)
    (with-current-buffer target
      (buffer-substring-no-properties (point-min) (point-max))))
   ((listp target)
    (let ((save-file (plist-get target :save-file)))
      (if (and save-file (file-exists-p save-file))
          (with-temp-buffer
            (insert-file-contents save-file)
            (buffer-substring-no-properties (point-min) (point-max)))
        "")))
   (t "")))

(defun rc/gptel-session-panel-preview-lines-list (target)
  "Return all preview lines for TARGET."
  (split-string (rc/gptel-session-panel-preview-text target) "\n"))

(defun rc/gptel-session-panel-preview-max-offset (target)
  "Return maximum valid preview offset for TARGET."
  (max 0 (- (length (rc/gptel-session-panel-preview-lines-list target))
            rc/gptel-session-panel-preview-lines)))

(defun rc/gptel-session-panel-preview-line-index ()
  "Return zero-based visual line index inside current preview block."
  (save-excursion
    (let ((line 0))
      (beginning-of-line)
      (while (and (> (point) (point-min))
                  (progn
                    (forward-line -1)
                    (get-text-property (point) 'rc/gptel-session-preview)))
        (setq line (1+ line)))
      line)))

(defun rc/gptel-session-panel-preview-string (target)
  "Return inline preview string for TARGET."
  (let* ((all-lines (rc/gptel-session-panel-preview-lines-list target))
         (total (length all-lines))
         (offset (min rc/gptel-session-panel-preview-offset
                      (max 0 (- total rc/gptel-session-panel-preview-lines))))
         (lines (seq-take (nthcdr offset all-lines) rc/gptel-session-panel-preview-lines))
         (from (if (> total 0) (1+ offset) 0))
         (to (min total (+ offset (length lines)))))
    (concat
     (propertize (format "    --- preview %d-%d/%d ---\n" from to total)
                 'face 'shadow)
     (mapconcat
      (lambda (line)
        (concat "    " (propertize line 'face 'shadow)))
      lines
      "\n")
     "\n")))

(defun rc/gptel-session-panel-clear-preview-block ()
  "Remove all inline preview blocks from current panel."
  (let ((inhibit-read-only t))
    (save-excursion
      (goto-char (point-min))
      (while (< (point) (point-max))
        (if (get-text-property (point) 'rc/gptel-session-preview)
            (let ((start (line-beginning-position)))
              (forward-line 1)
              (while (and (< (point) (point-max))
                          (get-text-property (point) 'rc/gptel-session-preview))
                (forward-line 1))
              (delete-region start (point)))
          (forward-line 1))))))

(defun rc/gptel-session-panel-goto-entry (target)
  "Move point to tabulated row whose id is TARGET."
  (goto-char (point-min))
  (catch 'found
    (while (< (point) (point-max))
      (when (equal (tabulated-list-get-id) target)
        (throw 'found t))
      (forward-line 1))
    nil))

(defun rc/gptel-session-panel-place-preview ()
  "Place inline preview below the current session row when needed."
  (rc/gptel-session-panel-clear-preview-block)
  (when (and rc/gptel-session-panel-preview-target
             (rc/gptel-session-panel-goto-entry rc/gptel-session-panel-preview-target))
    (let ((preview
           (propertize
            (rc/gptel-session-panel-preview-string
             rc/gptel-session-panel-preview-target)
            'rc/gptel-session-preview t
            'rc/gptel-session-preview-owner rc/gptel-session-panel-preview-target
            'read-only t
            'front-sticky t
            'rear-nonsticky nil)))
      (save-excursion
        (forward-line 1)
        (insert preview)))))

(defun rc/gptel-session-panel-preview-start ()
  "Move point to first preview line, if any."
  (when rc/gptel-session-panel-preview-target
    (rc/gptel-session-panel-goto-entry rc/gptel-session-panel-preview-target)
    (forward-line 1)
    (when (get-text-property (point) 'rc/gptel-session-preview)
      (setq rc/gptel-session-panel-preview-active t)
      (beginning-of-line))))

(defun rc/gptel-session-panel-preview-recenter (line-index)
  "Redraw preview and place point at preview LINE-INDEX."
  (let ((line-index (max 0 (min line-index (1- rc/gptel-session-panel-preview-lines)))))
    (rc/gptel-session-panel-render)
    (rc/gptel-session-panel-preview-start)
    (forward-line line-index)
    (when (not (get-text-property (point) 'rc/gptel-session-preview))
      (forward-line -1))
    (beginning-of-line)))

(defun rc/gptel-session-panel-preview-scroll (delta &optional line-index)
  "Scroll preview by DELTA lines and keep point near LINE-INDEX."
  (let* ((target rc/gptel-session-panel-preview-target)
         (max-offset (rc/gptel-session-panel-preview-max-offset target))
         (target-offset (max 0 (min (+ rc/gptel-session-panel-preview-offset delta)
                                    max-offset))))
    (if (= target-offset rc/gptel-session-panel-preview-offset)
        nil
      (setq rc/gptel-session-panel-preview-offset target-offset)
      (rc/gptel-session-panel-preview-recenter
       (or line-index (rc/gptel-session-panel-preview-line-index)))
      t)))

(defun rc/gptel-session-panel-next-line ()
  "Move down in panel or scroll preview down when active."
  (interactive)
  (if (not rc/gptel-session-panel-preview-active)
      (call-interactively #'next-line)
    (let ((line-index (rc/gptel-session-panel-preview-line-index)))
      (cond
       ((save-excursion
          (forward-line 1)
          (get-text-property (point) 'rc/gptel-session-preview))
        (forward-line 1)
        (beginning-of-line))
       ((rc/gptel-session-panel-preview-scroll 1 line-index))
       (t
        (message "Preview 已到底部"))))))

(defun rc/gptel-session-panel-previous-line ()
  "Move up in panel or scroll preview up when active."
  (interactive)
  (if (not rc/gptel-session-panel-preview-active)
      (call-interactively #'previous-line)
    (let ((line-index (rc/gptel-session-panel-preview-line-index)))
      (cond
       ((save-excursion
          (forward-line -1)
          (get-text-property (point) 'rc/gptel-session-preview))
        (forward-line -1)
        (beginning-of-line))
       ((rc/gptel-session-panel-preview-scroll -1 line-index))
       (t
        (message "Preview 已到顶部"))))))

(defun rc/gptel-session-panel-scroll-up-command ()
  "Preview-aware replacement for `scroll-up-command'."
  (interactive)
  (if (not rc/gptel-session-panel-preview-active)
      (call-interactively #'scroll-up-command)
    (unless (rc/gptel-session-panel-preview-scroll rc/gptel-session-panel-preview-lines 0)
      (message "Preview 已到底部"))))

(defun rc/gptel-session-panel-scroll-down-command ()
  "Preview-aware replacement for `scroll-down-command'."
  (interactive)
  (if (not rc/gptel-session-panel-preview-active)
      (call-interactively #'scroll-down-command)
    (unless (rc/gptel-session-panel-preview-scroll (- rc/gptel-session-panel-preview-lines) 0)
      (message "Preview 已到顶部"))))

(defun rc/gptel-session-panel-beginning-of-buffer ()
  "Preview-aware replacement for `beginning-of-buffer'."
  (interactive)
  (if (not rc/gptel-session-panel-preview-active)
      (call-interactively #'beginning-of-buffer)
    (progn
      (rc/gptel-session-panel-preview-scroll
       (- rc/gptel-session-panel-preview-offset) 0)
      (message "Preview 已到顶部"))))

(defun rc/gptel-session-panel-end-of-buffer ()
  "Preview-aware replacement for `end-of-buffer'."
  (interactive)
  (if (not rc/gptel-session-panel-preview-active)
      (call-interactively #'end-of-buffer)
    (let ((delta (- (rc/gptel-session-panel-preview-max-offset
                     rc/gptel-session-panel-preview-target)
                    rc/gptel-session-panel-preview-offset)))
      (rc/gptel-session-panel-preview-scroll delta (1- rc/gptel-session-panel-preview-lines))
      (message "Preview 已到底部"))))

(defun rc/gptel-session-panel-exit-preview ()
  "Leave inline preview navigation and return to owning session row."
  (interactive)
  (setq rc/gptel-session-panel-preview-active nil)
  (when rc/gptel-session-panel-preview-target
    (rc/gptel-session-panel-goto-entry rc/gptel-session-panel-preview-target)
    (beginning-of-line)))

;;;; Entry actions

(defun rc/gptel-session-panel-render ()
  "Render unified AI session panel."
  (let ((inhibit-read-only t))
    (setq mode-name (rc/gptel-session-panel-title))
    (erase-buffer)
    (insert (propertize
             (format "AI Sessions  [%s]\n" (upcase (symbol-name rc/gptel-session-panel-type)))
             'face 'bold))
    (insert (rc/gptel-session-panel-help-line))
    (insert "\n\n")
    (tabulated-list-print t)
    (rc/gptel-session-panel-place-preview)))

(defun rc/gptel-session-panel-revert ()
  "Refresh and redraw current session panel."
  (interactive)
  (rc/gptel-session-panel-refresh)
  (rc/gptel-session-panel-render)
  (goto-char (point-min))
  (forward-line 2))

(defun rc/gptel-session-panel-next-type ()
  "Switch session panel to next type."
  (interactive)
  (setq rc/gptel-session-panel-type
        (if (eq rc/gptel-session-panel-type 'ask) 'chat 'ask))
  (setq rc/gptel-session-panel-preview-target nil)
  (rc/gptel-session-panel-revert))

(defun rc/gptel-session-panel-prev-type ()
  "Switch session panel to previous type."
  (interactive)
  (rc/gptel-session-panel-next-type))

(defun rc/gptel-session-panel-toggle-type ()
  "Toggle AI session panel type."
  (interactive)
  (rc/gptel-session-panel-next-type))

(defun rc/gptel-session-panel-open-source-file ()
  "Open source file of current ask session."
  (interactive)
  (unless (eq rc/gptel-session-panel-type 'ask)
    (user-error "当前只有 ask session 关联源文件"))
  (let ((file (rc/gptel-session-panel-target-source-file
               (rc/gptel-session-panel-current-target))))
    (unless (and file (file-exists-p file))
      (user-error "当前 session 没有可打开的源文件"))
    (find-file-other-window file)))

(defun rc/gptel-session-panel-open-session-file ()
  "Open markdown session file of current ask session."
  (interactive)
  (unless (eq rc/gptel-session-panel-type 'ask)
    (user-error "当前只有 ask session 关联会话文件"))
  (let ((save-file (rc/gptel-session-panel-target-save-file
                    (rc/gptel-session-panel-current-target))))
    (unless (and save-file (file-exists-p save-file))
      (user-error "当前 session 还没有会话文件"))
    (find-file-other-window save-file)))

(defun rc/gptel-session-panel-prune-ask-index (root save-file)
  "Remove SAVE-FILE from ask index under ROOT."
  (let* ((index-file (rc/gptel-session-index-file root))
         (existing (or (rc/gptel-read-elisp-file index-file) '()))
         (filtered (seq-remove
                    (lambda (item)
                      (equal (plist-get item :save-file) save-file))
                    existing)))
    (if filtered
        (rc/gptel-write-elisp-file index-file filtered)
      (when (file-exists-p index-file)
        (delete-file index-file)))))

(defun rc/gptel-session-panel-rename ()
  "Rename current session row."
  (interactive)
  (let ((target (rc/gptel-session-panel-current-target)))
    (pcase rc/gptel-session-panel-type
      ('ask
       (let* ((old-title (if (bufferp target)
                             (or (buffer-local-value 'rc/gptel-ask-session-title target)
                                 (buffer-name target))
                           (or (plist-get target :title) "ask")))
              (new-title (string-trim
                          (read-string "Session title: " old-title
                                       'rc/gptel-session-panel-history old-title))))
         (when (string-empty-p new-title)
           (user-error "标题不能为空"))
         (cond
          ((bufferp target)
           (with-current-buffer target
             (setq rc/gptel-ask-session-title new-title)
             (when rc/gptel-ask-session-save-file
               (rc/gptel-write-ask-session-meta target)
               (rc/gptel-update-ask-session-index target))))
          ((listp target)
           (let ((meta-file (rc/gptel-session-panel-target-meta-file target))
                 (save-file (plist-get target :save-file))
                 (root (or (plist-get target :root)
                           (rc/gptel-session-panel-root))))
             (when (and meta-file (file-exists-p meta-file))
               (let ((meta (rc/gptel-read-elisp-file meta-file)))
                 (setq meta (plist-put meta :title new-title))
                 (rc/gptel-write-elisp-file meta-file meta)))
             (let* ((index-file (rc/gptel-session-index-file root))
                    (entries (or (rc/gptel-read-elisp-file index-file) '()))
                    (updated
                     (mapcar
                      (lambda (entry)
                        (if (equal (plist-get entry :save-file) save-file)
                            (plist-put (copy-sequence entry) :title new-title)
                          entry))
                      entries)))
               (rc/gptel-write-elisp-file index-file updated)))))
         (rc/gptel-session-panel-revert)
         (message "已重命名 session: %s" new-title)))
      ('chat
       (let* ((old-name (buffer-name target))
              (new-name (string-trim
                         (read-string "Chat buffer name: " old-name
                                      'rc/gptel-session-panel-history old-name))))
         (when (string-empty-p new-name)
           (user-error "标题不能为空"))
         (with-current-buffer target
           (rename-buffer new-name t))
         (rc/gptel-session-panel-revert)
         (message "已重命名 chat: %s" new-name))))))

(defun rc/gptel-session-panel-delete ()
  "Delete current session row."
  (interactive)
  (let ((target (rc/gptel-session-panel-current-target)))
    (pcase rc/gptel-session-panel-type
      ('ask
       (let* ((save-file (rc/gptel-session-panel-target-save-file target))
              (meta-file (rc/gptel-session-panel-target-meta-file target))
              (root (or (rc/gptel-session-panel-target-root target)
                        (rc/gptel-session-panel-root)))
              (title (if (bufferp target)
                         (buffer-name target)
                       (or (plist-get target :title) "ask"))))
         (unless save-file
           (user-error "这个 ask session 还没有持久化文件，没法删除记录"))
         (unless (yes-or-no-p (format "删除 ask session `%s` 及其会话文件？ " title))
           (user-error "已取消删除"))
         (when (and (bufferp target) (buffer-live-p target))
           (when (eq target rc/gptel-current-ask-buffer)
             (setq rc/gptel-current-ask-buffer nil))
           (kill-buffer target))
         (rc/gptel-session-panel-prune-ask-index root save-file)
         (when (and meta-file (file-exists-p meta-file))
           (delete-file meta-file))
         (when (file-exists-p save-file)
           (delete-file save-file))
         (rc/gptel-session-panel-revert)
         (message "已删除 ask session: %s" title)))
      ('chat
       (let ((name (buffer-name target)))
         (unless (yes-or-no-p (format "删除 chat buffer `%s` ? " name))
           (user-error "已取消删除"))
         (kill-buffer target)
         (rc/gptel-session-panel-revert)
         (message "已删除 chat: %s" name))))))

(defun rc/gptel-session-panel-toggle-preview ()
  "Toggle inline preview below current session row."
  (interactive)
  (if rc/gptel-session-panel-preview-active
      (rc/gptel-session-panel-exit-preview)
    (let ((target (rc/gptel-session-panel-current-target)))
      (if (equal rc/gptel-session-panel-preview-target target)
          (setq rc/gptel-session-panel-preview-target nil
                rc/gptel-session-panel-preview-offset 0)
        (setq rc/gptel-session-panel-preview-target target
              rc/gptel-session-panel-preview-offset 0))
      (rc/gptel-session-panel-render)
      (when rc/gptel-session-panel-preview-target
        (rc/gptel-session-panel-goto-entry target)
        (rc/gptel-session-panel-preview-start)))))

(defun rc/gptel-session-panel-activate ()
  "Activate AI session at point without forcing display."
  (interactive)
  (let ((target (rc/gptel-session-panel-current-target)))
    (pcase rc/gptel-session-panel-type
      ('ask
       (let ((save-file (rc/gptel-session-panel-target-save-file target)))
         (if (and save-file
                  (equal save-file (rc/gptel-current-ask-entry-save-file)))
             (progn
               (setq rc/gptel-current-ask-buffer nil)
               (rc/gptel-session-panel-revert)
               (message "已取消激活 ask session"))
           (setq rc/gptel-current-ask-buffer
                 (rc/gptel-session-panel-ensure-ask-buffer target))
           (rc/gptel-refresh-open-session-panels
            (rc/gptel-session-panel-target-root target))
           (message "已激活 ask session"))))
      ('chat
       (message "chat 直接用 C-RET/SPC 显示")))))

(defun rc/gptel-session-panel-visit ()
  "Activate AI session at point and display it."
  (interactive)
  (let ((panel-buffer (current-buffer)))
    (pcase rc/gptel-session-panel-type
      ('ask
       (let ((buffer (rc/gptel-session-panel-ensure-ask-buffer
                      (rc/gptel-session-panel-current-target))))
         (setq rc/gptel-current-ask-buffer buffer)
         (when (buffer-live-p buffer)
           (with-current-buffer buffer
             (rc/gptel-render-ask-session-buffer
              buffer
              rc/gptel-ask-session-source
              rc/gptel-ask-session-turns)
             (goto-char (point-min)))
           (with-current-buffer panel-buffer
             (rc/gptel-session-panel-revert))
           (rc/gptel-show-answer-buffer buffer)
           (let ((window (get-buffer-window buffer t)))
             (when (window-live-p window)
               (set-window-buffer window buffer)
               (set-window-point window (point-min))
               (set-window-start window (point-min) t))))))
      ('chat
       (pop-to-buffer (rc/gptel-session-panel-current-target))))))

(defun rc/gptel-session-panel-new-chat ()
  "Create and open a new gptel chat session."
  (interactive)
  (rc/gptel-ensure-core)
  (let* ((backend (or (default-value 'gptel-backend) gptel-backend))
         (name (generate-new-buffer-name
                (format "*%s*"
                        (if backend
                            (gptel-backend-name backend)
                          "gptel")))))
    (gptel name nil nil t)
    (setq rc/gptel-session-panel-type 'chat)
    (rc/gptel-session-panel-revert)))

(defun rc/gptel-session-panel-send ()
  "Jump to gptel send entrypoint."
  (interactive)
  (call-interactively #'rc/gptel-send-command))

(defun rc/gptel-session-panel-abort ()
  "Abort active request for session at point."
  (interactive)
  (let ((target (rc/gptel-session-panel-current-target)))
    (if (and (bufferp target)
             (rc/gptel-buffer-active-request-p target))
        (progn
          (gptel-abort target)
          (rc/gptel-session-panel-revert)
        (message "已中断 %s" (buffer-name target)))
      (user-error "当前 session 没有正在运行的请求"))))

;;;; Mode commands

(defun rc/gptel-session-panel-open-buffer ()
  "Open or return unified AI session panel buffer."
  (let ((buffer (get-buffer-create rc/gptel-session-panel-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'rc/gptel-session-panel-mode)
        (rc/gptel-session-panel-mode)
        (setq-local cursor-type nil)
        (setq-local rc/gptel-session-panel-type 'ask)
        (keymap-set rc/gptel-session-panel-mode-map "TAB" #'rc/gptel-session-panel-toggle-type)
        (keymap-set rc/gptel-session-panel-mode-map "C-f" #'rc/gptel-session-panel-next-type)
        (keymap-set rc/gptel-session-panel-mode-map "C-b" #'rc/gptel-session-panel-prev-type)
        (keymap-set rc/gptel-session-panel-mode-map "g" #'rc/gptel-session-panel-revert)
        (keymap-set rc/gptel-session-panel-mode-map "SPC" #'rc/gptel-session-panel-toggle-preview)
        (keymap-set rc/gptel-session-panel-mode-map "f" #'rc/gptel-session-panel-open-source-file)
        (keymap-set rc/gptel-session-panel-mode-map "m" #'rc/gptel-session-panel-open-session-file)
        (keymap-set rc/gptel-session-panel-mode-map "r" #'rc/gptel-session-panel-rename)
        (keymap-set rc/gptel-session-panel-mode-map "D" #'rc/gptel-session-panel-delete)
        (keymap-set rc/gptel-session-panel-mode-map "n" #'rc/gptel-session-panel-new-chat)
        (keymap-set rc/gptel-session-panel-mode-map "s" #'rc/gptel-session-panel-send)
        (keymap-set rc/gptel-session-panel-mode-map "k" #'rc/gptel-session-panel-abort)
        (keymap-set rc/gptel-session-panel-mode-map "q"
                    (lambda ()
                      (interactive)
                      (if rc/gptel-session-panel-preview-active
                          (rc/gptel-session-panel-exit-preview)
                        (quit-window))))
        (keymap-set rc/gptel-session-panel-mode-map "RET" #'rc/gptel-session-panel-activate)
        (let ((ctrl-return (ignore-errors (kbd "<C-return>"))))
          (when ctrl-return
            (define-key rc/gptel-session-panel-mode-map ctrl-return
                        #'rc/gptel-session-panel-visit)))
        (define-key rc/gptel-session-panel-mode-map [remap next-line]
                    #'rc/gptel-session-panel-next-line)
        (define-key rc/gptel-session-panel-mode-map [remap previous-line]
                    #'rc/gptel-session-panel-previous-line)
        (define-key rc/gptel-session-panel-mode-map [remap scroll-up-command]
                    #'rc/gptel-session-panel-scroll-up-command)
        (define-key rc/gptel-session-panel-mode-map [remap scroll-down-command]
                    #'rc/gptel-session-panel-scroll-down-command)
        (define-key rc/gptel-session-panel-mode-map [remap beginning-of-buffer]
                    #'rc/gptel-session-panel-beginning-of-buffer)
        (define-key rc/gptel-session-panel-mode-map [remap end-of-buffer]
                    #'rc/gptel-session-panel-end-of-buffer)
        (keymap-set rc/gptel-session-panel-mode-map "<down>" #'rc/gptel-session-panel-next-line)
        (keymap-set rc/gptel-session-panel-mode-map "<up>" #'rc/gptel-session-panel-previous-line))
      (rc/gptel-session-panel-revert))
    buffer))

(defun rc/gptel-session-panel-caller-root ()
  "Return caller root for opening the session panel."
  (let* ((buffer (window-buffer (selected-window)))
         (dir (with-current-buffer buffer
                (or (and buffer-file-name
                         (file-name-directory buffer-file-name))
                    default-directory))))
    (rc/gptel-current-session-root dir)))

(defun rc/gptel-session-list ()
  "Open the unified AI session panel."
  (interactive)
  (let ((root (rc/gptel-session-panel-caller-root))
        (buffer (rc/gptel-session-panel-open-buffer)))
    (with-current-buffer buffer
      (setq rc/gptel-session-panel-root-directory root)
      (rc/gptel-session-panel-revert))
    (pop-to-buffer buffer)))

(provide 'ai-sessions-rc)
;;; ai-sessions-rc.el ends here
