;;; ai-complete-trigger-rc.el --- Inline completion follow-up trigger -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'ai-complete-cooldown-rc)

(defvar-local rc/gptel-complete-auto-trigger-enabled nil
  "Non-nil enables conservative semi-automatic inline completion triggers in this buffer.")

(defvar-local rc/gptel-complete-auto-trigger-mode 'off
  "Semi-auto trigger mode for current buffer.
Supported values are `off', `on' and `diagnose'.")

(defvar rc/gptel-complete-auto-trigger-delay 0.08
  "Seconds to wait before semi-automatic inline completion trigger.")

(defvar rc/gptel-complete-auto-trigger-line-end-delay 0.08
  "Seconds to wait before a line-end driven inline completion trigger.")

(defvar rc/gptel-complete-auto-trigger-direct-char-delay 0.12
  "Seconds to wait before a direct-char driven inline completion trigger.")

(defvar rc/gptel-complete-cache-refresh-delay 0.05
  "Seconds to wait before refreshing visible ghost text from cache.")

(defvar rc/gptel-complete-cache-refresh-throttle 0.2
  "Minimum seconds between cache-driven refresh attempts.")

(defvar rc/gptel-complete-auto-trigger-chars
  '(?. ?> ?: ?\( ?,)
  "Characters that may trigger conservative inline completion.")

(defvar-local rc/gptel-complete-auto-trigger-timer nil
  "Pending semi-automatic inline completion timer in the current buffer.")

(defvar-local rc/gptel-complete-pending-auto-trigger-token nil
  "Pending auto-trigger token used to dedupe duplicate timer fires.")

(defvar-local rc/gptel-complete-cache-refresh-timer nil
  "Pending cache refresh timer for inline completion in the current buffer.")

(defvar-local rc/gptel-complete-last-cache-refresh-at 0
  "Last timestamp when cache-driven refresh was attempted in this buffer.")

(defvar-local rc/gptel-complete-last-auto-trigger-check nil
  "Last diagnostic plist for semi-automatic inline completion trigger.")

(defvar-local rc/gptel-complete-auto-trigger-history nil
  "Recent diagnostic checks for semi-automatic inline completion.")

(defvar rc/gptel-complete-auto-trigger-history-length 20
  "Maximum number of recent semi-automatic trigger checks to keep.")

(defvar rc/gptel-complete-auto-trigger-diagnose-message-interval 0.6
  "Minimum seconds between repeated diagnose minibuffer messages.")

(defvar-local rc/gptel-complete-last-diagnose-message nil
  "Last diagnose minibuffer message metadata plist.")

(defconst rc/gptel-complete-external-trigger-sources
  '(lsp-suggestions signature-help flymake-diagnostics post-jump-retrigger)
  "External trigger sources supported by the inline completion runtime.")

(defvar rc/gptel-complete-source-rules
  '((auto-typing :enabled t :delay 0.08)
    (followup :enabled t :delay 0.12)
    (cache-refresh :enabled t :delay 0.05)
    (post-jump-retrigger :enabled t :delay 0.02)
    (lsp-suggestions :enabled t :delay 0.03)
    (signature-help :enabled t :delay 0.04)
    (flymake-diagnostics :enabled t :delay 0.08))
  "Default policy rules for richer completion trigger sources.")

(defconst rc/gptel-complete-auto-trigger-mode-cycle
  '(off on diagnose)
  "Cycle order for semi-auto trigger mode.")

