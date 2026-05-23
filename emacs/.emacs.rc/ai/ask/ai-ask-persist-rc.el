;;; ai-ask-persist-rc.el --- Ask session persistence helpers -*- lexical-binding: t; -*-

;;; Code:

(defun rc/gptel-ask-persistable-source (source)
  "Return a serialized copy of ask SOURCE without live Emacs objects."
  (when (listp source)
    (list :file (plist-get source :file)
          :root (plist-get source :root)
          :mode (plist-get source :mode)
          :kind (plist-get source :kind)
          :label (plist-get source :label)
          :text (plist-get source :text))))

(defun rc/gptel-ask-persistable-turns (turns)
  "Return a serialized copy of ask TURNS."
  (mapcar
   (lambda (turn)
     (list :question (plist-get turn :question)
           :answer (plist-get turn :answer)
           :source (rc/gptel-ask-persistable-source
                    (plist-get turn :source))))
   (rc/gptel-normalize-ask-turns turns)))

(defun rc/gptel-ask-index-entry (buffer)
  "Return one serialized ask session entry for BUFFER."
  (with-current-buffer buffer
    (let ((question-count (length (or rc/gptel-ask-session-turns '()))))
      (setq rc/gptel-ask-session-question-count question-count)
    (list :id rc/gptel-ask-session-id
          :root rc/gptel-ask-session-root
          :file rc/gptel-ask-session-file
          :save-file rc/gptel-ask-session-save-file
          :meta-file (and rc/gptel-ask-session-save-file
                          (rc/gptel-session-meta-file rc/gptel-ask-session-save-file))
          :question-count question-count
          :updated-at (format-time-string "%Y-%m-%d %H:%M:%S")
          :title (or rc/gptel-ask-session-title
                     (buffer-name buffer))))))

(defun rc/gptel-write-ask-session-meta (buffer)
  "Write structured metadata for ask BUFFER."
  (with-current-buffer buffer
    (let* ((turns (rc/gptel-ask-persistable-turns rc/gptel-ask-session-turns))
           (question-count (length turns))
           (meta
           (list :id rc/gptel-ask-session-id
                 :root rc/gptel-ask-session-root
                 :file rc/gptel-ask-session-file
                 :save-file rc/gptel-ask-session-save-file
                 :question-count question-count
                 :source (rc/gptel-ask-persistable-source
                          rc/gptel-ask-session-source)
                 :turns turns
                 :history (rc/gptel-ask-turns-to-history turns)
                 :title (or rc/gptel-ask-session-title
                            (buffer-name buffer))
                 :updated-at (format-time-string "%Y-%m-%d %H:%M:%S"))))
      (setq rc/gptel-ask-session-question-count question-count)
      (when rc/gptel-ask-session-save-file
        (rc/gptel-write-elisp-file
         (rc/gptel-session-meta-file rc/gptel-ask-session-save-file)
         meta)))))

(defun rc/gptel-ask-meta-from-markdown (save-file)
  "Best-effort reconstruct ask metadata from SAVE-FILE."
  (with-temp-buffer
    (insert-file-contents save-file)
    (let (root file question-count)
      (goto-char (point-min))
      (when (re-search-forward "^- Root: `\\(.*\\)`$" nil t)
        (setq root (match-string 1)))
      (goto-char (point-min))
      (when (re-search-forward "^- File: `\\(.*\\)`$" nil t)
        (setq file (match-string 1)))
      (goto-char (point-min))
      (setq question-count
            (how-many "^## Q[0-9]+" (point-min) (point-max)))
      (list :id 0
            :root root
            :file (unless (string-empty-p (or file "")) file)
            :save-file save-file
            :question-count question-count
            :source nil
            :turns nil
            :history nil
            :title (file-name-base save-file)
            :updated-at (format-time-string
                         "%Y-%m-%d %H:%M:%S"
                         (file-attribute-modification-time
                          (file-attributes save-file)))))))

(defun rc/gptel-ensure-ask-meta-file (save-file)
  "Ensure structured meta file exists for SAVE-FILE and return its metadata."
  (let* ((meta-file (rc/gptel-session-meta-file save-file))
         (meta (or (rc/gptel-read-elisp-file meta-file)
                   (rc/gptel-ask-meta-from-markdown save-file)))
         (turns (rc/gptel-normalize-ask-turns (plist-get meta :turns)))
         (question-count (if turns
                             (length turns)
                           (or (plist-get meta :question-count) 0)))
         (normalized (plist-put (copy-sequence meta) :question-count question-count)))
    (when turns
      (setq normalized (plist-put normalized :turns turns))
      (setq normalized
            (plist-put normalized :history
                       (rc/gptel-ask-turns-to-history turns))))
    (unless (file-exists-p meta-file)
      (rc/gptel-write-elisp-file meta-file normalized))
    (when (not (equal normalized meta))
      (rc/gptel-write-elisp-file meta-file normalized))
    normalized))

(defun rc/gptel-ask-source-from-markdown (save-file file root)
  "Recover latest source block from SAVE-FILE using FILE and ROOT."
  (when (and save-file (file-exists-p save-file))
    (with-temp-buffer
      (insert-file-contents save-file)
      (goto-char (point-min))
      (let (last-text last-lang)
        (while (re-search-forward "^## \\(Source\\|Source Update\\)[ \t]*$" nil t)
          (forward-line 1)
          (when (looking-at-p "^[ \t]*$")
            (forward-line 1))
          (when (looking-at "^```\\([^`\n]*\\)$")
            (setq last-lang (string-trim (match-string 1)))
            (forward-line 1)
            (let ((code-start (point)))
              (when (re-search-forward "^```[ \t]*$" nil t)
                (setq last-text
                      (string-trim-right
                       (buffer-substring-no-properties
                        code-start
                        (match-beginning 0))))))))
        (when (and last-text (not (string-empty-p last-text)))
          (list :buffer nil
                :file file
                :root root
                :mode (and (not (string-empty-p (or last-lang "")))
                           (intern (concat last-lang "-mode")))
                :text last-text))))))

(defun rc/gptel-ask-parse-source-block-at-point (file root)
  "Parse a source block at point into a source plist."
  (when (looking-at "^```\\([^`\n]*\\)$")
    (let ((lang (string-trim (match-string 1))))
      (forward-line 1)
      (let ((code-start (point)))
        (when (re-search-forward "^```[ \t]*$" nil t)
          (list :buffer nil
                :file file
                :root root
                :mode (and (not (string-empty-p (or lang "")))
                           (intern (concat lang "-mode")))
                :text (string-trim-right
                       (buffer-substring-no-properties
                        code-start
                        (match-beginning 0)))))))))

(defun rc/gptel-ask-turns-from-markdown (save-file file root default-source)
  "Recover structured ask turns from SAVE-FILE."
  (when (and save-file (file-exists-p save-file))
    (with-temp-buffer
      (insert-file-contents save-file)
      (goto-char (point-min))
      (let ((current-source default-source)
            turns)
        (while (re-search-forward "^## \\(Source\\|Source Update\\|Q[0-9]+\\)[ \t]*$" nil t)
          (let ((heading (match-string 1))
                (heading-pos (match-beginning 0)))
            (goto-char heading-pos)
            (cond
             ((member heading '("Source" "Source Update"))
              (forward-line 1)
              (when (looking-at-p "^[ \t]*$")
                (forward-line 1))
              (let ((parsed (rc/gptel-ask-parse-source-block-at-point file root)))
                (when parsed
                  (setq current-source parsed))))
             ((string-match "^Q\\([0-9]+\\)$" heading)
              (let* ((qnum (match-string 1 heading))
                     (question-start (progn (forward-line 1) (point)))
                     (answer-heading
                      (and (re-search-forward
                            (format "^## A%s[ \t]*$" (regexp-quote qnum))
                            nil t)
                           (match-beginning 0)))
                     (answer-start
                      (and answer-heading
                           (progn (forward-line 1) (point))))
                     (next-heading
                      (and answer-start
                           (save-excursion
                             (goto-char answer-start)
                             (when (re-search-forward "^## \\(Source\\|Source Update\\|Q[0-9]+\\)[ \t]*$" nil t)
                               (match-beginning 0)))))
                     (question (and answer-heading
                                    (string-trim
                                     (buffer-substring-no-properties
                                      question-start answer-heading))))
                     (answer (and answer-start
                                  (string-trim
                                   (buffer-substring-no-properties
                                    answer-start
                                    (or next-heading (point-max)))))))
                (when (and question answer)
                  (push (list :question question
                              :answer answer
                              :source current-source)
                        turns)))
              (goto-char heading-pos)))))
        (nreverse turns)))))

(defun rc/gptel-load-ask-session-state (entry)
  "Load and normalize ask session state from ENTRY."
  (let* ((save-file (plist-get entry :save-file))
         (meta-file (and save-file (rc/gptel-session-meta-file save-file)))
         (meta (or (and meta-file
                        (rc/gptel-read-elisp-file meta-file))
                   entry))
         (root (or (plist-get meta :root) default-directory))
         (file (plist-get meta :file))
         (fallback-source (or (rc/gptel-ask-source-from-markdown save-file file root)
                              (list :buffer nil :file file :root root :mode nil :text "")))
         (stored-source (plist-get meta :source))
         (source (if (and (listp stored-source)
                          (stringp (plist-get stored-source :text))
                          (not (string-empty-p (plist-get stored-source :text))))
                     stored-source
                   fallback-source))
         (turns (or (rc/gptel-normalize-ask-turns (plist-get meta :turns))
                    (let ((history (rc/gptel-normalize-ask-history
                                    (plist-get meta :history))))
                      (and history
                           (rc/gptel-ask-history-to-turns history source)))
                    (rc/gptel-ask-turns-from-markdown save-file file root source)
                    nil))
         (question-count (length turns))
         (history (rc/gptel-ask-turns-to-history turns))
         (current-source (or source
                             (and turns (plist-get (car (last turns)) :source))
                             fallback-source))
         (id (max 1 (or (plist-get meta :id) 1)))
         (title (or (plist-get meta :title)
                    (and save-file (file-name-base save-file))
                    (rc/gptel-ask-buffer-name root id))))
    (setq rc/gptel-ask-session-counter
          (max rc/gptel-ask-session-counter id))
    (list :id id
          :root root
          :file file
          :save-file save-file
          :title title
          :source current-source
          :turns turns
          :history history
          :question-count question-count
          :source-count 1)))

(defun rc/gptel-update-ask-session-index (buffer)
  "Update directory-local ask session index for BUFFER."
  (with-current-buffer buffer
    (let* ((index-file (rc/gptel-session-index-file rc/gptel-ask-session-root))
           (existing (or (rc/gptel-read-elisp-file index-file) '()))
           (entry (rc/gptel-ask-index-entry buffer))
           (save-file (plist-get entry :save-file))
           (filtered
            (seq-remove
             (lambda (item)
               (equal (plist-get item :save-file) save-file))
             existing)))
      (rc/gptel-write-elisp-file index-file (cons entry filtered)))))

(defun rc/gptel-ask-session-file-slug (text)
  "Return a filesystem-friendly slug derived from TEXT."
  (let ((slug
         (string-trim
          (replace-regexp-in-string "[/\\:*?\"<>|\n\r\t]+" "-" text))))
    (setq slug (replace-regexp-in-string "[[:space:]]+" "-" slug))
    (if (string-empty-p slug)
        "ask"
      (truncate-string-to-width slug 32 nil nil nil))))

(defun rc/gptel-ask-session-save-path (buffer question)
  "Return markdown path used to persist BUFFER, using QUESTION for the slug."
  (with-current-buffer buffer
    (let* ((root rc/gptel-ask-session-root)
           (base (rc/gptel-session-md-dir root))
           (filename (format "%s-ask-%d-%s.md"
                             (format-time-string "%Y-%m-%d")
                             rc/gptel-ask-session-id
                             (rc/gptel-ask-session-file-slug question))))
      (make-directory base t)
      (expand-file-name filename base))))

(defun rc/gptel-save-ask-session (buffer &optional question)
  "Persist ask session BUFFER to disk."
  (with-current-buffer buffer
    (unless rc/gptel-ask-session-save-file
      (setq rc/gptel-ask-session-save-file
            (rc/gptel-ask-session-save-path buffer (or question "ask"))))
    (rc/gptel-render-ask-session-buffer
     buffer
     rc/gptel-ask-session-source
     rc/gptel-ask-session-turns)
    (let ((text (buffer-substring-no-properties (point-min) (point-max))))
      (write-region text nil rc/gptel-ask-session-save-file nil 'silent))
    (rc/gptel-write-ask-session-meta buffer)
    (rc/gptel-update-ask-session-index buffer)
    (when (fboundp 'rc/gptel-refresh-open-session-panels)
      (rc/gptel-refresh-open-session-panels rc/gptel-ask-session-root))))

(provide 'ai-ask-persist-rc)
;;; ai-ask-persist-rc.el ends here
