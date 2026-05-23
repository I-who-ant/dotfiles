;;; ai-complete-context-rc.el --- Inline completion mode/context rules -*- lexical-binding: t; -*-

;;; Code:

(require 'subr-x)
(require 'ai-complete-context-rules-rc)
(require 'ai-complete-policy-rules-rc)

(defun rc/gptel-complete-policy-rule (&optional mode)
  "Return inline completion policy plist for MODE or current `major-mode'."
  (alist-get (or mode major-mode) rc/gptel-complete-policy-rules))

(defun rc/gptel-complete-mode-rule (&optional mode)
  "Return inline completion rule plist for MODE or current `major-mode'.
Prefer policy rules and fall back to legacy context rules for compatibility."
  (or (rc/gptel-complete-policy-rule mode)
      (alist-get (or mode major-mode) rc/gptel-complete-mode-rules)))

(defun rc/gptel-complete-mode-extra (&optional mode)
  "Return mode-specific inline completion instructions for MODE."
  (or (plist-get (rc/gptel-complete-mode-rule mode) :extra)
      rc/gptel-complete-default-extra))

(defun rc/gptel-complete-mode-handler (&optional property mode)
  "Return mode-specific handler from PROPERTY for MODE or current `major-mode'."
  (let ((value (plist-get (rc/gptel-complete-mode-rule mode) property)))
    (cond
     ((functionp value) value)
     ((and (symbolp value) (fboundp value)) value)
     (t nil))))

(defun rc/gptel-compose-complete-extra (&optional user-extra)
  "Merge mode-specific completion rules with USER-EXTRA."
  ;; TODO(phase-3): add cross-file import/context slices instead of same-buffer-only prompt shaping.
  (string-join
   (delq nil
         (list (rc/gptel-complete-mode-extra)
               (and user-extra
                    (not (string-empty-p user-extra))
                    (concat "User preference:\n" user-extra))))
   "\n\n"))

(defun rc/gptel-describe-current-complete-prompt ()
  "Show current inline completion prompt diagnostics."
  (interactive)
  (rc/gptel-ensure-autocomplete)
  (let* ((diag (or (and (fboundp 'gptel-autocomplete-last-prompt-diagnostics)
                        (gptel-autocomplete-last-prompt-diagnostics))
                   (plist-get (gptel--request-context) :diagnostics)))
         (slices (plist-get diag :slices)))
    (with-help-window "*AI Complete Prompt*"
      (princ (format "file: %s\n" (or (plist-get diag :filename) (buffer-name))))
      (princ (format "prefix-length: %s\n" (or (plist-get diag :prefix-length) 0)))
      (princ (format "suffix-length: %s\n" (or (plist-get diag :suffix-length) 0)))
      (princ (format "context-length: %s\n" (or (plist-get diag :context-length) 0)))
      (princ (format "budget: %s\n\n" (or (plist-get diag :budget) "none")))
      (princ "Slices:\n")
      (dolist (slice slices)
        (princ
         (format "- %-18s included=%-3s raw=%-4s final=%-4s required=%s\n"
                 (or (plist-get slice :kind) 'unknown)
                 (if (plist-get slice :included) "yes" "no")
                 (or (plist-get slice :raw-length) 0)
                 (or (plist-get slice :final-length) 0)
                 (if (plist-get slice :required) "yes" "no"))))
      (when (plist-get diag :cropped)
        (princ "\nCropped:\n")
        (dolist (entry (plist-get diag :cropped))
          (princ
           (format "- %-18s removed=%s dropped=%s\n"
                   (plist-get entry :kind)
                   (or (plist-get entry :removed) 0)
                   (if (plist-get entry :dropped) "yes" "no"))))))))

(provide 'ai-complete-context-rc)
;;; ai-complete-context-rc.el ends here