(defun rc/gptel-complete-source-rule (&optional source)
  "Return effective rule plist for trigger SOURCE in current buffer."
  (let* ((source-key (or source 'auto-typing))
         (default (alist-get source-key rc/gptel-complete-source-rules))
         (mode-rules (plist-get (rc/gptel-complete-mode-rule) :source-rules))
         (mode-rule (alist-get source-key mode-rules)))
    (append mode-rule default)))

(defun rc/gptel-prepare-inline-complete-buffer (&optional extra)
  "Prepare current buffer locals for inline completion requests.
Merge optional EXTRA prompt with the active mode-specific rules."
  (rc/gptel-ensure-autocomplete)
  (rc/gptel-setup-action-locals 'complete)
  (setq-local gptel-autocomplete-system-message-extra
              (rc/gptel-compose-complete-extra extra)))

(defun rc/gptel-cancel-complete-auto-trigger ()
  "Cancel any pending semi-automatic inline completion timer."
  (when (timerp rc/gptel-complete-auto-trigger-timer)
    (cancel-timer rc/gptel-complete-auto-trigger-timer)
    (setq rc/gptel-complete-auto-trigger-timer nil))
  (setq rc/gptel-complete-pending-auto-trigger-token nil))

(defun rc/gptel-cancel-complete-cache-refresh ()
  "Cancel any pending cache-driven inline completion refresh timer."
  (when (timerp rc/gptel-complete-cache-refresh-timer)
    (cancel-timer rc/gptel-complete-cache-refresh-timer)
    (setq rc/gptel-complete-cache-refresh-timer nil)))

(defun rc/gptel-complete-set-auto-trigger-mode (mode)
  "Set current buffer semi-auto trigger MODE."
  (setq rc/gptel-complete-auto-trigger-mode mode
        rc/gptel-complete-auto-trigger-enabled (memq mode '(on diagnose))))

(defun rc/gptel-complete-cycle-auto-trigger-mode ()
  "Return next semi-auto trigger mode."
  (let* ((current (or rc/gptel-complete-auto-trigger-mode 'off))
         (tail (memq current rc/gptel-complete-auto-trigger-mode-cycle)))
    (or (cadr tail)
        (car rc/gptel-complete-auto-trigger-mode-cycle))))

(defun rc/gptel-complete-auto-trigger-diagnose-p ()
  "Return non-nil when semi-auto trigger is in diagnose mode."
  (eq rc/gptel-complete-auto-trigger-mode 'diagnose))

(defun rc/gptel-complete-record-auto-trigger-check (diag)
  "Record auto-trigger DIAG into recent history."
  (push diag rc/gptel-complete-auto-trigger-history)
  (setq rc/gptel-complete-auto-trigger-history
        (seq-take rc/gptel-complete-auto-trigger-history
                  rc/gptel-complete-auto-trigger-history-length))
  diag)

(defun rc/gptel-complete-trigger-source-label (source)
  "Return readable label for trigger SOURCE."
  (pcase source
    ('auto-typing "auto-typing")
    ('followup "followup")
    ('cache-refresh "cache-refresh")
    ('post-jump-retrigger "post-jump")
    ('lsp-suggestions "lsp")
    ('signature-help "signature")
    ('flymake-diagnostics "flymake")
    (_ (format "%s" (or source 'unknown)))))

(defun rc/gptel-complete-auto-trigger-blocked-reason-counts ()
  "Return alist of blocked reason counts from recent trigger history."
  (let (counts)
    (dolist (entry rc/gptel-complete-auto-trigger-history)
      (let ((reason (plist-get entry :blocked-reason)))
        (when reason
          (setf (alist-get reason counts nil nil #'eq)
                (1+ (or (alist-get reason counts nil nil #'eq) 0))))))
    counts))

(defun rc/gptel-complete-last-successful-trigger-check ()
  "Return most recent successful trigger diagnostic, else nil."
  (seq-find (lambda (entry)
              (plist-get entry :eligible))
            rc/gptel-complete-auto-trigger-history))

(defun rc/gptel-complete-should-echo-diagnose-message-p (diag)
  "Return non-nil when DIAG should be echoed to minibuffer."
  (let* ((now (float-time))
         (last rc/gptel-complete-last-diagnose-message)
         (last-reason (plist-get last :blocked-reason))
         (last-time (or (plist-get last :timestamp) 0))
         (reason (plist-get diag :blocked-reason)))
    (or (not (eq reason last-reason))
        (> (- now last-time) rc/gptel-complete-auto-trigger-diagnose-message-interval))))

(defun rc/gptel-complete-in-comment-or-string-p ()
  "Return non-nil when point is inside a comment or string."
  (cond
   ((and (derived-mode-p 'c-mode 'c++-mode 'java-mode)
         (fboundp 'c-in-literal))
    (memq (ignore-errors (c-in-literal)) '(c c++ string)))
   (t
    (let ((ppss (syntax-ppss)))
      (or (nth 3 ppss) (nth 4 ppss))))))

(defun rc/gptel-complete-in-preprocessor-p ()
  "Return non-nil when point is on a C-family preprocessor line."
  (and (derived-mode-p 'c-mode 'c++-mode 'c-ts-mode 'c++-ts-mode)
       (save-excursion
         (beginning-of-line)
         (or (looking-at-p "[[:space:]]*#")
             ;; Treat macro continuation lines as preprocessor context too.
             (let ((connected t)
                   found)
               (while (and connected
                           (not found)
                           (not (bobp)))
                 (forward-line -1)
                 (let ((line (buffer-substring-no-properties
                              (line-beginning-position)
                              (line-end-position))))
                   (if (string-match-p "\\`[[:space:]]*#" line)
                       (setq found t)
                     (setq connected
                           (string-match-p "\\\\[[:space:]]*\\'" line)))))
               found)))))

(defun rc/gptel-complete-policy-allows-point-context-p ()
  "Return non-nil when current point context is allowed by mode policy."
  (let* ((policy (rc/gptel-complete-mode-rule))
         (literal-kind
          (and (derived-mode-p 'c-mode 'c++-mode 'java-mode)
               (fboundp 'c-in-literal)
               (ignore-errors (c-in-literal))))
         (ppss (unless literal-kind (syntax-ppss)))
         (in-string (if literal-kind
                        (eq literal-kind 'string)
                      (nth 3 ppss)))
         (in-comment (if literal-kind
                         (memq literal-kind '(c c++))
                       (nth 4 ppss)))
         (in-preprocessor (rc/gptel-complete-in-preprocessor-p)))
    (and (or (not in-comment)
             (plist-get policy :allow-in-comment))
         (or (not in-string)
             (plist-get policy :allow-in-string))
         (or (not in-preprocessor)
             (plist-get policy :allow-in-preprocessor)))))

(defun rc/gptel-complete-auto-trigger-eligible-p ()
  "Return non-nil when current buffer state allows semi-auto completion."
  (and rc/gptel-complete-auto-trigger-enabled
       (bound-and-true-p gptel-autocomplete-mode)
       (or (not (fboundp 'rc/gptel-complete-environment-auto-allowed-p))
           (rc/gptel-complete-environment-auto-allowed-p))
       (not (minibufferp))
       (not (use-region-p))
       (eolp)
       (not (rc/gptel-inline-completion-visible-p))
       (rc/gptel-complete-policy-allows-point-context-p)
       (not (and (fboundp 'gptel-autocomplete-active-request-id)
                 (gptel-autocomplete-active-request-id)))
       (not (rc/gptel-complete-cooldown-active-entry))))

(defun rc/gptel-complete-cache-refresh-eligible-p (&optional prefix after-cursor-in-line)
  "Return non-nil when current buffer can refresh a cached ghost text.
Optional PREFIX and AFTER-CURSOR-IN-LINE constrain the expected cache match."
  (and (bound-and-true-p gptel-autocomplete-mode)
       (derived-mode-p 'prog-mode)
       (not (minibufferp))
       (not (use-region-p))
       (eolp)
       (not (rc/gptel-inline-completion-visible-p))
       (rc/gptel-complete-policy-allows-point-context-p)
       (not (and (fboundp 'gptel-autocomplete-active-request-id)
                 (gptel-autocomplete-active-request-id)))
       (fboundp 'gptel-autocomplete-cache-match)
       (gptel-autocomplete-cache-match nil prefix after-cursor-in-line)))

(defun rc/gptel-complete-trigger-chars ()
  "Return trigger chars for the current major mode."
  (or (plist-get (rc/gptel-complete-mode-rule) :trigger-chars)
      rc/gptel-complete-auto-trigger-chars))

(defun rc/gptel-complete-line-end-trigger-p ()
  "Return non-nil when current line shape warrants an end-of-line trigger."
  (when (plist-get (rc/gptel-complete-mode-rule) :auto-line-end)
    (let ((predicate (rc/gptel-complete-mode-handler :line-end-predicate))
          (regexp (plist-get (rc/gptel-complete-mode-rule) :line-end-regexp)))
      (if predicate
          (funcall predicate)
        (and regexp
             (save-excursion
               (skip-chars-backward " \t")
               (looking-back regexp (line-beginning-position))))))))

(defun rc/gptel-complete-direct-char-trigger-p (ch)
  "Return non-nil when direct char CH should trigger completion."
  (when (characterp ch)
    (let ((predicate (rc/gptel-complete-mode-handler :direct-char-predicate)))
      (if predicate
          (funcall predicate ch)
        (memq ch (rc/gptel-complete-trigger-chars))))))

(defun rc/gptel-complete-trigger-match-kind (&optional event)
  "Return trigger match kind for EVENT in current buffer."
  (let ((ch (or event last-command-event)))
    (cond
     ((not (characterp ch)) nil)
     ((rc/gptel-complete-direct-char-trigger-p ch) 'direct-char)
     ((rc/gptel-complete-line-end-trigger-p)
      'line-end)
     (t nil))))

(defun rc/gptel-complete-auto-trigger-blocked-reason (&optional event)
  "Return non-nil blocked reason symbol for auto-trigger on EVENT."
  (cond
   ((not rc/gptel-complete-auto-trigger-enabled) 'auto-trigger-disabled)
   ((not (bound-and-true-p gptel-autocomplete-mode)) 'autocomplete-mode-disabled)
   ((and (fboundp 'rc/gptel-complete-environment-blocked-reason)
         (rc/gptel-complete-environment-blocked-reason 'auto)))
   ((minibufferp) 'minibuffer)
   ((use-region-p) 'region-active)
   ((not (eolp)) 'not-end-of-line)
   ((rc/gptel-inline-completion-visible-p) 'ghost-visible)
   ((rc/gptel-complete-in-preprocessor-p) 'preprocessor-context)
   ((not (rc/gptel-complete-policy-allows-point-context-p)) 'comment-or-string)
   ((and (fboundp 'gptel-autocomplete-active-request-id)
         (gptel-autocomplete-active-request-id))
    'request-active)
   ((rc/gptel-complete-cooldown-active-entry) 'cooldown-active)
   ((not (characterp (or event last-command-event))) 'not-character-event)
   ((not (rc/gptel-complete-trigger-match-kind event)) 'no-trigger-match)
   (t nil)))

(defun rc/gptel-complete-auto-trigger-diagnostics (&optional event)
  "Return diagnostic plist for auto-trigger on EVENT."
  (let* ((match-kind (rc/gptel-complete-trigger-match-kind event))
         (blocked-reason (rc/gptel-complete-auto-trigger-blocked-reason event)))
    (list :major-mode major-mode
          :trigger-source 'auto-typing
          :source-rule (rc/gptel-complete-source-rule 'auto-typing)
          :event (or event last-command-event)
          :event-char (and (characterp (or event last-command-event))
                           (string (or event last-command-event)))
          :trigger-match-kind match-kind
          :line-end-match (rc/gptel-complete-line-end-trigger-p)
          :eligible (null blocked-reason)
          :blocked-reason blocked-reason
          :mode rc/gptel-complete-auto-trigger-mode
          :auto-trigger-enabled rc/gptel-complete-auto-trigger-enabled
          :autocomplete-mode (bound-and-true-p gptel-autocomplete-mode)
          :visible (rc/gptel-inline-completion-visible-p)
          :request-active (and (fboundp 'gptel-autocomplete-active-request-id)
                               (gptel-autocomplete-active-request-id))
          :in-comment-or-string (rc/gptel-complete-in-comment-or-string-p)
          :in-preprocessor (rc/gptel-complete-in-preprocessor-p)
          :at-eol (eolp)
          :timestamp (float-time)
          :trigger-chars (rc/gptel-complete-trigger-chars))))

(defun rc/gptel-complete-auto-trigger-diagnostic-message (diag)
  "Format a concise minibuffer message from trigger DIAG."
  (let ((reason (or (plist-get diag :blocked-reason) 'ok))
        (source (rc/gptel-complete-trigger-source-label
                 (plist-get diag :trigger-source)))
        (event-char (or (plist-get diag :event-char) "n/a"))
        (line-end (if (plist-get diag :line-end-match) "yes" "no"))
        (at-eol (if (plist-get diag :at-eol) "yes" "no")))
    (format "AI 半自动未触发[%s]: source=%s reason=%s event=%s eol=%s line-end=%s"
            (plist-get diag :major-mode)
            source
            reason
            event-char
            at-eol
            line-end)))

(defun rc/gptel-run-complete-auto-trigger (buffer point tick token)
  "Run semi-automatic inline completion in BUFFER if POINT/TICK/TOKEN still match."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq rc/gptel-complete-auto-trigger-timer nil)
      (cond
       ((not (equal token rc/gptel-complete-pending-auto-trigger-token))
        (when (fboundp 'rc/gptel-complete-observe-record-trace)
          (rc/gptel-complete-observe-record-trace
           'timer
           (list :event 'duplicate-auto-trigger
                 :trigger-kind 'auto
                 :token token))))
       ((not (and (= (point) point)
                  (= (buffer-chars-modified-tick) tick)))
        (setq rc/gptel-complete-pending-auto-trigger-token nil)
        (when (fboundp 'rc/gptel-complete-observe-record-trace)
          (rc/gptel-complete-observe-record-trace
           'timer
           (list :event 'stale-auto-trigger
                 :trigger-kind 'auto
                 :token token
                 :target-point point))))
       ((rc/gptel-complete-cooldown-active-entry)
        (setq rc/gptel-complete-pending-auto-trigger-token nil)
        (cl-incf rc/gptel-complete-cooldown-hit-count)
        (rc/gptel-complete-set-policy-explain
         (list :kind 'idle
               :reason 'cooldown
               :override 'auto
               :chain-length rc/gptel-complete-auto-continuation-chain-length
               :chain-limit rc/gptel-complete-auto-continuation-chain-limit
               :cooldown-active t))
        (when (fboundp 'rc/gptel-complete-observe-record-trace)
          (rc/gptel-complete-observe-record-trace
           'suppress
           (list :event 'auto-denied
                 :reason 'cooldown-active
                 :trigger-kind 'auto
                 :token token))))
       ((rc/gptel-complete-auto-trigger-eligible-p)
        (setq rc/gptel-complete-pending-auto-trigger-token nil)
        (rc/gptel-prepare-inline-complete-buffer)
        (rc/gptel-sync-complete-session-state)
        (rc/gptel-complete-session-update
         :auto-triggered-count
         (1+ (or (plist-get (rc/gptel-complete-session-state)
                            :auto-triggered-count)
                 0)))
        (gptel-complete 'auto))))))

(defun rc/gptel-complete-source-eligible-p (source)
  "Return non-nil when external trigger SOURCE is allowed right now."
  (let ((rule (rc/gptel-complete-source-rule source)))
    (and (plist-get rule :enabled)
         (bound-and-true-p gptel-autocomplete-mode)
         (derived-mode-p 'prog-mode)
         (not (minibufferp))
         (not (use-region-p))
         (eolp)
         (not (rc/gptel-inline-completion-visible-p))
         (rc/gptel-complete-policy-allows-point-context-p)
         (not (and (fboundp 'gptel-autocomplete-active-request-id)
                   (gptel-autocomplete-active-request-id))))))

(defun rc/gptel-complete-source-diagnostics (source &optional payload)
  "Return diagnostic plist for external trigger SOURCE using PAYLOAD."
  (let* ((rule (rc/gptel-complete-source-rule source))
         (blocked-reason
          (cond
           ((not (plist-get rule :enabled)) 'source-disabled)
           ((not (bound-and-true-p gptel-autocomplete-mode)) 'autocomplete-mode-disabled)
           ((and (fboundp 'rc/gptel-complete-environment-blocked-reason)
                 (rc/gptel-complete-environment-blocked-reason 'external)))
           ((minibufferp) 'minibuffer)
           ((use-region-p) 'region-active)
           ((not (eolp)) 'not-end-of-line)
           ((rc/gptel-inline-completion-visible-p) 'ghost-visible)
           ((rc/gptel-complete-in-preprocessor-p) 'preprocessor-context)
           ((not (rc/gptel-complete-policy-allows-point-context-p)) 'comment-or-string)
           ((and (fboundp 'gptel-autocomplete-active-request-id)
                 (gptel-autocomplete-active-request-id))
            'request-active)
           (t nil))))
    (list :major-mode major-mode
          :trigger-source source
          :source-rule rule
          :payload payload
          :eligible (null blocked-reason)
          :blocked-reason blocked-reason
          :mode rc/gptel-complete-auto-trigger-mode
          :autocomplete-mode (bound-and-true-p gptel-autocomplete-mode)
          :visible (rc/gptel-inline-completion-visible-p)
          :at-eol (eolp)
          :timestamp (float-time))))

(defun rc/gptel-run-complete-external-source (buffer point tick source)
  "Run external trigger SOURCE in BUFFER if POINT and TICK still match."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when (and (= (point) point)
                 (= (buffer-chars-modified-tick) tick)
                 (rc/gptel-complete-source-eligible-p source))
        (gptel-complete source)))))

(defun rc/gptel-complete-notify-source-event (source &optional payload)
  "Notify inline runtime that external trigger SOURCE became available.
PAYLOAD is kept in diagnostics/history for later inspection."
  (let ((diag (rc/gptel-complete-source-diagnostics source payload)))
    (setq rc/gptel-complete-last-auto-trigger-check diag)
    (rc/gptel-complete-record-auto-trigger-check diag)
    (when (plist-get diag :eligible)
      (let* ((rule (plist-get diag :source-rule))
             (delay (or (plist-get rule :delay) 0.03)))
        (run-with-timer
         delay
         nil
         #'rc/gptel-run-complete-external-source
         (current-buffer)
         (point)
         (buffer-chars-modified-tick)
         source)))
    diag))

(defun rc/gptel-complete-notify-lsp-suggestions (&optional payload)
  "Notify inline runtime that LSP suggestions are visible using PAYLOAD."
  (interactive)
  (rc/gptel-complete-notify-source-event 'lsp-suggestions payload))

(defun rc/gptel-complete-notify-signature-help (&optional payload)
  "Notify inline runtime that signature help is visible using PAYLOAD."
  (interactive)
  (rc/gptel-complete-notify-source-event 'signature-help payload))

(defun rc/gptel-complete-notify-flymake-diagnostics (&optional payload)
  "Notify inline runtime that flymake diagnostics changed using PAYLOAD."
  (interactive)
  (rc/gptel-complete-notify-source-event 'flymake-diagnostics payload))

(defun rc/gptel-run-complete-cache-refresh (buffer point tick prefix after-cursor-in-line source)
  "Refresh cache-backed ghost text in BUFFER if POINT/TICK and cache still match."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq rc/gptel-complete-cache-refresh-timer nil)
      (when (and (= (point) point)
                 (= (buffer-chars-modified-tick) tick)
                 (rc/gptel-complete-cache-refresh-eligible-p prefix after-cursor-in-line))
        (setq rc/gptel-complete-last-cache-refresh-at (float-time))
        (when (fboundp 'gptel--record-lifecycle-event)
          (gptel--record-lifecycle-event
           'cache-refresh-triggered
           (list :source source
           :target-point point)))
        (gptel-complete 'cache-refresh)))))

(defun rc/gptel-complete-try-immediate-cache-refresh (payload)
  "Try to show a matching cached completion immediately using PAYLOAD.
Return non-nil when a cache entry was displayed without waiting for a timer."
  (let ((source (plist-get payload :source))
        (prefix (plist-get payload :prefix))
        (after-cursor-in-line (plist-get payload :after)))
    (when (and (eq source 'superseded)
               (rc/gptel-complete-cache-refresh-eligible-p
                prefix after-cursor-in-line)
               (fboundp 'gptel--completion-cache-pop)
               (fboundp 'gptel--completion-show-cache))
      (let ((cached (gptel--completion-cache-pop
                     (point) prefix after-cursor-in-line)))
        (when cached
          (setq rc/gptel-complete-last-cache-refresh-at (float-time))
          (when (fboundp 'gptel--record-lifecycle-event)
            (gptel--record-lifecycle-event
             'cache-refresh-triggered
             (list :source source
                   :target-point (point)
                   :immediate t)))
          (gptel--completion-show-cache cached)
          t)))))

(defun rc/gptel-complete-handle-cache-available (payload)
  "Schedule one cache refresh attempt using PAYLOAD from plugin runtime."
  (let* ((source (plist-get payload :source))
         (diag (rc/gptel-complete-source-diagnostics 'cache-refresh payload)))
    (setq rc/gptel-complete-last-auto-trigger-check diag)
    (rc/gptel-complete-record-auto-trigger-check diag)
    (when (and (memq source '(superseded result))
               (plist-get diag :eligible)
               (> (- (float-time) (or rc/gptel-complete-last-cache-refresh-at 0))
                  rc/gptel-complete-cache-refresh-throttle)
               (rc/gptel-complete-cache-refresh-eligible-p
                (plist-get payload :prefix)
                (plist-get payload :after)))
      (unless (rc/gptel-complete-try-immediate-cache-refresh payload)
        (rc/gptel-cancel-complete-cache-refresh)
        (setq rc/gptel-complete-cache-refresh-timer
              (run-with-timer
               rc/gptel-complete-cache-refresh-delay
               nil
               #'rc/gptel-run-complete-cache-refresh
               (current-buffer)
               (point)
               (buffer-chars-modified-tick)
               (plist-get payload :prefix)
               (plist-get payload :after)
               source))))))

(defun rc/gptel-complete-post-self-insert-trigger ()
  "Conservatively trigger inline completion after selected punctuation."
  (let ((diag (rc/gptel-complete-auto-trigger-diagnostics last-command-event)))
    (setq rc/gptel-complete-last-auto-trigger-check diag)
    (rc/gptel-complete-record-auto-trigger-check diag)
    (if (plist-get diag :eligible)
        (progn
          (rc/gptel-cancel-complete-auto-trigger)
          (let ((token (list (point)
                             (buffer-chars-modified-tick)
                             (float-time))))
            (setq rc/gptel-complete-pending-auto-trigger-token token
                  rc/gptel-complete-auto-trigger-timer
                  (run-with-timer
                   (pcase (plist-get diag :trigger-match-kind)
                     ('line-end rc/gptel-complete-auto-trigger-line-end-delay)
                     ('direct-char rc/gptel-complete-auto-trigger-direct-char-delay)
                     (_ rc/gptel-complete-auto-trigger-delay))
                   nil
                   #'rc/gptel-run-complete-auto-trigger
                   (current-buffer)
                   (point)
                   (buffer-chars-modified-tick)
                   token))
            (when (fboundp 'rc/gptel-complete-observe-record-trace)
              (rc/gptel-complete-observe-record-trace
               'timer
               (list :event 'auto-trigger-scheduled
                     :trigger-kind 'auto
                     :token token
                     :match-kind (plist-get diag :trigger-match-kind)
                     :delay (pcase (plist-get diag :trigger-match-kind)
                              ('line-end rc/gptel-complete-auto-trigger-line-end-delay)
                              ('direct-char rc/gptel-complete-auto-trigger-direct-char-delay)
                              (_ rc/gptel-complete-auto-trigger-delay)))))))
      (when (fboundp 'rc/gptel-complete-observe-record-trace)
        (rc/gptel-complete-observe-record-trace
         'suppress
         (list :event 'auto-denied
               :reason (plist-get diag :blocked-reason)
               :trigger-kind 'auto
               :match-kind (plist-get diag :trigger-match-kind)
               :org-src (and (fboundp 'rc/gptel-complete-environment-policy)
                             (plist-get (rc/gptel-complete-environment-policy 'auto)
                                        :org-src))
               :yield-target (and (fboundp 'rc/gptel-complete-environment-policy)
                                  (plist-get (rc/gptel-complete-environment-policy 'auto)
                                             :yield-target)))))
      (when (rc/gptel-complete-auto-trigger-diagnose-p)
        (when (rc/gptel-complete-should-echo-diagnose-message-p diag)
          (setq rc/gptel-complete-last-diagnose-message diag)
          (message "%s"
                   (rc/gptel-complete-auto-trigger-diagnostic-message diag)))))))

(defun rc/gptel-toggle-complete-auto-trigger ()
  "Cycle conservative semi-automatic inline completion trigger mode.
Modes are `off', `on' and `diagnose'."
  (interactive)
  (when (fboundp 'rc/gptel-autocomplete-setup)
    (rc/gptel-autocomplete-setup))
  (when (fboundp 'rc/gptel-prepare-inline-complete-buffer)
    (rc/gptel-prepare-inline-complete-buffer))
  (unless (bound-and-true-p gptel-autocomplete-mode)
    (gptel-autocomplete-mode 1))
  (when (fboundp 'rc/gptel-complete-install-buffer-hooks)
    (rc/gptel-complete-install-buffer-hooks))
  (rc/gptel-complete-set-auto-trigger-mode
   (rc/gptel-complete-cycle-auto-trigger-mode))
  (message "AI 半自动补全触发[%s]: %s"
           (buffer-name)
           (pcase rc/gptel-complete-auto-trigger-mode
             ('off "关闭")
             ('on "开启")
             ('diagnose "诊断")
             (_ "关闭"))))

(provide 'ai-complete-trigger-rc)
;;; ai-complete-trigger-rc.el ends here
