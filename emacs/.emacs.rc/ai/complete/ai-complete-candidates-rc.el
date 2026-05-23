;;; ai-complete-candidates-rc.el --- Candidate navigation helpers -*- lexical-binding: t; -*-

;;; Code:

(defun rc/gptel-inline-next-candidate ()
  "Show next inline completion candidate when available."
  (interactive)
  (if (fboundp 'gptel-autocomplete-next-candidate)
      (call-interactively #'gptel-autocomplete-next-candidate)
    (message "当前补全插件不支持多候选")))

(defun rc/gptel-inline-previous-candidate ()
  "Show previous inline completion candidate when available."
  (interactive)
  (if (fboundp 'gptel-autocomplete-previous-candidate)
      (call-interactively #'gptel-autocomplete-previous-candidate)
    (message "当前补全插件不支持多候选")))

(provide 'ai-complete-candidates-rc)
;;; ai-complete-candidates-rc.el ends here
