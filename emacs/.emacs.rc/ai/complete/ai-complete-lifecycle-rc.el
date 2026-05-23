;;; ai-complete-lifecycle-rc.el --- Inline completion lifecycle wiring -*- lexical-binding: t; -*-

;;; Code:

(defun rc/gptel-install-complete-lifecycle-hooks ()
  "Install lifecycle hooks for inline completion state tracking."
  (rc/gptel-ensure-autocomplete)
  (add-hook 'gptel-autocomplete-lifecycle-hook
            #'rc/gptel-complete-lifecycle-hook))

(provide 'ai-complete-lifecycle-rc)
;;; ai-complete-lifecycle-rc.el ends here
