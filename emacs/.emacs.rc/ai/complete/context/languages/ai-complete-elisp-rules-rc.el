;;; ai-complete-elisp-rules-rc.el --- Emacs Lisp complete rules -*- lexical-binding: t; -*-

;;; Code:

(require 'ai-complete-language-utils-rc)

(declare-function rc/gptel-complete--next-edit-chunk "ai-complete-followup-rc" (text))

(defun rc/gptel-complete-elisp-split-followup (completion)
  "Split Emacs Lisp COMPLETION into display text and follow-up chunks."
  (when (and (stringp completion)
             (string-match-p "\n" completion))
    (let* ((lines (split-string completion "\n"))
           (display (mapconcat #'identity (seq-take lines 2) "\n"))
           (tail (seq-drop lines 2)))
      (list display
            (and tail
                 (mapcar #'rc/gptel-complete--next-edit-chunk
                         (list (string-join tail "\n"))))))))

(defconst rc/gptel-complete-elisp-policy-rules
  (rc/gptel-complete-build-policy-rules
   '(emacs-lisp-mode)
   '(:trigger-chars (?\( ?- ?: ?= 32)
     :auto-line-end t
     :line-end-regexp "\\(?:([^)]*\\|[=:]\\|\\_<setq\\_>\\|\\_<let\\*?\\_>\\)$"
     :allow-in-comment nil
     :allow-in-string nil
     :followup-style sexp-tail
     :followup-splitter rc/gptel-complete-elisp-split-followup
     :prefer-inline-edit nil
     :ghost-hint-style compact
     :extra "Prefer concise Emacs Lisp continuations using existing local style; avoid adding abstractions unless clearly needed."))
  "Policy rules for Emacs Lisp inline completion mode.")

(defconst rc/gptel-complete-elisp-context-rules
  (rc/gptel-complete-build-context-rules
   '(emacs-lisp-mode)
   '(:trigger-chars (?\( ?- ?: ?= 32)
     :auto-line-end t
     :line-end-regexp "\\(?:([^)]*\\|[=:]\\|\\_<setq\\_>\\|\\_<let\\*?\\_>\\)$"
     :extra "Prefer concise Emacs Lisp continuations using existing local style; avoid adding abstractions unless clearly needed."))
  "Context rules for Emacs Lisp inline completion mode.")

(defconst rc/gptel-complete-elisp-followup-rules
  (rc/gptel-complete-build-followup-rules '(emacs-lisp-mode) 'sexp-tail)
  "Followup split rules for Emacs Lisp inline completion mode.")

(provide 'ai-complete-elisp-rules-rc)
;;; ai-complete-elisp-rules-rc.el ends here
