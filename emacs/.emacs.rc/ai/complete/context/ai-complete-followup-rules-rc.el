;;; ai-complete-followup-rules-rc.el --- Inline completion followup rules -*- lexical-binding: t; -*-

;;; Code:

(require 'ai-complete-c-family-rules-rc)
(require 'ai-complete-python-rules-rc)
(require 'ai-complete-java-rules-rc)
(require 'ai-complete-web-rules-rc)
(require 'ai-complete-elisp-rules-rc)

(defvar rc/gptel-complete-followup-mode-rules
  (append rc/gptel-complete-c-family-followup-rules
          rc/gptel-complete-python-followup-rules
          rc/gptel-complete-java-followup-rules
          rc/gptel-complete-web-followup-rules
          rc/gptel-complete-elisp-followup-rules)
  "Mode-aware followup split strategies.")

(provide 'ai-complete-followup-rules-rc)
;;; ai-complete-followup-rules-rc.el ends here
