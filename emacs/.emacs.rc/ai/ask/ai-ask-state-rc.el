;;; ai-ask-state-rc.el --- Ask session state helpers -*- lexical-binding: t; -*-

;;; Code:

(defvar rc/gptel-current-ask-buffer nil
  "Most recently used ask session buffer.")

(defvar rc/gptel-ask-session-counter 0
  "Counter used to build stable ask session buffer names.")

(defvar-local rc/gptel-ask-session-id nil
  "Numeric id of the current ask session.")
(defvar-local rc/gptel-ask-session-root nil
  "Root directory associated with the current ask session.")
(defvar-local rc/gptel-ask-session-file nil
  "Primary file associated with the current ask session.")
(defvar-local rc/gptel-ask-session-source nil
  "Current source plist for the ask session.")
(defvar-local rc/gptel-ask-session-history nil
  "Conversation history for the ask session as alternating strings.")
(defvar-local rc/gptel-ask-session-turns nil
  "Structured ask turns for the current session.")
(defvar-local rc/gptel-ask-session-question-count 0
  "Number of questions asked in the current ask session.")
(defvar-local rc/gptel-ask-session-source-count 0
  "Number of source updates in the current ask session.")
(defvar-local rc/gptel-ask-session-save-file nil
  "Markdown file used to persist this ask session.")
(defvar-local rc/gptel-ask-session-title nil
  "Human title of the current ask session.")
(defvar-local rc/gptel-ask-session-state 'idle
  "Current high-level ask session state.")
(defvar-local rc/gptel-ask-session-last-request-id nil
  "Last request id issued by this ask session.")
(defvar-local rc/gptel-ask-session-last-error nil
  "Last request error recorded for this ask session.")

(defvar rc/gptel-ask-buffer-source-max-chars 12000
  "Maximum characters captured when asking from the whole current buffer.")

(defvar rc/gptel-ask-directory-source-entry-limit 40
  "Maximum top-level directory entries captured for directory ask context.")

(defvar rc/gptel-ask-directory-source-snippet-max-chars 3000
  "Maximum characters captured from the current file inside directory ask context.")

