;;; ai-action-lifecycle-rc.el --- Shared AI action lifecycle helpers -*- lexical-binding: t; -*-

;;; Code:

(require 'seq)

(defvar-local rc/gptel-action-lifecycle-history nil
  "Shared lifecycle history for AI actions in the current buffer.")

(defvar rc/gptel-action-lifecycle-history-length 40
  "Maximum number of shared lifecycle entries kept per buffer.")

(defun rc/gptel-action-lifecycle-history (&optional buffer)
  "Return shared lifecycle history for BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    rc/gptel-action-lifecycle-history))

(defun rc/gptel-action-record-event (action-kind event &optional extra buffer)
  "Record one shared lifecycle EVENT for ACTION-KIND in BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    (let ((payload (append
                    (list :action-kind action-kind
                          :event event
                          :buffer (current-buffer)
                          :timestamp (float-time))
                    extra)))
      (push payload rc/gptel-action-lifecycle-history)
      (setq rc/gptel-action-lifecycle-history
            (seq-take rc/gptel-action-lifecycle-history
                      rc/gptel-action-lifecycle-history-length))
      payload)))

(defun rc/gptel-complete-shared-lifecycle-history (&optional buffer)
  "Return complete lifecycle history normalized to the shared event shape."
  (with-current-buffer (or buffer (current-buffer))
    (mapcar
     (lambda (entry)
       (append
        (list :action-kind 'complete)
        entry))
     (or (plist-get (and (fboundp 'rc/gptel-complete-session-state)
                         (rc/gptel-complete-session-state))
                    :lifecycle-history)
         nil))))

(provide 'ai-action-lifecycle-rc)
;;; ai-action-lifecycle-rc.el ends here
