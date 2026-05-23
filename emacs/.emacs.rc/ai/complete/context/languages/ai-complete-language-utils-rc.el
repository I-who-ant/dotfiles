;;; ai-complete-language-utils-rc.el --- Shared helpers for language rule files -*- lexical-binding: t; -*-

;;; Code:

(defconst rc/gptel-complete-default-source-rules
  '((post-jump-retrigger :enabled t :delay 0.02)
    (lsp-suggestions :enabled t :delay 0.03)
    (signature-help :enabled t :delay 0.04)
    (flymake-diagnostics :enabled t :delay 0.08))
  "Default source rules shared by most inline completion modes.")

(defun rc/gptel-complete-language--plist-ensure (plist property value)
  "Return PLIST with PROPERTY set to VALUE when PROPERTY is absent."
  (if (plist-member plist property)
      plist
    (append plist (list property value))))

(defun rc/gptel-complete-build-policy-rules (modes plist)
  "Build policy rules for MODES from shared PLIST."
  (let ((base (rc/gptel-complete-language--plist-ensure
               plist :source-rules rc/gptel-complete-default-source-rules)))
    (mapcar (lambda (mode)
              (append (list mode) base))
            modes)))

(defun rc/gptel-complete-build-context-rules (modes plist)
  "Build context rules for MODES from shared PLIST."
  (mapcar (lambda (mode)
            (append (list mode) plist))
          modes))

(defun rc/gptel-complete-build-followup-rules (modes split-style)
  "Build followup rules for MODES using SPLIT-STYLE."
  (mapcar (lambda (mode)
            (list mode :split split-style))
          modes))

(provide 'ai-complete-language-utils-rc)
;;; ai-complete-language-utils-rc.el ends here
