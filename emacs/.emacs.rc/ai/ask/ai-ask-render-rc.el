;;; ai-ask-render-rc.el --- Ask session rendering helpers -*- lexical-binding: t; -*-

;;; Code:

(defun rc/gptel-insert-source-block (buffer source &optional update-p)
  "Insert SOURCE block into BUFFER."
  (with-current-buffer buffer
    (let ((inhibit-read-only t))
      (goto-char (point-max))
      (insert (format "\n## %s\n\n```%s\n%s\n```\n"
                      (if update-p "Source Update" "Source")
                      (rc/gptel-ask-source-language source)
                      (plist-get source :text))))))

(defun rc/gptel-ask-source-same-p (a b)
  "Return non-nil when ask source A and B are materially the same."
  (and (equal (plist-get a :file) (plist-get b :file))
       (equal (plist-get a :text) (plist-get b :text))
       (equal (plist-get a :mode) (plist-get b :mode))))

(defun rc/gptel-ask-insert-turns (buffer turns)
  "Insert structured TURNS into BUFFER."
  (with-current-buffer buffer
    (let ((prev-source nil)
          (num 1))
      (dolist (turn turns)
        (let ((source (plist-get turn :source)))
          (when (and (listp source)
                     (stringp (plist-get source :text))
                     (not (string-empty-p (plist-get source :text)))
                     (not (rc/gptel-ask-source-same-p source prev-source)))
            (rc/gptel-insert-source-block buffer source (and prev-source t))
            (setq prev-source source)))
        (insert (format "\n## Q%d\n\n%s\n\n## A%d\n\n%s\n"
                        num
                        (string-trim (plist-get turn :question))
                        num
                        (string-trim-right (or (plist-get turn :answer) ""))))
        (setq num (1+ num))))))

(defun rc/gptel-render-ask-session-buffer (buffer source turns)
  "Rebuild ask BUFFER from SOURCE and structured TURNS."
  (with-current-buffer buffer
    (let ((inhibit-read-only t))
      (widen)
      (remove-overlays (point-min) (point-max))
      (erase-buffer)
      (insert (rc/gptel-ask-session-heading source))
      (when rc/gptel-ask-session-save-file
        (save-excursion
          (goto-char (point-min))
          (when (re-search-forward "^- Save: `.*`$" nil t)
            (replace-match
             (format "- Save: `%s`" rc/gptel-ask-session-save-file)
             t t))))
      (if (and turns (listp turns))
          (rc/gptel-ask-insert-turns buffer turns)
        (when (and (listp source)
                   (stringp (plist-get source :text))
                   (not (string-empty-p (plist-get source :text))))
          (rc/gptel-insert-source-block buffer source)))
      (goto-char (point-min))
      (set-buffer-modified-p nil))))

(provide 'ai-ask-render-rc)
;;; ai-ask-render-rc.el ends here
