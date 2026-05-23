;;; ai-complete-web-rules-rc.el --- JS/TS complete rules -*- lexical-binding: t; -*-

;;; Code:

(require 'ai-complete-language-utils-rc)

(defconst rc/gptel-complete-web-policy-rules
  (append
   (rc/gptel-complete-build-policy-rules
    '(js-mode js-ts-mode)
    '(:trigger-chars (?. ?\( ?, ?= ?:)
      :auto-line-end t
      :line-end-regexp "\\(?:\\.\\|=>\\|[({,=:]\\|\\_<return\\_>\\)$"
      :allow-in-comment nil
      :allow-in-string nil
      :followup-style blank-or-terminator
      :prefer-inline-edit nil
      :ghost-hint-style compact
      :extra "Prefer concise JavaScript or TypeScript continuations and match the surrounding semicolon and quote style."))
   (rc/gptel-complete-build-policy-rules
    '(typescript-mode typescript-ts-mode tsx-ts-mode)
    '(:trigger-chars (?. ?\( ?, ?= ?:)
      :auto-line-end t
      :line-end-regexp "\\(?:\\.\\|=>\\|[({,=:]\\|\\_<return\\_>\\)$"
      :allow-in-comment nil
      :allow-in-string nil
      :followup-style blank-or-terminator
      :prefer-inline-edit nil
      :ghost-hint-style compact
      :extra "Prefer concise TypeScript continuations and preserve local type and naming style.")))
  "Policy rules for JS/TS inline completion modes.")

(defconst rc/gptel-complete-web-context-rules
  (append
   (rc/gptel-complete-build-context-rules
    '(js-mode js-ts-mode)
    '(:trigger-chars (?. ?\( ?, ?= ?:)
      :auto-line-end t
      :line-end-regexp "\\(?:\\.\\|=>\\|[({,=:]\\|\\_<return\\_>\\)$"
      :extra "Prefer concise JavaScript or TypeScript continuations and match the surrounding semicolon and quote style."))
   (rc/gptel-complete-build-context-rules
    '(typescript-mode typescript-ts-mode tsx-ts-mode)
    '(:trigger-chars (?. ?\( ?, ?= ?:)
      :auto-line-end t
      :line-end-regexp "\\(?:\\.\\|=>\\|[({,=:]\\|\\_<return\\_>\\)$"
      :extra "Prefer concise TypeScript continuations and preserve local type and naming style.")))
  "Context rules for JS/TS inline completion modes.")

(defconst rc/gptel-complete-web-followup-rules
  (append
   (rc/gptel-complete-build-followup-rules '(js-mode js-ts-mode) 'blank-or-terminator)
   (rc/gptel-complete-build-followup-rules '(typescript-mode typescript-ts-mode tsx-ts-mode) 'blank-or-terminator))
  "Followup split rules for JS/TS inline completion modes.")

(provide 'ai-complete-web-rules-rc)
;;; ai-complete-web-rules-rc.el ends here
