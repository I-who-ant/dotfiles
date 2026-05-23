;;; ai-core-rc.el --- Core AI helpers  -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defvar rc/gptel-core-loaded nil
  "Non-nil when core gptel packages have been loaded in this session.")

(defvar rc/gptel-rewrite-loaded nil
  "Non-nil when rewrite support has been loaded in this session.")

(defvar rc/gptel-autocomplete-loaded nil
  "Non-nil when autocomplete support has been loaded in this session.")

(defvar rc/gptel-command-backend-override nil
  "Optional backend override for custom AI commands.")

(defvar rc/gptel-command-model-override nil
  "Optional model override for custom AI commands.")

(defun rc/gptel-current-session-root (&optional directory)
  "Return directory root used for local AI sessions."
  (file-name-as-directory
   (expand-file-name (or directory default-directory))))

(defun rc/gptel-session-store-dir (&optional root)
  "Return `some-of-the-question' directory for ROOT."
  (expand-file-name "some-of-the-question"
                    (rc/gptel-current-session-root root)))

(defun rc/gptel-session-md-dir (&optional root)
  "Return session markdown directory for ROOT."
  (expand-file-name "sessions"
                    (rc/gptel-session-store-dir root)))

(defun rc/gptel-session-index-file (&optional root)
  "Return session index file path for ROOT."
  (expand-file-name "index.el"
                    (rc/gptel-session-store-dir root)))

(defun rc/gptel-session-meta-file (save-file)
  "Return metadata file path for SAVE-FILE."
  (concat (file-name-sans-extension save-file) ".meta.el"))

(defun rc/gptel-path-last-component (path)
  "Return last directory or file component from PATH."
  (file-name-nondirectory (directory-file-name path)))

(defun rc/gptel-read-elisp-file (file)
  "Read one Lisp object from FILE, returning nil when absent."
  (when (file-exists-p file)
    (condition-case err
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (read (current-buffer)))
      (error
       (message "AI: 跳过损坏 elisp 文件 %s (%s)"
                file
                (error-message-string err))
       nil))))

(defun rc/gptel-write-elisp-file (file object)
  "Persist OBJECT to FILE as one pretty-printed Lisp form."
  (make-directory (file-name-directory file) t)
  (with-temp-file file
    (let ((print-length nil)
          (print-level nil))
      (pp object (current-buffer)))))

