;;; ai-complete-policy-rules-rc.el --- Inline completion policy rules -*- lexical-binding: t; -*-

;;; Code:

(require 'ai-complete-c-family-rules-rc)
(require 'ai-complete-python-rules-rc)
(require 'ai-complete-java-rules-rc)
(require 'ai-complete-web-rules-rc)
(require 'ai-complete-elisp-rules-rc)

(defvar rc/gptel-complete-policy-rules
  (append rc/gptel-complete-c-family-policy-rules
          rc/gptel-complete-python-policy-rules
          rc/gptel-complete-java-policy-rules
          rc/gptel-complete-web-policy-rules
          rc/gptel-complete-elisp-policy-rules)
  "Per-major-mode inline completion policies.")

(provide 'ai-complete-policy-rules-rc)
;;; ai-complete-policy-rules-rc.el ends here
