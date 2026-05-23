;;; ai-complete-java-rules-rc.el --- Java complete rules -*- lexical-binding: t; -*-

;;; Code:

(require 'ai-complete-language-utils-rc)

(defun rc/gptel-complete-java--method-chain-tail-p ()
  "Return non-nil when current Java line ends with a method-chain call."
  (let* ((line (buffer-substring-no-properties
                (line-beginning-position)
                (point)))
         (trimmed (string-trim-right line)))
    (and (string-suffix-p ")" trimmed)
         (string-match-p "\\.[[:word:]_]+([^;\n]*)\\s-*\\'" trimmed))))

(defun rc/gptel-complete-java-line-end-trigger-p ()
  "Return non-nil when current Java line shape warrants a trigger."
  (save-excursion
    (skip-chars-backward " \t")
    (or (looking-back "\\(?:\\.\\|->\\|@[[:word:]_]+\\|[=(,]\\|\\_<return\\_>\\|\\_<if\\_>\\|\\_<new\\_>\\|\\_<throws\\_>\\)$"
                      (line-beginning-position))
        (looking-back ";\\s-*\\'" (line-beginning-position))
        (looking-back "\\_<\\(?:if\\|for\\|while\\|catch\\|switch\\)\\_>.*)\\s-*\\'"
                      (line-beginning-position))
        (rc/gptel-complete-java--method-chain-tail-p))))

(defconst rc/gptel-complete-java-policy-rules
  (rc/gptel-complete-build-policy-rules
   '(java-mode java-ts-mode)
   '(:trigger-chars (?. ?\( ?, ?= ?: ?@)
     :line-end-predicate rc/gptel-complete-java-line-end-trigger-p
     :auto-line-end t
     :line-end-regexp "\\(?:\\.\\|->\\|@[[:word:]_]+\\|[=(,]\\|\\_<return\\_>\\|\\_<if\\_>\\|\\_<new\\_>\\|\\_<throws\\_>\\)$"
     :allow-in-comment nil
     :allow-in-string nil
     :followup-style blank-or-terminator
     :prefer-inline-edit nil
     :ghost-hint-style compact
     :extra "Prefer concise Java continuations. Reuse the current class, method, and naming style instead of inventing new abstractions."))
  "Policy rules for Java inline completion modes.")

(defconst rc/gptel-complete-java-context-rules
  (rc/gptel-complete-build-context-rules
   '(java-mode java-ts-mode)
   '(:trigger-chars (?. ?\( ?, ?= ?: ?@)
     :auto-line-end t
     :line-end-regexp "\\(?:\\.\\|->\\|@[[:word:]_]+\\|[=(,]\\|\\_<return\\_>\\|\\_<if\\_>\\|\\_<new\\_>\\|\\_<throws\\_>\\)$"
     :extra "Prefer concise Java continuations. Reuse the current class, method, and naming style instead of inventing new abstractions."))
  "Context rules for Java inline completion modes.")

(defconst rc/gptel-complete-java-followup-rules
  (rc/gptel-complete-build-followup-rules '(java-mode java-ts-mode) 'blank-or-terminator)
  "Followup split rules for Java inline completion modes.")

(provide 'ai-complete-java-rules-rc)
;;; ai-complete-java-rules-rc.el ends here
