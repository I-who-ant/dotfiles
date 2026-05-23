;;; ai-complete-schedule-rc.el --- Request scheduling and priority -*- lexical-binding: t; -*-

;;; Code:

(defvar rc/gptel-complete-request-priority-alist
  '((manual . 30)
    (followup . 20)
    (auto . 10)
    (retry . 5))
  "Priority table for inline completion request sources.")

(defvar-local rc/gptel-complete-last-request-source 'manual
  "Last inline completion request source in current buffer.")

(defvar-local rc/gptel-complete-last-request-time 0.0
  "Timestamp of last inline completion request in current buffer.")

(defvar rc/gptel-complete-min-request-interval 0.05
  "Minimum interval between completion requests in the same buffer.")

(defun rc/gptel-complete-request-priority (source)
  "Return numeric priority for request SOURCE."
  (or (cdr (assq source rc/gptel-complete-request-priority-alist)) 0))

(defun rc/gptel-complete-register-request-source (source)
  "Record current request SOURCE for scheduling decisions."
  (setq-local rc/gptel-complete-last-request-source source)
  (setq-local rc/gptel-complete-last-request-time (float-time)))

(defun rc/gptel-complete-request-allowed-p (source)
  "Return non-nil when SOURCE may start a new completion request now."
  (let ((now (float-time)))
    (or (> (- now rc/gptel-complete-last-request-time)
           rc/gptel-complete-min-request-interval)
        (> (rc/gptel-complete-request-priority source)
           (rc/gptel-complete-request-priority
            rc/gptel-complete-last-request-source)))))

(provide 'ai-complete-schedule-rc)
;;; ai-complete-schedule-rc.el ends here
