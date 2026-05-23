;;; lsp-rc.el --- Completion and LSP workflow  -*- lexical-binding: t; -*-

;;; Code:

(rc/require 'company 'lsp-ui 'lsp-mode)

(autoload 'global-company-mode "company" nil t)
(autoload 'lsp "lsp-mode" nil t)
(autoload 'lsp-ui-mode "lsp-ui" nil t)
(autoload 'lsp-ui-peek-find-definitions "lsp-ui-peek" nil t)
(autoload 'lsp-ui-peek-find-references "lsp-ui-peek" nil t)

(setq company-idle-delay 0.2
      company-minimum-prefix-length 1
      lsp-ui-doc-enable nil
      lsp-ui-doc-show-with-cursor nil
      lsp-ui-doc-show-with-mouse nil
      lsp-ui-peek-enable t
      lsp-ui-peek-show-directory t
      lsp-ui-sideline-enable nil
      lsp-idle-delay 0.5
      lsp-log-io nil
      lsp-enable-file-watchers nil)

(global-company-mode 1)

(with-eval-after-load 'company
  (message "✓ Company 已加载"))

(with-eval-after-load 'lsp-ui
  (add-hook 'lsp-ui-mode-hook
            (lambda ()
              (local-set-key (kbd "M-.") #'lsp-ui-peek-find-definitions)
              (local-set-key (kbd "M-?") #'lsp-ui-peek-find-references)))
  (message "✓ LSP UI 已配置"))

(dolist (hook '(c-mode-hook
                c++-mode-hook
                python-mode-hook
                python-ts-mode-hook
                java-mode-hook
                java-ts-mode-hook))
  (add-hook hook #'lsp))

(add-hook 'lsp-mode-hook #'lsp-ui-mode)

(with-eval-after-load 'lsp-mode
  (message "✓ LSP 已加载"))

(provide 'lsp-rc)
;;; lsp-rc.el ends here
