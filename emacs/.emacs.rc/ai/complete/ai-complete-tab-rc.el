;;; ai-complete-tab-rc.el --- Inline completion tab integration -*- lexical-binding: t; -*-

;;; Code:

(defun rc/gptel-inline-completion-visible-p ()
  "Return non-nil when gptel inline completion ghost text is visible."
  (and (fboundp 'gptel-autocomplete-visible-p)
       (gptel-autocomplete-visible-p)))

(defun rc/gptel-inline-tab (&optional arg)
  "Accept current ghost text, else fall back to normal tab behavior.
A non-nil prefix ARG (typically `C-u') signals a force-followup intent."
  (interactive "P")
  (rc/gptel-sync-complete-session-state)
  (if (rc/gptel-inline-completion-visible-p)
      (let ((intent (if arg 'force-followup 'default)))
        (rc/gptel-complete-accept-with-intent intent arg))
    (call-interactively #'indent-for-tab-command)))

(defun rc/gptel-inline-tab-and-stop ()
  "Accept current ghost text with force-stop intent.
Suppresses any automatic follow-up after the accept."
  (interactive)
  (rc/gptel-sync-complete-session-state)
  (if (rc/gptel-inline-completion-visible-p)
      (rc/gptel-complete-accept-with-intent 'force-stop)
    (call-interactively #'newline)))

(defun rc/gptel-inline-tab-and-followup ()
  "Accept current ghost text with force-followup intent.
Forces an automatic follow-up request even when defaults would idle."
  (interactive)
  (rc/gptel-sync-complete-session-state)
  (if (rc/gptel-inline-completion-visible-p)
      (rc/gptel-complete-accept-with-intent 'force-followup)
    (call-interactively #'newline)))

(defun rc/gptel-inline-shift-tab ()
  "Accept one word of current ghost text, else show a short hint."
  (interactive)
  (rc/gptel-sync-complete-session-state)
  (if (rc/gptel-inline-completion-visible-p)
      (call-interactively #'gptel-accept-word)
    (message "当前没有可接受的 AI 补全")))

(defun rc/gptel-inline-accept-line ()
  "Accept one line of current ghost text, else show a short hint."
  (interactive)
  (rc/gptel-sync-complete-session-state)
  (if (rc/gptel-inline-completion-visible-p)
      (call-interactively #'gptel-accept-line)
    (message "当前没有可接受的 AI 补全")))

(defun rc/gptel-inline-apply-next-edit ()
  "Apply the next queued edit, else show a short hint."
  (interactive)
  (rc/gptel-sync-complete-session-state)
  (if (> (or (plist-get (rc/gptel-complete-session-state) :next-edit-queue-size) 0) 0)
      (call-interactively #'rc/gptel-apply-next-edit)
    (message "当前没有可应用的 next edit")))

(defun rc/gptel-inline-go-to-next-location (&optional retrigger)
  "Jump to the next predicted location, optionally RETRIGGER completion."
  (interactive "P")
  (rc/gptel-sync-complete-session-state)
  (if (plist-get (rc/gptel-complete-session-state) :cursor-prediction-target-available)
      (rc/gptel-go-to-next-location retrigger)
    (message "当前没有可跳转的 next location")))

(defun rc/gptel-inline-abort-or-clear ()
  "Abort active inline completion request, else clear the current ghost text."
  (interactive)
  (cond
   ((and (fboundp 'gptel-autocomplete-active-request-id)
         (gptel-autocomplete-active-request-id)
         (fboundp 'rc/gptel-abort-current-buffer))
    (rc/gptel-abort-current-buffer))
   ((fboundp 'gptel-clear-completion)
    (gptel-clear-completion 'user-reject))
   (t
    (keyboard-quit))))

(defun rc/gptel-complete-install-buffer-hooks ()
  "Install buffer-local hooks for the current autocomplete buffer."
  (add-hook 'post-self-insert-hook
            #'rc/gptel-complete-post-self-insert-trigger
            nil t))

(defun rc/gptel-install-complete-hooks ()
  "Install hooks and key bindings for inline completion integration."
  (rc/gptel-ensure-autocomplete)
  (add-hook 'gptel-autocomplete-after-accept-hook
            #'rc/gptel-complete-accept-hook)
  (add-hook 'gptel-autocomplete-after-accept-hook
            #'rc/gptel-complete-after-accept-trigger)
  (add-hook 'gptel-autocomplete-after-accept-hook
            #'rc/gptel-complete-after-accept-jump)
  (add-hook 'gptel-autocomplete-mode-hook
            #'rc/gptel-complete-install-buffer-hooks)
  (keymap-set gptel-autocomplete-mode-map "TAB" #'rc/gptel-inline-tab)
  (keymap-set gptel-autocomplete-mode-map "<tab>" #'rc/gptel-inline-tab)
  (keymap-set gptel-autocomplete-mode-map "S-<return>" #'rc/gptel-inline-tab-and-stop)
  (keymap-set gptel-autocomplete-mode-map "C-S-<return>" #'rc/gptel-inline-tab-and-followup)
  (keymap-set gptel-autocomplete-mode-map "M-f" #'rc/gptel-inline-shift-tab)
  (keymap-set gptel-autocomplete-mode-map "M-l" #'rc/gptel-inline-accept-line)
  (keymap-set gptel-autocomplete-mode-map "M-RET" #'rc/gptel-inline-apply-next-edit)
  (keymap-set gptel-autocomplete-mode-map "M-j" #'rc/gptel-inline-go-to-next-location)
  (keymap-set gptel-autocomplete-mode-map "M-]" #'rc/gptel-inline-next-candidate)
  (keymap-set gptel-autocomplete-mode-map "M-[" #'rc/gptel-inline-previous-candidate)
  (keymap-set gptel-autocomplete-mode-map "C-g" #'rc/gptel-inline-abort-or-clear)
  (keymap-set gptel-autocomplete-completion-map "TAB" #'rc/gptel-inline-tab)
  (keymap-set gptel-autocomplete-completion-map "<tab>" #'rc/gptel-inline-tab)
  (keymap-set gptel-autocomplete-completion-map "S-<return>" #'rc/gptel-inline-tab-and-stop)
  (keymap-set gptel-autocomplete-completion-map "C-S-<return>" #'rc/gptel-inline-tab-and-followup)
  (keymap-set gptel-autocomplete-completion-map "M-f" #'gptel-accept-word)
  (keymap-set gptel-autocomplete-completion-map "M-l" #'gptel-accept-line)
  (keymap-set gptel-autocomplete-completion-map "M-RET" #'rc/gptel-inline-apply-next-edit)
  (keymap-set gptel-autocomplete-completion-map "M-j" #'rc/gptel-inline-go-to-next-location)
  (keymap-set gptel-autocomplete-completion-map "M-]" #'rc/gptel-inline-next-candidate)
  (keymap-set gptel-autocomplete-completion-map "M-[" #'rc/gptel-inline-previous-candidate)
  (keymap-set gptel-autocomplete-completion-map "C-g" #'rc/gptel-inline-abort-or-clear))

(provide 'ai-complete-tab-rc)
;;; ai-complete-tab-rc.el ends here
