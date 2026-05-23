;;; ai-action-complete-rc.el --- AI completion helpers  -*- lexical-binding: t; -*-

;;; Code:

(defun rc/gptel-completion-target-point ()
  "Return the line-end position used for manual completion."
  (save-excursion
    (if (use-region-p)
        (goto-char (region-end)))
    (line-end-position)))

(defun rc/gptel-manual-complete (&optional extra)
  "Request a completion once without enabling automatic idle completion."
  (interactive)
  (rc/gptel-prepare-inline-complete-buffer extra)
  (if (use-region-p)
      (let ((beg (region-beginning))
            (end (region-end)))
        (deactivate-mark)
        (rc/gptel-rewrite-region beg end extra))
    (unless gptel-autocomplete-mode
      (gptel-autocomplete-mode 1))
    (when (fboundp 'rc/gptel-complete-install-buffer-hooks)
      (rc/gptel-complete-install-buffer-hooks))
    (rc/gptel-cancel-complete-followup)
    (rc/gptel-cancel-complete-auto-trigger)
    (rc/gptel-complete-session-reset)
    (if (and (fboundp 'rc/gptel-complete-environment-manual-allowed-p)
             (not (rc/gptel-complete-environment-manual-allowed-p)))
        (let* ((policy (and (fboundp 'rc/gptel-complete-environment-policy)
                            (rc/gptel-complete-environment-policy 'manual)))
               (reason (or (plist-get policy :blocked-reason) 'manual-denied)))
          (when (fboundp 'rc/gptel-complete-set-policy-explain)
            (rc/gptel-complete-set-policy-explain
             (list :kind 'idle
                   :reason reason
                   :override 'manual
                   :chain-length 0
                   :chain-limit (or (and (boundp 'rc/gptel-complete-auto-continuation-chain-limit)
                                         rc/gptel-complete-auto-continuation-chain-limit)
                                    0)
                   :cooldown-active nil)))
          (when (fboundp 'rc/gptel-complete-observe-record-trace)
            (rc/gptel-complete-observe-record-trace
             'suppress
             (list :event 'manual-denied
                   :reason reason
                   :trigger-kind 'manual
                   :yield-target (plist-get policy :yield-target)
                   :org-src (plist-get policy :org-src))))
          (message "AI 补全未触发: %s" reason))
      (when (fboundp 'rc/gptel-complete-environment-yield-if-needed)
        (rc/gptel-complete-environment-yield-if-needed 'manual))
      (goto-char (rc/gptel-completion-target-point))
      (gptel-complete 'manual))))

(defun rc/gptel-autocomplete-setup ()
  "Apply one-time settings for gptel autocomplete."
  (rc/gptel-ensure-autocomplete)
  (unless (bound-and-true-p rc/gptel-autocomplete-setup-done)
    (setq rc/gptel-autocomplete-setup-done t)
    (setq gptel-autocomplete-before-context-lines 80
          gptel-autocomplete-after-context-lines 20
          gptel-autocomplete-idle-delay nil
          gptel-autocomplete-use-context nil)
    (rc/gptel-install-complete-lifecycle-hooks)
    (rc/gptel-install-complete-observe-hooks)
    (rc/gptel-install-complete-hooks)))

(defun rc/gptel-complete-code ()
  "Use the configured action profile to request code completion."
  (interactive)
  (rc/gptel-autocomplete-setup)
  (rc/gptel-manual-complete (rc/gptel-read-extra-prompt)))

(defun rc/gptel-apply-next-edit ()
  "Apply the currently queued next edit for inline completion."
  (interactive)
  (rc/gptel-sync-complete-session-state)
  (if (and (fboundp 'gptel-apply-next-edit)
           (> (or (plist-get (rc/gptel-complete-session-state) :next-edit-queue-size) 0) 0))
      (call-interactively #'gptel-apply-next-edit)
    (message "当前没有可应用的 next edit")))

(defun rc/gptel-go-to-next-location (&optional retrigger)
  "Jump to the current cursor prediction target.
With prefix RETRIGGER, also request one completion from the jumped location."
  (interactive "P")
  (rc/gptel-sync-complete-session-state)
  (if (and (fboundp 'gptel-go-to-next-location)
           (plist-get (rc/gptel-complete-session-state) :cursor-prediction-target-available))
      (gptel-go-to-next-location retrigger)
    (message "当前没有可跳转的 next location")))

(provide 'ai-action-complete-rc)
;;; ai-action-complete-rc.el ends here