(defun rc/gptel--alist-inc (alist key &optional delta)
  "Return ALIST with KEY incremented by DELTA."
  (let ((copy (copy-tree alist))
        (step (or delta 1)))
    (setf (alist-get key copy nil nil #'equal)
          (+ (or (alist-get key copy nil nil #'equal) 0) step))
    copy))

(defun rc/gptel--plist-inc (plist key &optional delta)
  "Return PLIST with KEY incremented by DELTA."
  (plist-put plist key (+ (or (plist-get plist key) 0) (or delta 1))))

(defun rc/gptel-ensure-core ()
  "Load core gptel packages on demand."
  (unless rc/gptel-core-loaded
    (unless (require 'gptel nil t)
      (user-error "未能加载 gptel"))
    (require 'gptel-request)
    (setq rc/gptel-core-loaded t)
    (message "✓ gptel 已加载")))

(defun rc/gptel-ensure-rewrite ()
  "Load gptel rewrite support on demand."
  (rc/gptel-ensure-core)
  (unless rc/gptel-rewrite-loaded
    (unless (require 'gptel-rewrite nil t)
      (user-error "未能加载 gptel-rewrite"))
    (setq rc/gptel-rewrite-loaded t)
    (message "✓ gptel-rewrite 已加载")))

(defun rc/gptel-ensure-autocomplete ()
  "Load gptel autocomplete support on demand."
  (rc/gptel-ensure-core)
  (unless rc/gptel-autocomplete-loaded
    (unless (require 'gptel-autocomplete nil t)
      (user-error "未能加载 gptel-autocomplete"))
    (setq rc/gptel-autocomplete-loaded t)
    (message "✓ gptel-autocomplete 已加载")))

(defun rc/gptel-send-command ()
  "Lazy entrypoint for `gptel-send'."
  (interactive)
  (rc/gptel-ensure-core)
  (call-interactively #'gptel-send))

(defun rc/gptel-menu-command ()
  "Lazy entrypoint for `gptel-menu'."
  (interactive)
  (rc/gptel-ensure-core)
  (unless (require 'gptel-transient nil t)
    (user-error "未能加载 gptel-transient"))
  (call-interactively #'gptel-menu))

(defun rc/gptel-rewrite-command ()
  "Lazy entrypoint for `gptel-rewrite'."
  (interactive)
  (rc/gptel-ensure-rewrite)
  (call-interactively #'gptel-rewrite))

(defun rc/gptel-buffer-active-request-p (&optional buffer)
  "Return non-nil when BUFFER has an active gptel request."
  (rc/gptel-ensure-core)
  (let ((target (or buffer (current-buffer))))
    (cl-some
     (lambda (entry)
       (eq (thread-first (cadr entry)
                         (gptel-fsm-info)
                         (plist-get :buffer))
           target))
     gptel--request-alist)))

(defun rc/gptel-abort-current-buffer ()
  "Abort the active gptel request in current buffer, else quit normally."
  (interactive)
  (if (rc/gptel-buffer-active-request-p (current-buffer))
      (gptel-abort (current-buffer))
    (keyboard-quit)))

(defun rc/gptel-command-backend (action)
  "Return the backend for ACTION-aware custom AI commands."
  (rc/gptel-ensure-core)
  (or rc/gptel-command-backend-override
      (when (fboundp 'gptel-action-backend)
        (gptel-action-backend action))
      gptel-backend))

(defun rc/gptel-command-model (action)
  "Return the model for ACTION-aware custom AI commands."
  (rc/gptel-ensure-core)
  ;; TODO(phase-3): route complete/ask/rewrite to different models by latency/quality budget.
  (or rc/gptel-command-model-override
      (when (fboundp 'gptel-action-model)
        (gptel-action-model action))
      gptel-model
      'deepseek-chat))

(defun rc/gptel-command-system-base (action)
  "Return base system message string for ACTION."
  (rc/gptel-ensure-core)
  (or (when (fboundp 'gptel-action-system-string)
        (gptel-action-system-string action))
      (when (stringp gptel--system-message)
        gptel--system-message)
      (when (and gptel--system-message
                 (fboundp 'gptel--parse-directive))
        (car-safe
         (ignore-errors
           (gptel--parse-directive gptel--system-message 'raw))))))

(defun rc/gptel-compose-system-message (action task &optional extra)
  "Merge ACTION base system message with TASK instructions and EXTRA notes."
  (string-join
   (delq nil
         (list (rc/gptel-command-system-base action)
               task
               (and extra
                    (not (string-empty-p extra))
                    (concat "Additional instructions:\n" extra))))
   "\n\n"))

(defun rc/gptel-setup-action-locals (action)
  "Set stable buffer-local defaults for ACTION-aware custom AI commands."
  (setq-local gptel-backend (rc/gptel-command-backend action))
  (setq-local gptel-model (rc/gptel-command-model action))
  (setq-local gptel-stream t)
  (when (boundp 'gptel-autocomplete-use-context)
    (setq-local gptel-autocomplete-use-context nil))
  (when (boundp 'gptel-autocomplete-system-message-base)
    (setq-local gptel-autocomplete-system-message-base
                (rc/gptel-command-system-base action))))

(defun rc/gptel-read-extra-prompt ()
  "Read an optional extra prompt string from minibuffer."
  (let ((prompt (string-trim (read-string "Prompt: "))))
    (unless (string-empty-p prompt)
      prompt)))

(defun rc/ignore-media-key ()
  "Silently swallow media-key noise and preserve AI ghost text."
  (interactive)
  (when (fboundp 'gptel-autocomplete-preserve-next-clear)
    (gptel-autocomplete-preserve-next-clear)))

(provide 'ai-core-rc)
;;; ai-core-rc.el ends here
