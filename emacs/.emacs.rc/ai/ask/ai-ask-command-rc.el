;;; ai-ask-command-rc.el --- Ask session commands -*- lexical-binding: t; -*-

;;; Code:

(defvar rc/gptel--ask-read-action nil
  "Internal action selected while reading an ask question.")

(defvar rc/gptel--ask-read-text ""
  "Internal minibuffer contents preserved while reading an ask question.")

(defvar rc/gptel--ask-read-status nil
  "Transient status text shown while reading an ask question.")

(defvar rc/gptel--ask-pending-operation nil
  "Pending ask operation selected from the minibuffer.")

(defvar rc/gptel-ask-minibuffer-menu-history nil
  "History for ask minibuffer operation menu.")

(defun rc/gptel-materialize-ask-session-buffer (state)
  "Materialize ask session STATE into a live buffer and return it."
  (let ((buffer (get-buffer-create (rc/gptel-ask-live-buffer-name state))))
    (with-current-buffer buffer
      (rc/gptel-prepare-answer-buffer
       buffer (plist-get state :source) #'rc/gptel-ask-session-heading)
      (setq rc/gptel-ask-session-id (plist-get state :id)
            rc/gptel-ask-session-root (plist-get state :root)
            rc/gptel-ask-session-file (plist-get state :file)
            rc/gptel-ask-session-source (plist-get state :source)
            rc/gptel-ask-session-turns (plist-get state :turns)
            rc/gptel-ask-session-history (plist-get state :history)
            rc/gptel-ask-session-question-count (plist-get state :question-count)
            rc/gptel-ask-session-source-count (plist-get state :source-count)
            rc/gptel-ask-session-save-file (plist-get state :save-file)
            rc/gptel-ask-session-title (plist-get state :title)
            rc/gptel-ask-session-state 'ready
            rc/gptel-ask-session-last-error nil)
      (when (fboundp 'rc/gptel-action-record-event)
        (rc/gptel-action-record-event
         'ask
         'session-materialized
         (list :session-id rc/gptel-ask-session-id
               :state 'ready)))
      (rename-buffer (rc/gptel-ask-live-buffer-name state) t)
      (rc/gptel-render-ask-session-buffer buffer
                                          rc/gptel-ask-session-source
                                          rc/gptel-ask-session-turns)
      (goto-char (point-min))
      (set-buffer-modified-p nil))
    buffer))

(defun rc/gptel-activate-ask-session (entry)
  "Activate ask session ENTRY and return its live buffer."
  (let* ((state (rc/gptel-load-ask-session-state entry))
         (buffer (rc/gptel-materialize-ask-session-buffer state)))
    (setq rc/gptel-current-ask-buffer buffer)
    (when (fboundp 'rc/gptel-action-record-event)
      (with-current-buffer buffer
        (rc/gptel-action-record-event
         'ask
         'session-activated
         (list :session-id rc/gptel-ask-session-id
               :state rc/gptel-ask-session-state
               :request-id rc/gptel-ask-session-last-request-id))))
    (when (fboundp 'rc/gptel-refresh-open-session-panels)
      (rc/gptel-refresh-open-session-panels
       (buffer-local-value 'rc/gptel-ask-session-root buffer)))
    buffer))

(defun rc/gptel-ask-effective-source (buffer &optional turns)
  "Return effective source for BUFFER using TURNS when available."
  (let* ((turns (or turns
                    (buffer-local-value 'rc/gptel-ask-session-turns buffer)))
         (turn-source (and turns
                           (plist-get (car (last turns)) :source))))
    (or turn-source
        (buffer-local-value 'rc/gptel-ask-session-source buffer))))

(defun rc/gptel-ask-apply-turns (buffer turns &optional save-label)
  "Apply TURNS to BUFFER, then persist and refresh local state."
  (with-current-buffer buffer
    (setq rc/gptel-ask-session-turns turns
          rc/gptel-ask-session-history (rc/gptel-ask-turns-to-history turns)
          rc/gptel-ask-session-question-count (length turns)
          rc/gptel-ask-session-source (or (rc/gptel-ask-effective-source buffer turns)
                                          rc/gptel-ask-session-source))
    (rc/gptel-render-ask-session-buffer
     buffer
     rc/gptel-ask-session-source
     rc/gptel-ask-session-turns)
    (when (fboundp 'rc/gptel-action-record-event)
      (rc/gptel-action-record-event
       'ask
       'turns-applied
       (list :state 'ready
             :turn-count (length rc/gptel-ask-session-turns))))
    (rc/gptel-save-ask-session buffer (or save-label "ask"))
    (when (fboundp 'rc/gptel-refresh-open-session-panels)
      (rc/gptel-refresh-open-session-panels rc/gptel-ask-session-root))
    (set-buffer-modified-p nil)))

(defun rc/gptel-ask-read-turn-index (buffer prompt &optional allow-zero)
  "Read one turn index for BUFFER using PROMPT."
  (with-current-buffer buffer
    (let* ((count (length rc/gptel-ask-session-turns))
           (min-value (if allow-zero 0 1))
           (input (read-number
                   (format "%s (%d-%d): " prompt min-value count)
                   count)))
      (unless (and (>= input min-value) (<= input count))
        (user-error "编号超出范围"))
      input)))

(defun rc/gptel-ask-truncate-session (buffer keep-count)
  "Keep only first KEEP-COUNT turns in BUFFER."
  (with-current-buffer buffer
    (let ((new-turns (seq-take rc/gptel-ask-session-turns keep-count)))
      (rc/gptel-ask-apply-turns buffer new-turns
                                (format "rollback-q%d" keep-count))
      (when (fboundp 'rc/gptel-action-record-event)
        (rc/gptel-action-record-event
         'ask
         'rollback
         (list :state 'ready
               :turn-count (length rc/gptel-ask-session-turns)
               :keep-count keep-count)))
      (message "已回滚到 Q%d" keep-count))))

(defun rc/gptel-ask-branch-session (buffer keep-count)
  "Create a new ask session branched from first KEEP-COUNT turns in BUFFER."
  (with-current-buffer buffer
    (let* ((new-turns (seq-take rc/gptel-ask-session-turns keep-count))
           (source (or (rc/gptel-ask-effective-source buffer new-turns)
                       rc/gptel-ask-session-source))
           (branch-buffer (rc/gptel-ensure-ask-session source t)))
      (with-current-buffer branch-buffer
      (setq rc/gptel-ask-session-title
            (format "%s-branch-q%d"
                    (or rc/gptel-ask-session-title
                        (buffer-name buffer))
                    keep-count))
        (rc/gptel-ask-apply-turns branch-buffer new-turns
                                  (format "branch-q%d" keep-count)))
      (when (fboundp 'rc/gptel-action-record-event)
        (with-current-buffer branch-buffer
          (rc/gptel-action-record-event
           'ask
           'branch-created
           (list :state 'ready
                 :turn-count (length rc/gptel-ask-session-turns)))))
      branch-buffer)))

(defun rc/gptel-read-ask-operation ()
  "Read one ask minibuffer operation."
  (let* ((choices '(("切换会话" . switch-session)
                    ("回滚到指定 Q" . rollback)
                    ("从指定 Q 分叉新会话" . branch)))
         (choice (completing-read "Ask 操作: "
                                  choices nil t nil
                                  'rc/gptel-ask-minibuffer-menu-history)))
    (cdr (assoc choice choices))))

(defun rc/gptel-minibuffer-ask-operations ()
  "Queue ask operations and exit current `Question:' input."
  (interactive)
  (setq rc/gptel--ask-read-action 'ops
        rc/gptel--ask-read-text (minibuffer-contents-no-properties))
  (exit-minibuffer))

(defun rc/gptel-ensure-ask-session (source &optional force-new)
  "Return a live ask session buffer for SOURCE."
  (if (and (not force-new)
           (rc/gptel-ask-buffer-live-p))
      rc/gptel-current-ask-buffer
    (let* ((root (plist-get source :root))
           (id (cl-incf rc/gptel-ask-session-counter))
           (state (list :id id
                        :root root
                        :file (plist-get source :file)
                       :save-file nil
                       :title (rc/gptel-ask-buffer-name root id)
                       :source source
                       :turns nil
                       :history nil
                       :question-count 0
                       :source-count 1))
           (buffer (rc/gptel-materialize-ask-session-buffer state)))
      (when (and (buffer-live-p (plist-get source :buffer))
                 (buffer-local-value 'mark-active (plist-get source :buffer)))
        (with-current-buffer (plist-get source :buffer)
          (deactivate-mark)))
      (setq rc/gptel-current-ask-buffer buffer)
      buffer)))

(defun rc/gptel-replace-ask-session-source (buffer source)
  "Replace current ask session source in BUFFER with SOURCE."
  (with-current-buffer buffer
    (setq rc/gptel-ask-session-source source
          rc/gptel-ask-session-file (plist-get source :file)
          rc/gptel-ask-session-root (plist-get source :root))
    (cl-incf rc/gptel-ask-session-source-count)
    (when (fboundp 'rc/gptel-action-record-event)
      (rc/gptel-action-record-event
       'ask
       'source-replaced
       (list :state rc/gptel-ask-session-state
             :source-count rc/gptel-ask-session-source-count)))
    (rc/gptel-render-ask-session-buffer
     buffer
     rc/gptel-ask-session-source
     rc/gptel-ask-session-turns)
    (when (fboundp 'rc/gptel-refresh-open-session-panels)
      (rc/gptel-refresh-open-session-panels rc/gptel-ask-session-root))
    (set-buffer-modified-p nil)))

(defun rc/gptel-ask-prompt-text (source question)
  "Build the user prompt using SOURCE and QUESTION."
  (unless (and (listp source)
               (stringp (plist-get source :text))
               (not (string-empty-p (plist-get source :text))))
    (user-error "当前 ask session 没有有效 source，请重新选区后新建 session"))
  (format "Selected text from `%s`:\n\n%s\n\nQuestion:\n%s"
          (or (plist-get source :file)
              (buffer-name (plist-get source :buffer)))
          (plist-get source :text)
          question))

(defun rc/gptel-insert-question-heading (buffer question)
  "Insert question heading for QUESTION into BUFFER and return answer marker."
  (with-current-buffer buffer
    (let ((inhibit-read-only t))
      (cl-incf rc/gptel-ask-session-question-count)
      (goto-char (point-max))
      (insert (format "\n## Q%d\n\n%s\n\n## A%d\n\n"
                      rc/gptel-ask-session-question-count
                      question
                      rc/gptel-ask-session-question-count))
      (copy-marker (point-max)))))

(defun rc/gptel-send-ask-question (buffer question)
  "Send QUESTION using ask session BUFFER."
  (unless (rc/gptel-ask-session-valid-p buffer)
    (user-error "当前 ask session 状态无效，请重新选区后再用 C-c a q 创建新 session"))
  (let* ((source (buffer-local-value 'rc/gptel-ask-session-source buffer))
         (history (copy-sequence
                   (or (buffer-local-value 'rc/gptel-ask-session-history buffer)
                       nil)))
         (user-prompt (rc/gptel-ask-prompt-text source question))
         (answer-start (rc/gptel-insert-question-heading buffer question))
         (request-prompt (append history (list user-prompt)))
         (response-text ""))
    (with-current-buffer buffer
      (rc/gptel-setup-action-locals 'ask)
      (setq rc/gptel-ask-session-last-request-id nil
            rc/gptel-ask-session-state 'requesting
            rc/gptel-ask-session-last-error nil))
    (rc/gptel-show-answer-buffer buffer)
    (let ((request
           (rc/gptel-action-send
            :action-kind 'ask
            :buffer buffer
            :prompt request-prompt
            :position answer-start
            :stream t
            :system (rc/gptel-question-system-message)
            :detail (list :question question
                          :session-id (buffer-local-value 'rc/gptel-ask-session-id buffer))
            :on-stream
            (lambda (response _info request)
              (with-current-buffer buffer
                (let ((inhibit-read-only t)
                      (window-states (rc/gptel-answer-windows-at-bottom-p buffer)))
                  (setq response-text (concat response-text response))
                  (when (fboundp 'rc/gptel-action-record-event)
                    (rc/gptel-action-record-event
                     'ask
                     'answer-streamed
                     (list :request-id (plist-get request :request-id)
                           :state 'requesting
                           :chunk-length (length response))))
                  (save-excursion
                    (goto-char (point-max))
                    (insert response))
                  (rc/gptel-answer-refresh-windows window-states))))
            :on-success
            (lambda (_response _info request)
              (with-current-buffer buffer
                (let ((window-states (rc/gptel-answer-windows-at-bottom-p buffer)))
                  (setq rc/gptel-ask-session-turns
                        (append rc/gptel-ask-session-turns
                                (list (list :question question
                                            :answer response-text
                                            :source source))))
                  (setq rc/gptel-ask-session-history
                        (rc/gptel-ask-turns-to-history rc/gptel-ask-session-turns))
                  (setq rc/gptel-ask-session-state 'ready
                        rc/gptel-ask-session-last-error nil)
                  (when (fboundp 'rc/gptel-action-record-event)
                    (rc/gptel-action-record-event
                     'ask
                     'answer-completed
                     (list :request-id (plist-get request :request-id)
                           :state 'ready
                           :turn-count (length rc/gptel-ask-session-turns))))
                  (rc/gptel-save-ask-session buffer question)
                  (rc/gptel-answer-refresh-windows window-states))))
            :on-failure
            (lambda (_response info request)
              (with-current-buffer buffer
                (let ((inhibit-read-only t)
                      (window-states (rc/gptel-answer-windows-at-bottom-p buffer)))
                  (setq rc/gptel-ask-session-state 'failed
                        rc/gptel-ask-session-last-error (plist-get info :status))
                  (when (fboundp 'rc/gptel-action-record-event)
                    (rc/gptel-action-record-event
                     'ask
                     'request-failed
                     (list :request-id (plist-get request :request-id)
                           :state 'failed
                           :end-reason 'failed-request
                           :last-error (plist-get info :status))))
                  (save-excursion
                    (goto-char (point-max))
                    (insert (format "\n\nRequest failed: %s"
                                    (plist-get info :status))))
                  (rc/gptel-answer-refresh-windows window-states))))
            :on-abort
            (lambda (_response _info request)
              (with-current-buffer buffer
                (setq rc/gptel-ask-session-state 'aborted
                      rc/gptel-ask-session-last-error nil)
                (when (fboundp 'rc/gptel-action-record-event)
                  (rc/gptel-action-record-event
                   'ask
                   'request-aborted
                   (list :request-id (plist-get request :request-id)
                         :state 'aborted
                         :end-reason 'aborted-request
                         :last-error "aborted"))))))))
      (with-current-buffer buffer
        (setq rc/gptel-ask-session-last-request-id (plist-get request :request-id))
        (when (fboundp 'rc/gptel-action-record-event)
          (rc/gptel-action-record-event
           'ask
           'question-sent
           (list :request-id (plist-get request :request-id)
                 :state 'requesting
                 :question question))))
      (message "Ask session querying..."))))

(defun rc/gptel-read-ask-session-buffer ()
  "Read and return one live ask session buffer."
  (let* ((buffers (rc/gptel-ask-session-buffers))
         (choices (mapcar (lambda (buf)
                            (cons (rc/gptel-ask-session-label buf) buf))
                          buffers)))
    (unless choices
      (user-error "当前没有可切换的 ask session"))
    (cdr (assoc (completing-read "Switch ask session: " choices nil t) choices))))

(defun rc/gptel-switch-ask-session ()
  "Switch current ask workflow to another live ask session."
  (interactive)
  (let ((buffer (rc/gptel-read-ask-session-buffer)))
    (setq rc/gptel-current-ask-buffer buffer)
    (rc/gptel-show-answer-buffer buffer)
    (message "已切换到 %s" (buffer-name buffer))))

(defun rc/gptel-minibuffer-action-set (action)
  "Set ask minibuffer ACTION and exit."
  (interactive)
  (setq rc/gptel--ask-read-action action
        rc/gptel--ask-read-text (minibuffer-contents-no-properties))
  (exit-minibuffer))

(defun rc/gptel-minibuffer-switch-ask-session ()
  "Switch ask session while staying inside `Question:' input."
  (interactive)
  (setq rc/gptel--ask-read-action 'switch-session
        rc/gptel--ask-read-text (minibuffer-contents-no-properties))
  (call-interactively #'rc/gptel-session-list)
  (let ((buffer rc/gptel-current-ask-buffer))
    (when (rc/gptel-ask-session-valid-p buffer)
      (setq rc/gptel--ask-read-status
            (format "已切换到 %s" (buffer-name buffer)))))
  (exit-minibuffer))

(defun rc/gptel-read-ask-question (source-available-p current-source-fn
                                                      on-replace on-new
                                                      on-use-buffer on-use-directory)
  "Read a question for ask sessions."
  (let ((text "")
        result)
    (while (not result)
      (setq rc/gptel--ask-read-action 'ask
            rc/gptel--ask-read-text text)
      (let ((minibuffer-local-map
             (make-composed-keymap
              (define-keymap
                "C-q" (lambda ()
                        (interactive)
                        (unless source-available-p
                          (user-error "当前没有可用上下文，不能覆盖 source"))
                        (rc/gptel-minibuffer-action-set 'replace-source))
                "C-r" (lambda ()
                        (interactive)
                        (unless source-available-p
                          (user-error "当前没有可用上下文，不能新建 ask session"))
                        (rc/gptel-minibuffer-action-set 'new-session))
                "C-b" (lambda ()
                        (interactive)
                        (rc/gptel-minibuffer-action-set 'use-buffer-source))
                "C-d" (lambda ()
                        (interactive)
                        (rc/gptel-minibuffer-action-set 'use-directory-source))
                "C-l" #'rc/gptel-minibuffer-ask-operations)
              minibuffer-local-map))
            (input nil))
        (setq input
              (minibuffer-with-setup-hook
                  (lambda ()
                    (let* ((hint-core "[C-q 覆盖默认上下文, C-r 新开 session, C-b 文件上下文, C-d 目录上下文, C-l ask 操作]")
                           (source-summary (funcall current-source-fn))
                           (hint (if rc/gptel--ask-read-status
                                     (format "  %s  [source=%s | %s]"
                                             hint-core source-summary rc/gptel--ask-read-status)
                                   (format "  %s  [source=%s]" hint-core source-summary)))
                           (ov (make-overlay (point-max) (point-max) nil t t)))
                      (overlay-put ov 'after-string
                                   (propertize hint 'face 'shadow))
                      (add-hook 'post-command-hook
                                (lambda ()
                                  (when (overlayp ov)
                                    (overlay-put
                                     ov 'after-string
                                     (and (string-empty-p
                                           (minibuffer-contents-no-properties))
                                          (propertize hint 'face 'shadow)))))
                                nil t)
                      (add-hook 'minibuffer-exit-hook
                                (lambda ()
                                  (when (overlayp ov)
                                    (delete-overlay ov)))
                                nil t)))
                (read-from-minibuffer "Question: " text nil nil nil text)))
        (pcase rc/gptel--ask-read-action
          ('ask
           (setq rc/gptel--ask-read-status nil)
           (setq result (list :action 'ask :question input)))
          ('replace-source
           (funcall on-replace)
           (setq rc/gptel--ask-read-status "已覆盖后续问题的 source")
           (setq text rc/gptel--ask-read-text))
          ('new-session
           (funcall on-new)
           (setq rc/gptel--ask-read-status
                 (format "已切换到 %s" (buffer-name rc/gptel-current-ask-buffer)))
           (setq text rc/gptel--ask-read-text))
          ('use-buffer-source
           (funcall on-use-buffer)
           (setq rc/gptel--ask-read-status "已切到当前文件上下文")
           (setq text rc/gptel--ask-read-text))
          ('use-directory-source
           (funcall on-use-directory)
           (setq rc/gptel--ask-read-status "已切到当前目录上下文")
           (setq text rc/gptel--ask-read-text))
          ('switch-session
           (setq text rc/gptel--ask-read-text))
          ('ops
           (setq rc/gptel--ask-pending-operation (rc/gptel-read-ask-operation))
           (pcase rc/gptel--ask-pending-operation
             ('switch-session
              (call-interactively #'rc/gptel-session-list)
              (let ((buffer rc/gptel-current-ask-buffer))
                (when (rc/gptel-ask-session-valid-p buffer)
                  (setq rc/gptel--ask-read-status
                        (format "已切换到 %s" (buffer-name buffer))))))
             ('rollback
              (unless (rc/gptel-ask-buffer-live-p)
                (user-error "当前没有可回滚的 ask session"))
              (let ((keep-count (rc/gptel-ask-read-turn-index
                                 rc/gptel-current-ask-buffer
                                 "回滚保留到第几个 Q")))
                (rc/gptel-ask-truncate-session rc/gptel-current-ask-buffer keep-count)
                (setq rc/gptel--ask-read-status
                      (format "已回滚到 Q%d" keep-count))))
             ('branch
              (unless (rc/gptel-ask-buffer-live-p)
                (user-error "当前没有可分叉的 ask session"))
              (let* ((keep-count (rc/gptel-ask-read-turn-index
                                  rc/gptel-current-ask-buffer
                                  "从第几个 Q 分叉"))
                     (branch-buffer (rc/gptel-ask-branch-session
                                     rc/gptel-current-ask-buffer keep-count)))
                (setq rc/gptel-current-ask-buffer branch-buffer
                      rc/gptel--ask-read-status
                      (format "已分叉为 %s" (buffer-name branch-buffer))))))
           (setq rc/gptel--ask-pending-operation nil)
           (setq text rc/gptel--ask-read-text)))))
    result))

(defun rc/gptel-ask-question ()
  "Ask a question using a persistent ask session in a bottom window."
  (interactive)
  (let* ((origin-buffer (current-buffer))
         (region-source (when (use-region-p)
                          (rc/gptel-ask-source-from-region
                           origin-buffer (region-beginning) (region-end))))
         (source-candidates (and (not region-source)
                                 (rc/gptel-ask-source-candidates origin-buffer)))
         (buffer-source (cdr (assq 'buffer source-candidates)))
         (directory-source (cdr (assq 'directory source-candidates)))
         (default-source (or region-source
                             (rc/gptel-ask-fallback-source origin-buffer)))
         (session-buffer
          (cond
           ((and (rc/gptel-ask-buffer-live-p)
                 (not region-source))
            rc/gptel-current-ask-buffer)
           (default-source
            (rc/gptel-ensure-ask-session default-source (not (rc/gptel-ask-buffer-live-p))))
           (t
            (user-error "当前没有可用 ask session，也没有可用于提问的文件或目录上下文"))))
         (read-result
          (rc/gptel-read-ask-question
           (and default-source t)
           (lambda ()
             (let ((source (buffer-local-value 'rc/gptel-ask-session-source session-buffer)))
               (rc/gptel-ask-source-summary (or source default-source))))
           (lambda ()
             (when default-source
               (rc/gptel-replace-ask-session-source session-buffer default-source)))
           (lambda ()
             (unless default-source
               (user-error "当前没有可用上下文，不能新建 ask session"))
             (setq session-buffer
                   (rc/gptel-ensure-ask-session default-source t)))
           (lambda ()
             (unless buffer-source
               (user-error "当前没有可用文件上下文"))
             (rc/gptel-replace-ask-session-source session-buffer buffer-source))
           (lambda ()
             (unless directory-source
               (user-error "当前没有可用目录上下文"))
             (rc/gptel-replace-ask-session-source session-buffer directory-source)))))
    (let ((question (string-trim (plist-get read-result :question))))
      (when (string-empty-p question)
        (user-error "问题不能为空"))
      (when (buffer-live-p origin-buffer)
        (with-current-buffer origin-buffer
          (when (use-region-p)
            (deactivate-mark))))
      (setq rc/gptel-current-ask-buffer session-buffer)
      (rc/gptel-send-ask-question session-buffer question))))

(provide 'ai-ask-command-rc)
;;; ai-ask-command-rc.el ends here
