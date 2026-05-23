;;; ai-complete-python-rules-rc.el --- Python complete rules -*- lexical-binding: t; -*-

;;; Code:

(require 'ai-complete-language-utils-rc)

(declare-function rc/gptel-complete--next-edit-chunk "ai-complete-followup-rc" (text))

(defun rc/gptel-complete-python--line-indent (line)
  "Return indentation width of LINE using leading whitespace length."
  (if (string-match "\\`[ \t]*" (or line ""))
      (length (match-string 0 line))
    0))

(defun rc/gptel-complete-python--clause-boundary-p (line base-indent)
  "Return non-nil when LINE starts a sibling clause at BASE-INDENT."
  (and (string-match-p "\\S-" line)
       (<= (rc/gptel-complete-python--line-indent line) base-indent)
       (string-match-p
        "\\`\\s-*\\(?:elif\\|else\\|except\\|finally\\)\\_>.*:\\s-*\\'"
        line)))

(defun rc/gptel-complete-python--dedented-boundary-p (line base-indent)
  "Return non-nil when LINE starts a new top-level chunk at BASE-INDENT."
  (and (string-match-p "\\S-" line)
       (<= (rc/gptel-complete-python--line-indent line) base-indent)
       (not (string-match-p
             "\\`\\s-*\\(?:elif\\|else\\|except\\|finally\\)\\_>.*:\\s-*\\'"
             line))))

(defun rc/gptel-complete-python-split-followup (completion)
  "Split Python COMPLETION into display text and follow-up chunks."
  (when (and (stringp completion)
             (string-match-p "\n" completion))
    (let* ((lines (split-string completion "\n"))
           (display (car lines))
           (rest (cdr lines))
           (base-indent (rc/gptel-complete-python--line-indent display))
           (current nil)
           (chunks nil))
      (when display
        (dolist (line rest)
          (when (and current
                     (or (rc/gptel-complete-python--clause-boundary-p line base-indent)
                         (rc/gptel-complete-python--dedented-boundary-p line base-indent)))
            (push (string-join (nreverse current) "\n") chunks)
            (setq current nil))
          (push line current))
        (when current
          (push (string-join (nreverse current) "\n") chunks))
        (list display
              (mapcar #'rc/gptel-complete--next-edit-chunk
                      (nreverse chunks)))))))

(defconst rc/gptel-complete-python-policy-rules
  (rc/gptel-complete-build-policy-rules
   '(python-mode python-ts-mode)
   '(:trigger-chars (?. ?\( ?, ?= ?:)
     :auto-line-end t
     :line-end-regexp "\\(?:\\_<return\\_>\\|\\_<elif\\_>\\|\\_<else\\_>\\|\\_<except\\_>\\|\\_<finally\\_>\\|\\_<if\\_>\\|[(:,=]\\)$"
     :allow-in-comment nil
     :allow-in-string nil
     :followup-style indent-block
     :followup-splitter rc/gptel-complete-python-split-followup
     :prefer-inline-edit nil
     :ghost-hint-style compact
     :extra "Prefer short Python continuations that fit the surrounding indentation and avoid unnecessary comments."))
  "Policy rules for Python inline completion modes.")

(defconst rc/gptel-complete-python-context-rules
  (rc/gptel-complete-build-context-rules
   '(python-mode python-ts-mode)
   '(:trigger-chars (?. ?\( ?, ?= ?:)
     :auto-line-end t
     :line-end-regexp "\\(?:\\_<return\\_>\\|\\_<elif\\_>\\|\\_<else\\_>\\|\\_<except\\_>\\|\\_<finally\\_>\\|\\_<if\\_>\\|[(:,=]\\)$"
     :extra "Prefer short Python continuations that fit the surrounding indentation and avoid unnecessary comments."))
  "Context rules for Python inline completion modes.")

(defconst rc/gptel-complete-python-followup-rules
  (rc/gptel-complete-build-followup-rules '(python-mode python-ts-mode) 'indent-block)
  "Followup split rules for Python inline completion modes.")

(provide 'ai-complete-python-rules-rc)
;;; ai-complete-python-rules-rc.el ends here