(defun rc/gptel-ask-source-summary (source)
  "Return a concise human-readable summary for ask SOURCE."
  (let ((kind (plist-get source :kind)))
    (pcase kind
      ('region
       (format "region:%s" (rc/gptel-ask-source-label source)))
      ('buffer
       (format "buffer:%s" (rc/gptel-ask-source-label source)))
      ('directory
       (format "directory:%s" (rc/gptel-path-last-component
                               (or (plist-get source :root)
                                   (rc/gptel-ask-source-label source)))))
      (_
       (format "%s:%s"
               (or kind 'source)
               (rc/gptel-ask-source-label source))))))

(defun rc/gptel-ask-session-state-plist (&optional buffer)
  "Return normalized ask session state plist for BUFFER, else nil."
  (let ((target (or buffer (current-buffer))))
    (when (rc/gptel-ask-session-valid-p target)
      (with-current-buffer target
        (let* ((requesting (and (fboundp 'rc/gptel-buffer-active-request-p)
                               (ignore-errors
                                 (rc/gptel-buffer-active-request-p target))))
               (last-request (and (fboundp 'rc/gptel-action-last-request)
                                  (rc/gptel-action-last-request target)))
               (turn-count (length (or rc/gptel-ask-session-turns '()))))
          (list :session-id rc/gptel-ask-session-id
                :root rc/gptel-ask-session-root
                :file rc/gptel-ask-session-file
                :save-file rc/gptel-ask-session-save-file
                :title (or rc/gptel-ask-session-title (buffer-name))
                :request-id rc/gptel-ask-session-last-request-id
                :state (cond
                        (requesting 'requesting)
                        ((eq rc/gptel-ask-session-state 'aborted) 'aborted)
                        (rc/gptel-ask-session-last-error 'failed)
                        ((> turn-count 0) 'ready)
                        (t rc/gptel-ask-session-state))
                :end-reason (plist-get last-request :end-reason)
                :last-error rc/gptel-ask-session-last-error
                :source rc/gptel-ask-session-source
                :turn-count turn-count
                :question-count rc/gptel-ask-session-question-count
                :source-count rc/gptel-ask-session-source-count
                :history (or (and (fboundp 'rc/gptel-action-lifecycle-history)
                                  (copy-sequence
                                   (rc/gptel-action-lifecycle-history target)))
                             '())))))))

(defun rc/gptel-ask-action-snapshot (&optional buffer)
  "Return shared action snapshot for ask session BUFFER, else nil."
  (let ((state (rc/gptel-ask-session-state-plist buffer)))
    (when state
      (let* ((source (plist-get state :source))
             (request-state (plist-get state :state))
             (next-action-kind
              (pcase request-state
                ('requesting 'wait-response)
                ((or 'ready 'idle) 'ask-next)
                ('failed 'retry-request)
                (_ 'none))))
      (list :action-kind 'ask
            :title (format "ask:%s" (plist-get state :title))
            :buffer (or buffer (current-buffer))
            :request-id (plist-get state :request-id)
            :state (plist-get state :state)
            :end-reason (plist-get state :end-reason)
            :visible (get-buffer-window (or buffer (current-buffer)) 'visible)
            :last-error (plist-get state :last-error)
            :backend (with-current-buffer (or buffer (current-buffer))
                       (and (boundp 'gptel-backend) gptel-backend))
            :model (with-current-buffer (or buffer (current-buffer))
                     (and (boundp 'gptel-model) gptel-model))
            :profile nil
            :stats nil
            :history (plist-get state :history)
            :detail
            (list :session-id (plist-get state :session-id)
                  :request-source (or (plist-get source :kind) 'session)
                  :next-action-kind next-action-kind
                  :next-action-count 1
                  :root (plist-get state :root)
                  :file (plist-get state :file)
                  :save-file (plist-get state :save-file)
                  :turn-count (plist-get state :turn-count)
                  :question-count (plist-get state :question-count)
                  :source-count (plist-get state :source-count)))))))

(defun rc/gptel-normalize-ask-history (history)
  "Return HISTORY normalized to an alternating string list."
  (let ((items (seq-filter #'stringp history)))
    (if (zerop (% (length items) 2))
        items
      (butlast items))))

(defun rc/gptel-normalize-ask-turns (turns)
  "Return TURNS normalized to a list of valid ask turn plists."
  (seq-filter
   (lambda (turn)
     (and (listp turn)
          (stringp (plist-get turn :question))
          (not (string-empty-p
                (rc/gptel-ask-question-from-history-prompt
                 (plist-get turn :question))))
          (stringp (plist-get turn :answer))
          (listp (plist-get turn :source))
          (stringp (plist-get (plist-get turn :source) :text))))
   (mapcar
    (lambda (turn)
      (plist-put (copy-sequence turn)
                 :question
                 (rc/gptel-ask-question-from-history-prompt
                  (plist-get turn :question))))
    turns)))

(defun rc/gptel-ask-session-heading (source)
  "Return initial markdown heading for a new ask session using SOURCE."
  (format "# Ask Session\n\n- Root: `%s`\n- File: `%s`\n- Save: `(pending first answer)`\n\n"
          (or (plist-get source :root) "")
          (or (plist-get source :file)
              (buffer-name (plist-get source :buffer)))))

(defun rc/gptel-ask-buffer-name (root id)
  "Return a stable ask buffer name for ROOT and ID."
  (format "*ask:%s:%d*"
          (rc/gptel-path-last-component root)
          id))

(defun rc/gptel-ask-live-buffer-name (state)
  "Return the dedicated live buffer name for ask STATE."
  (rc/gptel-ask-buffer-name (plist-get state :root) (plist-get state :id)))

(defun rc/gptel-ask-session-root (buffer)
  "Return storage root for ask session from BUFFER."
  (with-current-buffer buffer
    (or (and buffer-file-name (file-name-directory buffer-file-name))
        default-directory)))

(defun rc/gptel-ask-source-from-region (buffer beg end)
  "Build a source plist from BUFFER region between BEG and END."
  (with-current-buffer buffer
    (let ((text (buffer-substring-no-properties beg end)))
      (unless (and (stringp text) (not (string-empty-p text)))
        (user-error "当前选区为空，不能创建 ask source"))
      (list :buffer buffer
            :file buffer-file-name
            :root (rc/gptel-ask-session-root buffer)
            :mode major-mode
            :kind 'region
            :label (or buffer-file-name (buffer-name buffer))
            :text text))))

(defun rc/gptel-ask-source-from-buffer (buffer)
  "Build a source plist from the whole BUFFER."
  (with-current-buffer buffer
    (let* ((raw (buffer-substring-no-properties (point-min) (point-max)))
           (text (string-trim raw))
           (label (or buffer-file-name (buffer-name buffer))))
      (unless (and (stringp text) (not (string-empty-p text)))
        (user-error "当前 buffer 为空，不能创建 ask source"))
      (when (> (length text) rc/gptel-ask-buffer-source-max-chars)
        (setq text (substring text 0 rc/gptel-ask-buffer-source-max-chars)))
      (list :buffer buffer
            :file buffer-file-name
            :root (rc/gptel-ask-session-root buffer)
            :mode major-mode
            :kind 'buffer
            :label label
            :text text))))

(defun rc/gptel-ask-source-from-directory (&optional buffer)
  "Build a source plist from BUFFER's current directory."
  (with-current-buffer (or buffer (current-buffer))
    (let* ((root (rc/gptel-ask-session-root (current-buffer)))
           (entries (seq-take
                     (seq-remove
                      (lambda (name)
                        (member name '("." "..")))
                      (directory-files root nil nil t))
                     rc/gptel-ask-directory-source-entry-limit))
           (current-file (or buffer-file-name ""))
           (current-snippet
            (and (> (buffer-size) 0)
                 (let ((snippet (string-trim
                                 (buffer-substring-no-properties (point-min) (point-max)))))
                   (when (> (length snippet) rc/gptel-ask-directory-source-snippet-max-chars)
                     (setq snippet
                           (substring snippet 0 rc/gptel-ask-directory-source-snippet-max-chars)))
                   snippet)))
           (text
            (string-join
             (delq nil
                   (list (format "Directory root: %s" root)
                         (and (not (string-empty-p current-file))
                              (format "Current file: %s" current-file))
                         "Top-level entries:"
                         (mapconcat (lambda (name) (format "- %s" name))
                                    entries
                                    "\n")
                         (and current-snippet
                              (not (string-empty-p current-snippet))
                              (format "\nCurrent file snippet:\n%s" current-snippet))))
             "\n")))
      (list :buffer (current-buffer)
            :file nil
            :root root
            :mode major-mode
            :kind 'directory
            :label root
            :text text))))

(defun rc/gptel-ask-source-label (source)
  "Return a readable label for SOURCE."
  (or (plist-get source :label)
      (plist-get source :file)
      (and (buffer-live-p (plist-get source :buffer))
           (buffer-name (plist-get source :buffer)))
      (plist-get source :root)
      "current-context"))

(defun rc/gptel-ask-fallback-source (buffer)
  "Return a non-region ask source derived from BUFFER."
  (with-current-buffer buffer
    (cond
     ((and (buffer-file-name buffer)
           (> (buffer-size) 0))
      (rc/gptel-ask-source-from-buffer buffer))
     ((> (buffer-size) 0)
      (rc/gptel-ask-source-from-buffer buffer))
     (t
     (rc/gptel-ask-source-from-directory buffer)))))

(defun rc/gptel-ask-source-candidates (buffer)
  "Return available non-empty ask source candidates for BUFFER."
  (with-current-buffer buffer
    (delq nil
          (list
           (when (> (buffer-size) 0)
             (cons 'buffer (rc/gptel-ask-source-from-buffer buffer)))
           (cons 'directory (rc/gptel-ask-source-from-directory buffer))))))

(defun rc/gptel-ask-source-language (source)
  "Return a markdown fence language string for SOURCE."
  (let* ((mode (plist-get source :mode))
         (name (and mode (symbol-name mode))))
    (if (and name (string-suffix-p "-mode" name))
        (substring name 0 (- (length name) 5))
      "")))

(defun rc/gptel-ask-session-valid-p (buffer)
  "Return non-nil when BUFFER has a valid ask session state."
  (let ((source (and (buffer-live-p buffer)
                     (buffer-local-value 'rc/gptel-ask-session-source buffer)))
        (save-file (and (buffer-live-p buffer)
                        (buffer-local-value 'rc/gptel-ask-session-save-file buffer))))
    (and (buffer-live-p buffer)
         (numberp (buffer-local-value 'rc/gptel-ask-session-id buffer))
         (or (and (listp source)
                  (stringp (plist-get source :text))
                  (not (string-empty-p (plist-get source :text))))
             (and save-file (file-exists-p save-file)))
         (numberp (buffer-local-value 'rc/gptel-ask-session-question-count buffer))
         (numberp (buffer-local-value 'rc/gptel-ask-session-source-count buffer)))))

(defun rc/gptel-ask-buffer-live-p ()
  "Return non-nil when `rc/gptel-current-ask-buffer' is live and valid."
  (and (buffer-live-p rc/gptel-current-ask-buffer)
       (rc/gptel-ask-session-valid-p rc/gptel-current-ask-buffer)))

(defun rc/gptel-ask-session-buffers ()
  "Return all live valid ask session buffers."
  (seq-filter #'rc/gptel-ask-session-valid-p (buffer-list)))

(defun rc/gptel-ask-session-label (buffer)
  "Return a readable label for ask session BUFFER."
  (with-current-buffer buffer
    (format "%s  [%s]"
            (or rc/gptel-ask-session-title (buffer-name buffer))
            (or rc/gptel-ask-session-file
                (rc/gptel-path-last-component rc/gptel-ask-session-root)))))

(defun rc/gptel-ask-question-from-history-prompt (prompt)
  "Extract the question text from stored ask PROMPT."
  (let ((text (string-trim (or prompt ""))))
    (if (string-match "Question:[ \t]*\n\\(\\(?:.\\|\n\\)*\\)\\'" text)
        (string-trim (match-string 1 text))
      text)))

(defun rc/gptel-ask-history-entry (source question)
  "Build one legacy history prompt from SOURCE and QUESTION."
  (format "Context from `%s`:\n\n%s\n\nQuestion:\n%s"
          (rc/gptel-ask-source-label source)
          (plist-get source :text)
          question))

(defun rc/gptel-ask-turns-to-history (turns)
  "Convert structured TURNS into legacy alternating history."
  (apply #'append
         (mapcar
          (lambda (turn)
            (list (rc/gptel-ask-history-entry
                   (plist-get turn :source)
                   (plist-get turn :question))
                  (plist-get turn :answer)))
          turns)))

(defun rc/gptel-ask-history-to-turns (history default-source)
  "Convert legacy alternating HISTORY into structured turns."
  (let ((pairs (rc/gptel-normalize-ask-history history))
        turns)
    (while pairs
      (let* ((prompt (pop pairs))
             (answer (pop pairs))
             (question (rc/gptel-ask-question-from-history-prompt prompt)))
        (push (list :question question
                    :answer (or answer "")
                    :source default-source)
              turns)))
    (nreverse turns)))

(defun rc/gptel-question-system-message ()
  "Return the default system prompt for question answering."
  (rc/gptel-ensure-core)
  (rc/gptel-compose-system-message
   'ask
   "Answer questions about the provided context, code, or directory snapshot. Do not rewrite the original text unless the user explicitly asks for it. Answer clearly and directly in Chinese unless the user explicitly asks otherwise."))

(provide 'ai-ask-state-rc)
;;; ai-ask-state-rc.el ends here
