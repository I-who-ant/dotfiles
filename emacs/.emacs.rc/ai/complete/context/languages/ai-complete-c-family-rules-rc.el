;;; ai-complete-c-family-rules-rc.el --- C-family complete rules -*- lexical-binding: t; -*-

;;; Code:

(require 'ai-complete-language-utils-rc)

(defun rc/gptel-complete-c-family--call-tail-p ()
  "Return non-nil when current line ends with a likely member/function call."
  (let* ((line (buffer-substring-no-properties
                (line-beginning-position)
                (point)))
         (trimmed (string-trim-right line)))
    (and (string-suffix-p ")" trimmed)
         (not (string-match-p
               "\\_<\\(?:if\\|for\\|while\\|switch\\)\\_>.*)\\s-*\\'"
               trimmed))
         (or (string-match-p "\\(?:->\\|\\.\\|::\\)[[:word:]_]+([^;\n]*)\\s-*\\'" trimmed)
             (string-match-p "\\_<[[:word:]_]+\\s-*<[^>\n]+>\\s-*([^;\n]*)\\s-*\\'" trimmed)))))

(defun rc/gptel-complete-c-family-line-end-trigger-p ()
  "Return non-nil when current C-family line shape warrants a trigger."
  (save-excursion
    (skip-chars-backward " \t")
    (or (looking-back "\\(?:->\\|::\\|[=(,]\\|\\_<return\\_>\\|\\_<if\\_>\\)$"
                      (line-beginning-position))
        (looking-back ";\\s-*\\'" (line-beginning-position))
        (looking-back "\\_<\\(?:if\\|for\\|while\\|switch\\)\\_>.*)\\s-*\\'"
                      (line-beginning-position)))))

(defun rc/gptel-complete-cpp-line-end-trigger-p ()
  "Return non-nil when current C++ line shape warrants a trigger."
  (save-excursion
    (skip-chars-backward " \t")
    (or (rc/gptel-complete-c-family-line-end-trigger-p)
        (rc/gptel-complete-c-family--call-tail-p)
        (looking-back "\\_<auto\\_>" (line-beginning-position)))))

(defun rc/gptel-complete-c-family-direct-char-trigger-p (ch)
  "Return non-nil when C-family direct char CH should trigger completion."
  (pcase ch
    (?: (save-excursion
          (looking-back "::" (line-beginning-position))))
    (?> (save-excursion
          (looking-back "->" (line-beginning-position))))
    (_ (memq ch (rc/gptel-complete-trigger-chars)))))

(defconst rc/gptel-complete-c-family-policy-rules
  (append
   (rc/gptel-complete-build-policy-rules
    '(c-mode c-ts-mode)
    '(:trigger-chars (?. ?> ?: ?\( ?, ?=)
      :direct-char-predicate rc/gptel-complete-c-family-direct-char-trigger-p
      :line-end-predicate rc/gptel-complete-c-family-line-end-trigger-p
      :auto-line-end t
      :line-end-regexp "\\(?:->\\|::\\|[=(,]\\|\\_<return\\_>\\|\\_<if\\_>\\)$"
      :allow-in-comment nil
      :allow-in-string nil
      :allow-in-preprocessor nil
      :followup-style blank-or-terminator
      :prefer-inline-edit nil
      :ghost-hint-style compact
      :extra "Prefer concise C-style continuations. Preserve local vertical spacing instead of collapsing intentional blank lines between setup, loops, and logical blocks. Do not invent helper functions unless the local code strongly implies one."))
   (rc/gptel-complete-build-policy-rules
    '(c++-mode c++-ts-mode)
    '(:trigger-chars (?. ?> ?: ?\( ?, ?=)
      :direct-char-predicate rc/gptel-complete-c-family-direct-char-trigger-p
      :line-end-predicate rc/gptel-complete-cpp-line-end-trigger-p
      :auto-line-end t
      :line-end-regexp "\\(?:->\\|::\\|[=(,]\\|\\_<return\\_>\\|\\_<if\\_>\\|\\_<auto\\_>\\)$"
      :allow-in-comment nil
      :allow-in-string nil
      :allow-in-preprocessor nil
      :followup-style blank-or-terminator
      :prefer-inline-edit nil
      :ghost-hint-style compact
      :extra "Prefer concise modern C++ continuations, but stay consistent with the current file's style, existing naming, and local vertical spacing. Do not collapse intentional blank lines between setup, loops, and logical blocks.")))
  "Policy rules for C-family inline completion modes.")

(defconst rc/gptel-complete-c-family-context-rules
  (append
   (rc/gptel-complete-build-context-rules
    '(c-mode c-ts-mode)
    '(:trigger-chars (?. ?> ?: ?\( ?, ?=)
      :auto-line-end t
      :line-end-regexp "\\(?:->\\|::\\|[=(,]\\|\\_<return\\_>\\|\\_<if\\_>\\)$"
      :extra "Prefer concise C-style continuations. Preserve local vertical spacing instead of collapsing intentional blank lines between setup, loops, and logical blocks. Do not invent helper functions unless the local code strongly implies one."))
   (rc/gptel-complete-build-context-rules
    '(c++-mode c++-ts-mode)
    '(:trigger-chars (?. ?> ?: ?\( ?, ?=)
      :auto-line-end t
      :line-end-regexp "\\(?:->\\|::\\|[=(,]\\|\\_<return\\_>\\|\\_<if\\_>\\|\\_<auto\\_>\\)$"
      :extra "Prefer concise modern C++ continuations, but stay consistent with the current file's style, existing naming, and local vertical spacing. Do not collapse intentional blank lines between setup, loops, and logical blocks.")))
  "Context rules for C-family inline completion modes.")

(defconst rc/gptel-complete-c-family-followup-rules
  (append
   (rc/gptel-complete-build-followup-rules '(c-mode c-ts-mode) 'blank-or-terminator)
   (rc/gptel-complete-build-followup-rules '(c++-mode c++-ts-mode) 'blank-or-terminator))
  "Followup split rules for C-family inline completion modes.")

(provide 'ai-complete-c-family-rules-rc)
;;; ai-complete-c-family-rules-rc.el ends here
