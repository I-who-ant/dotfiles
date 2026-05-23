;;; ai-action-request-rc.el --- Shared AI action request helper -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'seq)

(defvar rc/gptel-action-request-counter-table (make-hash-table :test #'eq)
  "Per-action request id counters keyed by action kind symbol.")

(defvar rc/gptel-action-request-history-length 40
  "Maximum number of shared request entries kept per buffer.")

(defvar-local rc/gptel-action-request-history nil
  "Shared request history for AI actions in the current buffer.")

(defvar-local rc/gptel-action-active-request nil
  "Current active shared request plist in the current buffer.")

(defvar-local rc/gptel-action-last-request nil
  "Last completed shared request plist in the current buffer.")

(defun rc/gptel-action-next-request-id (action-kind)
  "Return the next stable request id string for ACTION-KIND."
  (let ((count (1+ (gethash action-kind rc/gptel-action-request-counter-table 0))))
    (puthash action-kind count rc/gptel-action-request-counter-table)
    (format "%s-%d" (symbol-name action-kind) count)))

(defun rc/gptel-action-request-history (&optional buffer)
  "Return shared request history for BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    rc/gptel-action-request-history))

(defun rc/gptel-action-active-request (&optional buffer)
  "Return active shared request for BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    rc/gptel-action-active-request))

(defun rc/gptel-action-last-request (&optional buffer)
  "Return last completed shared request for BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    rc/gptel-action-last-request))

(defun rc/gptel-action--remember-request (request &optional buffer)
  "Push REQUEST into BUFFER-local shared request history."
  (with-current-buffer (or buffer (current-buffer))
    (push request rc/gptel-action-request-history)
    (setq rc/gptel-action-request-history
          (seq-take rc/gptel-action-request-history
                    rc/gptel-action-request-history-length))
    request))

(defun rc/gptel-action-request-find (request-id &optional buffer)
  "Return most recent shared request matching REQUEST-ID in BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    (or (and (listp rc/gptel-action-active-request)
             (equal (plist-get rc/gptel-action-active-request :request-id)
                    request-id)
             rc/gptel-action-active-request)
        (seq-find
         (lambda (request)
           (equal (plist-get request :request-id) request-id))
         rc/gptel-action-request-history))))

(defun rc/gptel-action--update-request (request &rest pairs)
  "Return REQUEST plist updated with PAIRS."
  (let ((copy (copy-sequence request)))
    (while pairs
      (setq copy (plist-put copy (pop pairs) (pop pairs))))
    copy))

(defun rc/gptel-action-request--event (state)
  "Return shared observer event symbol for request STATE."
  (pcase state
    ('requesting 'request-started)
    ('succeeded 'request-succeeded)
    ('failed 'request-failed)
    ('aborted 'request-aborted)
    ('superseded 'request-superseded)
    (_ 'request-updated)))

(defun rc/gptel-action-request-mark-finished (request state &optional extra)
  "Record REQUEST as terminal STATE, merging EXTRA, and return the updated plist."
  (with-current-buffer (plist-get request :buffer)
    (let* ((updated (apply #'rc/gptel-action--update-request
                           request
                           :state state
                           :completed-at (float-time)
                           extra))
           (event (rc/gptel-action-request--event state)))
      (when (and (listp rc/gptel-action-active-request)
                 (equal (plist-get rc/gptel-action-active-request :request-id)
                        (plist-get updated :request-id)))
        (setq rc/gptel-action-active-request nil))
      (setq rc/gptel-action-last-request updated)
      (rc/gptel-action--remember-request updated)
      (when (fboundp 'rc/gptel-action-record-event)
        (rc/gptel-action-record-event
         (plist-get updated :action-kind)
         event
         (list :request-id (plist-get updated :request-id)
               :state state
               :end-reason (plist-get updated :end-reason)
               :last-error (plist-get updated :last-error)
               :request-source (plist-get updated :request-source)
               :detail (plist-get updated :detail))))
      updated)))

(defun rc/gptel-action-request-mark-started (request)
  "Record REQUEST as started and return the updated plist."
  (with-current-buffer (plist-get request :buffer)
    (let ((started
           (rc/gptel-action--update-request
            request
            :state 'requesting
            :started-at (float-time)
            :completed-at nil
            :end-reason nil
            :last-error nil)))
      (setq rc/gptel-action-active-request started)
      (rc/gptel-action--remember-request started)
      (when (fboundp 'rc/gptel-action-record-event)
        (rc/gptel-action-record-event
         (plist-get started :action-kind)
         'request-started
         (list :request-id (plist-get started :request-id)
               :state 'requesting
               :request-source (plist-get started :request-source)
               :detail (plist-get started :detail))))
      started)))

(defun rc/gptel-action-request-mark-succeeded (request &optional extra)
  "Record REQUEST as succeeded, merging EXTRA, and return the updated plist."
  (rc/gptel-action-request-mark-finished request 'succeeded extra))

(defun rc/gptel-action-request-mark-failed (request status &optional end-reason extra)
  "Record REQUEST as failed with STATUS and optional END-REASON, merging EXTRA."
  (rc/gptel-action-request-mark-finished
   request
   'failed
   (append
    (list :end-reason (or end-reason 'failed-request)
          :last-error status)
    extra)))

(defun rc/gptel-action-request-mark-aborted (request &optional extra)
  "Record REQUEST as aborted, merging EXTRA."
  (rc/gptel-action-request-mark-finished
   request
   'aborted
   (append
    (list :end-reason 'aborted-request
          :last-error "aborted")
    extra)))

(defun rc/gptel-action-request-mark-superseded (request &optional extra)
  "Record REQUEST as superseded, merging EXTRA."
  (rc/gptel-action-request-mark-finished
   request
   'superseded
   (append
    (list :end-reason 'ignored-superseded)
    extra)))

(cl-defun rc/gptel-action-send (&key action-kind buffer prompt position system stream
                                     request-id request-source detail transforms
                                     on-stream on-success on-failure on-abort)
  "Send one shared AI action request.

ACTION-KIND and BUFFER are required.
PROMPT, POSITION, SYSTEM, STREAM and TRANSFORMS are forwarded to `gptel-request'.
REQUEST-ID defaults to `rc/gptel-action-next-request-id'.
REQUEST-SOURCE and DETAIL are recorded in the shared request history.
ON-STREAM, ON-SUCCESS, ON-FAILURE and ON-ABORT are callback functions."
  (rc/gptel-ensure-core)
  (let* ((target (or buffer (current-buffer)))
         (request
          (with-current-buffer target
            (rc/gptel-action-request-mark-started
             (list :action-kind action-kind
                   :request-id (or request-id
                                   (rc/gptel-action-next-request-id action-kind))
                   :request-source request-source
                   :buffer target
                   :position position
                   :prompt prompt
                   :system system
                   :stream stream
                   :detail detail)))))
    (gptel-request
     prompt
     :buffer target
     :position position
     :stream stream
     :system system
     :transforms transforms
     :callback
     (lambda (response info)
       (with-current-buffer target
         (cond
          ((and stream (stringp response))
           (when on-stream
             (funcall on-stream response info request)))
          ((or (and stream (eq response t))
               (and (not stream) (stringp response)))
           (let ((done (rc/gptel-action-request-mark-succeeded request)))
             (when on-success
               (funcall on-success response info done))))
          ((eq response 'abort)
           (let ((aborted (rc/gptel-action-request-mark-aborted request)))
             (when on-abort
               (funcall on-abort response info aborted))))
          (t
           (let ((failed (rc/gptel-action-request-mark-failed
                          request
                          (plist-get info :status)
                          'failed-request)))
             (when on-failure
               (funcall on-failure response info failed))))))))
    request))

(defun rc/gptel-action-abort (&optional buffer)
  "Abort the active gptel request in BUFFER, else return nil."
  (let ((target (or buffer (current-buffer))))
    (when (rc/gptel-buffer-active-request-p target)
      (gptel-abort target)
      t)))

(provide 'ai-action-request-rc)
;;; ai-action-request-rc.el ends here
