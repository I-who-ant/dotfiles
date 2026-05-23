;;; ai-action-rewrite-rc.el --- AI rewrite helpers  -*- lexical-binding: t; -*-

;;; Code:

(defvar rc/gptel-rewrite-job-counter 0
  "Counter used to build stable rewrite job ids.")

(defvar-local rc/gptel-rewrite-last-job nil
  "Last rewrite job plist recorded for the current buffer.")

(defun rc/gptel-rewrite-job-meaningful-p (&optional buffer)
  "Return non-nil when BUFFER has a meaningful rewrite job snapshot."
  (with-current-buffer (or buffer (current-buffer))
    (and (listp rc/gptel-rewrite-last-job)
         (or (plist-get rc/gptel-rewrite-last-job :request-id)
             (plist-get rc/gptel-rewrite-last-job :state)
             (plist-get rc/gptel-rewrite-last-job :last-error)
             (plist-get rc/gptel-rewrite-last-job :last-result)))))

(defun rc/gptel-rewrite-action-snapshot (&optional buffer)
  "Return shared action snapshot for rewrite BUFFER, else nil."
  (with-current-buffer (or buffer (current-buffer))
    (when (rc/gptel-rewrite-job-meaningful-p (current-buffer))
      (let* ((request-id (plist-get rc/gptel-rewrite-last-job :request-id))
             (history (or (and (fboundp 'rc/gptel-action-lifecycle-history)
                               (seq-filter
                                (lambda (entry)
                                  (and (listp entry)
                                       (eq (plist-get entry :action-kind) 'rewrite)
                                       (or (null request-id)
                                           (equal (plist-get entry :request-id) request-id))))
                                (copy-sequence
                                 (rc/gptel-action-lifecycle-history (current-buffer)))))
                          (list (copy-sequence rc/gptel-rewrite-last-job))))
             (state (plist-get rc/gptel-rewrite-last-job :state)))
        (list :action-kind 'rewrite
              :title (format "rewrite:%s" (buffer-name))
              :buffer (current-buffer)
              :request-id request-id
              :state state
              :end-reason (plist-get rc/gptel-rewrite-last-job :end-reason)
              :visible nil
              :last-error (plist-get rc/gptel-rewrite-last-job :last-error)
              :backend (and (boundp 'gptel-backend) gptel-backend)
              :model (and (boundp 'gptel-model) gptel-model)
              :profile nil
              :stats nil
              :history history
              :transitions nil
              :detail
              (list :rewrite-id (plist-get rc/gptel-rewrite-last-job :rewrite-id)
                    :request-source 'region
                    :next-action-kind
                    (pcase state
                      ('requesting 'wait-response)
                      ('applied 'review-result)
                      ('failed 'retry-request)
                      ('aborted 'retry-request)
                      (_ 'none))
                    :next-action-count 1
                    :mode (plist-get rc/gptel-rewrite-last-job :mode)
                    :region (plist-get rc/gptel-rewrite-last-job :region)
                    :result (plist-get rc/gptel-rewrite-last-job :last-result)))))))

(defun rc/gptel-region-system-message (&optional extra)
  "Return a system prompt for region rewriting."
  (rc/gptel-compose-system-message
   'rewrite
   (if (derived-mode-p 'prog-mode)
       "Rewrite the selected code region. Output ONLY the replacement code, without markdown fences, explanations, or extra text."
     "Rewrite the selected text. Output ONLY the replacement text, without markdown fences, explanations, or extra text.")
   extra))

(defun rc/gptel-strip-markdown-fences (text)
  "Remove a single surrounding markdown code fence from TEXT if present."
  (let ((trimmed (string-trim text)))
    (if (string-match "^```\\(?:[a-zA-Z0-9_-]+\\)?\n\\(\\(?:.\\|\n\\)*?\\)\n```$" trimmed)
        (match-string 1 trimmed)
      trimmed)))

(defun rc/gptel-rewrite-region (beg end &optional extra)
  "Rewrite the active region from BEG to END using gptel."
  (let* ((region-text (buffer-substring-no-properties beg end))
         (buffer (current-buffer))
         (beg-marker (copy-marker beg))
         (end-marker (copy-marker end t))
         (rewrite-id (cl-incf rc/gptel-rewrite-job-counter))
         (system-message (rc/gptel-region-system-message extra))
         request-id)
    (with-current-buffer buffer
      (rc/gptel-setup-action-locals 'rewrite)
      (setq request-id (rc/gptel-action-next-request-id 'rewrite))
      (setq rc/gptel-rewrite-last-job
            (list :rewrite-id rewrite-id
                  :request-id request-id
                  :buffer buffer
                  :mode major-mode
                  :region (cons beg end)
                  :state 'requesting
                  :end-reason nil
                  :last-error nil
                  :last-result nil)))
    (when (fboundp 'rc/gptel-action-record-event)
      (with-current-buffer buffer
       (rc/gptel-action-record-event
        'rewrite
        'rewrite-started
         (list :request-id request-id
               :state 'requesting
                :rewrite-id rewrite-id
                :region (cons beg end)))))
    (rc/gptel-action-send
     :action-kind 'rewrite
     :buffer buffer
     :prompt region-text
     :position end-marker
     :system system-message
     :request-id request-id
     :detail (list :rewrite-id rewrite-id
                   :region (cons beg end)
                   :mode (buffer-local-value 'major-mode buffer))
     :on-success
     (lambda (response _info request)
       (when (and (buffer-live-p buffer)
                  (marker-buffer beg-marker)
                  (marker-buffer end-marker))
         (with-current-buffer buffer
           (let ((inhibit-read-only t)
                 (replacement (rc/gptel-strip-markdown-fences response)))
             (save-excursion
               (delete-region beg-marker end-marker)
               (goto-char beg-marker)
               (insert replacement))
             (set-marker beg-marker nil)
             (set-marker end-marker nil)
             (setq rc/gptel-rewrite-last-job
                   (plist-put rc/gptel-rewrite-last-job :state 'applied))
             (setq rc/gptel-rewrite-last-job
                   (plist-put rc/gptel-rewrite-last-job :end-reason 'applied))
             (setq rc/gptel-rewrite-last-job
                   (plist-put rc/gptel-rewrite-last-job :last-result replacement))
             (when (fboundp 'rc/gptel-action-record-event)
               (rc/gptel-action-record-event
                'rewrite
                'rewrite-applied
                (list :request-id (plist-get request :request-id)
                      :state 'applied
                      :end-reason 'applied
                      :rewrite-id rewrite-id)))
             (message "gptel region rewrite done")))))
     :on-abort
     (lambda (_response _info request)
       (when (buffer-live-p buffer)
         (with-current-buffer buffer
           (setq rc/gptel-rewrite-last-job
                 (plist-put rc/gptel-rewrite-last-job :state 'aborted))
           (setq rc/gptel-rewrite-last-job
                 (plist-put rc/gptel-rewrite-last-job :end-reason 'aborted-request))
           (setq rc/gptel-rewrite-last-job
                 (plist-put rc/gptel-rewrite-last-job :last-error "aborted"))
           (when (fboundp 'rc/gptel-action-record-event)
             (rc/gptel-action-record-event
              'rewrite
              'rewrite-aborted
              (list :request-id (plist-get request :request-id)
                    :state 'aborted
                    :end-reason 'aborted-request
                    :rewrite-id rewrite-id))))))
     :on-failure
     (lambda (_response info request)
       (when (buffer-live-p buffer)
         (with-current-buffer buffer
           (setq rc/gptel-rewrite-last-job
                 (plist-put rc/gptel-rewrite-last-job :state 'failed))
           (setq rc/gptel-rewrite-last-job
                 (plist-put rc/gptel-rewrite-last-job :end-reason 'failed-request))
           (setq rc/gptel-rewrite-last-job
                 (plist-put rc/gptel-rewrite-last-job :last-error
                            (plist-get info :status)))
           (when (fboundp 'rc/gptel-action-record-event)
             (rc/gptel-action-record-event
              'rewrite
              'rewrite-failed
              (list :request-id (plist-get request :request-id)
                    :state 'failed
                    :end-reason 'failed-request
                    :rewrite-id rewrite-id
                    :last-error (plist-get info :status)))))
         (message "gptel region rewrite failed: %s"
                  (plist-get info :status)))))))

(provide 'ai-action-rewrite-rc)
;;; ai-action-rewrite-rc.el ends here
