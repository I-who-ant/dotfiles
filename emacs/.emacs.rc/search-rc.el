;;; search-rc.el --- Search and navigation helpers  -*- lexical-binding: t; -*-

;;; Code:

(defun rc/isearch-forward-use-region ()
  "Start isearch and seed it with region text when region is active."
  (interactive)
  (if (use-region-p)
      (let ((region-text (buffer-substring-no-properties
                          (region-beginning)
                          (region-end))))
        (deactivate-mark)
        (isearch-mode t nil nil nil)
        (isearch-yank-string region-text))
    (isearch-forward)))

(defun rc/isearch-backward-use-region ()
  "Start backward isearch and seed it with region text when active."
  (interactive)
  (if (use-region-p)
      (let ((region-text (buffer-substring-no-properties
                          (region-beginning)
                          (region-end))))
        (deactivate-mark)
        (isearch-mode nil nil nil nil)
        (isearch-yank-string region-text))
    (isearch-backward)))

(defun rc/rgrep-selected (beg end)
  "Run rgrep using selected text between BEG and END."
  (interactive (if (use-region-p)
                   (list (region-beginning) (region-end))
                 (list (point-min) (point-min))))
  (rgrep (buffer-substring-no-properties beg end) "*" (pwd)))

(provide 'search-rc)
;;; search-rc.el ends here
