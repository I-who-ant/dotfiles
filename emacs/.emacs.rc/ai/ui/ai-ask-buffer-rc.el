;;; ai-ask-buffer-rc.el --- Ask buffer UI helpers  -*- lexical-binding: t; -*-

;;; Code:

(defvar rc/gptel-ask-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-g") #'rc/gptel-abort-current-buffer)
    map)
  "Keymap used in ask session buffers.")

(defun rc/gptel-prepare-answer-buffer (buffer source heading-fn)
  "Initialize ask BUFFER display using SOURCE and HEADING-FN."
  (with-current-buffer buffer
    (let ((inhibit-read-only t))
      (kill-all-local-variables)
      (widen)
      (remove-overlays (point-min) (point-max))
      (erase-buffer)
      (insert (funcall heading-fn source))
      (when (fboundp 'markdown-mode)
        (markdown-mode))
      (setq-local truncate-lines nil)
      (use-local-map (copy-keymap rc/gptel-ask-mode-map))
      (view-mode 1)
      (set-buffer-modified-p nil)
      (goto-char (point-min))
      (point-max))))

(provide 'ai-ask-buffer-rc)
;;; ai-ask-buffer-rc.el ends here
