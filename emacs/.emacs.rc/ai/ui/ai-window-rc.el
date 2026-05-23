;;; ai-window-rc.el --- AI window helpers  -*- lexical-binding: t; -*-

;;; Code:

(defun rc/gptel-show-answer-buffer (buffer)
  "Display BUFFER in a side window at the bottom."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when (and (boundp 'rc/gptel-ask-session-source)
                 (boundp 'rc/gptel-ask-session-turns)
                 (boundp 'rc/gptel-ask-session-save-file)
                 (or rc/gptel-ask-session-save-file
                     (and (listp rc/gptel-ask-session-source)
                          (stringp (plist-get rc/gptel-ask-session-source :text)))))
        (rc/gptel-render-ask-session-buffer
         buffer
         rc/gptel-ask-session-source
         rc/gptel-ask-session-turns))))
  (let ((window
         (display-buffer
          buffer
          '((display-buffer-in-side-window)
            (side . bottom)
            (slot . 0)
            (window-height . 0.28)))))
    (when (window-live-p window)
      (set-window-buffer window buffer)
      (with-current-buffer buffer
        (goto-char (point-min))
        (set-window-point window (point-min))
        (set-window-start window (point-min) t))
      window)))

(defun rc/gptel-answer-window-follow-p (window)
  "Return non-nil when WINDOW is still following the buffer bottom."
  (when (window-live-p window)
    (let ((window-end (window-end window t))
          (buffer-end (with-current-buffer (window-buffer window)
                        (point-max))))
      (and window-end
           (>= window-end buffer-end)))))

(defun rc/gptel-answer-windows-at-bottom-p (buffer)
  "Return windows showing BUFFER together with whether each is following output."
  (mapcar
   (lambda (window)
     (cons window (rc/gptel-answer-window-follow-p window)))
   (get-buffer-window-list buffer nil t)))

(defun rc/gptel-answer-refresh-windows (window-states)
  "Refresh answer windows using WINDOW-STATES."
  (dolist (entry window-states)
    (let ((window (car entry))
          (follow-p (cdr entry)))
      (when (window-live-p window)
        (when follow-p
          (with-current-buffer (window-buffer window)
            (set-window-point window (point-max))))))))

(provide 'ai-window-rc)
;;; ai-window-rc.el ends here
