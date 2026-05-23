;;; ai-complete-context-rules-rc.el --- Inline completion context rules -*- lexical-binding: t; -*-

;;; Code:

(require 'ai-complete-c-family-rules-rc)
(require 'ai-complete-python-rules-rc)
(require 'ai-complete-java-rules-rc)
(require 'ai-complete-web-rules-rc)
(require 'ai-complete-elisp-rules-rc)

(defvar rc/gptel-complete-mode-rules
  (append rc/gptel-complete-c-family-context-rules
          rc/gptel-complete-python-context-rules
          rc/gptel-complete-java-context-rules
          rc/gptel-complete-web-context-rules
          rc/gptel-complete-elisp-context-rules)
  "Per-major-mode inline completion rules.")

(defvar rc/gptel-complete-default-extra
  "Continue the current code naturally. Keep the completion minimal and consistent with the surrounding file."
  "Fallback extra instructions for inline completion.")

(provide 'ai-complete-context-rules-rc)
;;; ai-complete-context-rules-rc.el ends here
