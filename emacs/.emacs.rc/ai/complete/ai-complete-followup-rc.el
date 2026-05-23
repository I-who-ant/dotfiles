;;; ai-complete-followup-rc.el --- Mode-aware followup splitting -*- lexical-binding: t; -*-

;;; Code:

(require 'subr-x)
(require 'ai-complete-followup-rules-rc)
(require 'ai-complete-context-rc)

(defvar rc/gptel-complete-followup-delay 0.12
  "Seconds to wait before triggering a follow-up completion after accept.")

(defvar-local rc/gptel-complete-followup-timer nil
  "Pending follow-up timer for inline completion in the current buffer.")

(defun rc/gptel-cancel-complete-followup ()
  "Cancel any pending inline completion follow-up timer."
  (when (timerp rc/gptel-complete-followup-timer)
    (cancel-timer rc/gptel-complete-followup-timer)
    (setq rc/gptel-complete-followup-timer nil)))

(defun rc/gptel-complete-followup-rule (&optional mode)
  "Return followup split rule plist for MODE.
Prefer policy rules and fall back to legacy followup rules for compatibility."
  (let* ((policy (rc/gptel-complete-policy-rule mode))
         (style (plist-get policy :followup-style)))
    (or (and style (list :split style))
        (alist-get (or mode major-mode) rc/gptel-complete-followup-mode-rules))))

(defun rc/gptel-complete--next-edit-chunk (text)
  "Normalize followup TEXT into a next-edit chunk that preserves leading newline."
  (when (and (stringp text)
             (not (string-empty-p text)))
    (if (string-prefix-p "\n" text)
        text
      (concat "\n" text))))

(defun rc/gptel-complete-followup-splitter (&optional mode)
  "Return mode-specific followup splitter for MODE or current `major-mode'."
  (rc/gptel-complete-mode-handler :followup-splitter mode))

(defun rc/gptel-complete-split-followup (completion)
  "Return (DISPLAY FOLLOWUPS) for COMPLETION, or nil to use plugin fallback."
  (let ((splitter (rc/gptel-complete-followup-splitter)))
    (when splitter
      (funcall splitter completion))))

(defun rc/gptel-complete-followup-eligible-p (payload)
  "Return non-nil when accepted completion PAYLOAD should trigger a follow-up."
  (let ((accepted-text (or (plist-get payload :accepted-text) "")))
    (and (not (plist-get payload :partial))
         (stringp accepted-text)
         (not (string-empty-p (string-trim accepted-text)))
         (bound-and-true-p gptel-autocomplete-mode)
         (not (minibufferp))
         (eolp)
         (not (rc/gptel-inline-completion-visible-p))
         (rc/gptel-complete-policy-allows-point-context-p)
         ;; Avoid immediate retrigger after obviously complete block endings.
         (not (string-match-p "\n[[:space:]]*$" accepted-text))
         (not (string-match-p "[;})\\]\"']\\'" accepted-text)))))

(defun rc/gptel-run-complete-followup (buffer)
  "Trigger a follow-up completion in BUFFER when still appropriate."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq rc/gptel-complete-followup-timer nil)
      (when (and (bound-and-true-p gptel-autocomplete-mode)
                 (not (minibufferp))
                 (eolp)
                 (not (rc/gptel-inline-completion-visible-p))
                 (rc/gptel-complete-policy-allows-point-context-p))
        (rc/gptel-prepare-inline-complete-buffer)
        (rc/gptel-sync-complete-session-state)
        (rc/gptel-complete-session-update
         :followup-triggered-count
         (1+ (or (plist-get (rc/gptel-complete-session-state)
                            :followup-triggered-count)
                 0)))
        (gptel-complete 'followup)))))

(provide 'ai-complete-followup-rc)
;;; ai-complete-followup-rc.el ends here
