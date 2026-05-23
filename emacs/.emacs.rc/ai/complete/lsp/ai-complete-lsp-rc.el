;;; ai-complete-lsp-rc.el --- LSP/editor signal bridge for inline completion -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defvar rc/gptel-complete-lsp-bridge-enabled t
  "Whether editor/LSP signals should feed the inline completion runtime.")

(defvar rc/gptel-complete-suppress-company-when-ghost-visible t
  "Whether visible ghost text should suppress Company popup completion.")

(defvar rc/gptel-complete-manual-trigger-allows-company-yield t
  "Whether manual complete may proceed after yielding an active Company popup.")

(defvar rc/gptel-complete-capf-yields-to-ghost nil
  "Whether active completion-in-region UI may yield to ghost completion.
Default remains conservative: deny ghost while CAPF UI is active.")

(defun rc/gptel-complete-company-active-p ()
  "Return non-nil when Company currently has an active popup."
  (cond
   ((fboundp 'company--active-p)
    (company--active-p))
   ((boundp 'company-candidates)
    (and company-candidates t))
   (t nil)))

(defun rc/gptel-complete-yasnippet-active-p ()
  "Return non-nil when YAS snippet expansion is currently active."
  (or (and (boundp 'yas--active-field-overlay)
           (overlayp yas--active-field-overlay))
      (and (fboundp 'yas-active-snippets)
           (ignore-errors (yas-active-snippets))
           t)))

(defun rc/gptel-complete-capf-active-p ()
  "Return non-nil when completion-at-point UI is currently active."
  (or (bound-and-true-p completion-in-region-mode)
      (and (boundp 'completion-in-region--data)
           completion-in-region--data)))

(defun rc/gptel-complete-tramp-buffer-p ()
  "Return non-nil when current buffer is remote via TRAMP."
  (and default-directory
       (file-remote-p default-directory)))

(defun rc/gptel-complete-org-src-buffer-p ()
  "Return non-nil when current buffer is an Org src edit buffer."
  (or (bound-and-true-p org-src-mode)
      (bound-and-true-p org-src--from-org-mode)
      (and (boundp 'org-src--beg-marker)
           org-src--beg-marker)))

(defun rc/gptel-complete-environment-context ()
  "Return current editor coordination context as a plist."
  (list :company-active (rc/gptel-complete-company-active-p)
        :yas-active (rc/gptel-complete-yasnippet-active-p)
        :capf-active (rc/gptel-complete-capf-active-p)
        :minibuffer (minibufferp)
        :tramp (rc/gptel-complete-tramp-buffer-p)
        :read-only buffer-read-only
        :prog-mode (derived-mode-p 'prog-mode)
        :org-src (rc/gptel-complete-org-src-buffer-p)
        :lsp-mode (bound-and-true-p lsp-mode)
        :eglot-managed (bound-and-true-p eglot--managed-mode)))

(defun rc/gptel-complete-environment-policy (&optional trigger-kind)
  "Return coordination policy plist for TRIGGER-KIND.
TRIGGER-KIND should be `auto', `manual' or `external'."
  (let* ((kind (or trigger-kind 'auto))
         (ctx (rc/gptel-complete-environment-context))
         (company (plist-get ctx :company-active))
         (yas (plist-get ctx :yas-active))
         (capf (plist-get ctx :capf-active))
         (minibuffer (plist-get ctx :minibuffer))
         (tramp (plist-get ctx :tramp))
         (read-only (plist-get ctx :read-only))
         (prog-mode (plist-get ctx :prog-mode))
         (org-src (plist-get ctx :org-src))
         auto-allow manual-allow reason yield-target)
    (cond
     (minibuffer
      (setq auto-allow nil manual-allow nil reason 'minibuffer))
     (read-only
      (setq auto-allow nil manual-allow nil reason 'read-only))
     (tramp
      (setq auto-allow nil manual-allow nil reason 'tramp))
     ((not prog-mode)
      (setq auto-allow nil manual-allow nil reason 'not-prog-mode))
     (yas
      (setq auto-allow nil manual-allow nil reason 'yasnippet-active yield-target 'yasnippet))
     (company
      (setq auto-allow nil
            manual-allow rc/gptel-complete-manual-trigger-allows-company-yield
            reason 'company-active
            yield-target 'company))
     (capf
      (setq auto-allow nil
            manual-allow rc/gptel-complete-capf-yields-to-ghost
            reason 'capf-active
            yield-target 'capf))
     (t
      (setq auto-allow t manual-allow t)))
    (list :trigger-kind kind
          :auto-allow auto-allow
          :manual-allow manual-allow
          :suppress-reason (unless (or auto-allow manual-allow) reason)
          :blocked-reason reason
          :yield-target yield-target
          :org-src org-src
          :company-active company
          :yas-active yas
          :capf-active capf)))

(defun rc/gptel-complete-environment-blocked-reason (&optional trigger-kind)
  "Return blocked reason for TRIGGER-KIND in current editor context."
  (let* ((policy (rc/gptel-complete-environment-policy trigger-kind))
         (allowed (pcase (or trigger-kind 'auto)
                    ('manual (plist-get policy :manual-allow))
                    (_ (plist-get policy :auto-allow)))))
    (unless allowed
      (plist-get policy :blocked-reason))))

(defun rc/gptel-complete-environment-manual-allowed-p ()
  "Return non-nil when manual completion is allowed right now."
  (plist-get (rc/gptel-complete-environment-policy 'manual) :manual-allow))

(defun rc/gptel-complete-environment-auto-allowed-p ()
  "Return non-nil when auto/external completion is allowed right now."
  (plist-get (rc/gptel-complete-environment-policy 'auto) :auto-allow))

(defun rc/gptel-complete-environment-yield-if-needed (&optional trigger-kind)
  "Yield competing editor UI if allowed for TRIGGER-KIND."
  (let* ((policy (rc/gptel-complete-environment-policy trigger-kind))
         (yield-target (plist-get policy :yield-target)))
    (pcase yield-target
      ('company
       (when (and (plist-get policy :manual-allow)
                  (rc/gptel-complete-company-active-p)
                  (fboundp 'company-abort))
         (company-abort)
         (when (fboundp 'rc/gptel-complete-observe-record-trace)
           (rc/gptel-complete-observe-record-trace
            'coordination
            (list :event 'yield
                  :yield-target 'company
                  :trigger-kind (or trigger-kind 'manual)))))
       t)
      (_ nil))))

(defun rc/gptel-complete-company-should-yield-p ()
  "Return non-nil when Company should yield to inline ghost completion."
  (and rc/gptel-complete-suppress-company-when-ghost-visible
       (fboundp 'rc/gptel-inline-completion-visible-p)
       (rc/gptel-inline-completion-visible-p)))

(defun rc/gptel-complete-maybe-abort-company (&rest _args)
  "Abort Company popup when inline ghost completion should own the surface."
  (when (and (rc/gptel-complete-company-should-yield-p)
             (rc/gptel-complete-company-active-p)
             (fboundp 'company-abort))
    (company-abort)))

(defun rc/gptel-complete-company-lsp-backend-p (&optional backend)
  "Return non-nil when BACKEND looks like an LSP-driven completion backend."
  (let ((target (or backend (and (boundp 'company-backend) company-backend))))
    (cond
     ((null target) nil)
     ((listp target)
      (seq-some #'rc/gptel-complete-company-lsp-backend-p target))
     ((symbolp target)
      (let ((name (symbol-name target)))
        (or (string-match-p "lsp" name)
            (and (eq target 'company-capf)
                 (bound-and-true-p lsp-mode)))))
     (t nil))))

(defun rc/gptel-complete-company-started (backend)
  "Bridge Company BACKEND visibility into the inline runtime."
  (if (rc/gptel-complete-company-should-yield-p)
      (progn
        (when (fboundp 'rc/gptel-complete-observe-record-trace)
          (rc/gptel-complete-observe-record-trace
           'coordination
           (list :event 'yield
                 :yield-target 'company
                 :trigger-kind 'surface
                 :reason 'ghost-visible)))
        (rc/gptel-complete-maybe-abort-company))
    (when (and rc/gptel-complete-lsp-bridge-enabled
               (rc/gptel-complete-company-lsp-backend-p backend)
               (fboundp 'rc/gptel-complete-notify-lsp-suggestions))
      (rc/gptel-complete-notify-lsp-suggestions
       (list :backend backend
             :candidate-count (length (or (and (boundp 'company-candidates)
                                               company-candidates)
                                          nil))
             :prefix (and (boundp 'company-prefix) company-prefix))))))

(defun rc/gptel-complete-flymake-after-diagnostics (&rest _args)
  "Bridge updated diagnostics into the inline runtime."
  (when (and rc/gptel-complete-lsp-bridge-enabled
             (bound-and-true-p flymake-mode)
             (fboundp 'rc/gptel-complete-notify-flymake-diagnostics)
             (fboundp 'flymake-diagnostics))
    (rc/gptel-complete-notify-flymake-diagnostics
     (list :diagnostic-count (length (flymake-diagnostics))
           :source 'flymake))))

(defun rc/gptel-complete-lsp-signature-activated (&rest _args)
  "Bridge active LSP signature help into the inline runtime."
  (when (and rc/gptel-complete-lsp-bridge-enabled
             (bound-and-true-p lsp-mode)
             (bound-and-true-p lsp-signature-mode)
             (fboundp 'rc/gptel-complete-notify-signature-help))
    (rc/gptel-complete-notify-signature-help
     (list :source 'lsp-signature
           :signature-present t
           :signature
           (cond
            ((and (boundp 'lsp--signature-last)
                  lsp--signature-last
                  (fboundp 'lsp--signature->message))
             (ignore-errors (lsp--signature->message lsp--signature-last)))
            (t nil))))))

(defun rc/gptel-install-complete-lsp-bridges ()
  "Install Company/LSP/Flymake bridges for the inline runtime."
  (with-eval-after-load 'company
    (add-hook 'company-completion-started-hook
              #'rc/gptel-complete-company-started)
    (add-hook 'post-command-hook
              #'rc/gptel-complete-maybe-abort-company))
  (with-eval-after-load 'lsp-mode
    (when (boundp 'lsp-after-diagnostics-hook)
      (add-hook 'lsp-after-diagnostics-hook
                #'rc/gptel-complete-flymake-after-diagnostics))
    (when (fboundp 'lsp-signature-activate)
      (advice-add 'lsp-signature-activate :after
                  #'rc/gptel-complete-lsp-signature-activated))
    (when (boundp 'lsp-signature-mode-hook)
      (add-hook 'lsp-signature-mode-hook
                #'rc/gptel-complete-lsp-signature-activated)))
  (with-eval-after-load 'flymake
    (when (boundp 'flymake-after-diagnostics-hook)
      (add-hook 'flymake-after-diagnostics-hook
                #'rc/gptel-complete-flymake-after-diagnostics))))

(rc/gptel-install-complete-lsp-bridges)

(provide 'ai-complete-lsp-rc)
;;; ai-complete-lsp-rc.el ends here
