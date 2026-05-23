;;; keys-rc.el --- Global keybindings  -*- lexical-binding: t; -*-

;;; Code:

(global-set-key (kbd "C-x C-g") #'find-file-at-point)
(global-set-key (kbd "C-c i m") #'imenu)
(global-set-key (kbd "C-c M-q") #'rc/unfill-paragraph)
(global-set-key (kbd "C-,") #'rc/duplicate-line)
(global-set-key (kbd "C-x p d") #'rc/insert-timestamp)
(global-set-key (kbd "C-x p s") #'rc/rgrep-selected)
(global-set-key (kbd "C-c l") #'ldd-at-point)

(global-set-key (kbd "C-c f e") #'rc/open-config)
(global-set-key (kbd "C-c C-e") #'rc/open-custom-file)

(global-set-key (kbd "<XF86AudioPlay>") #'rc/ignore-media-key)
(global-set-key (kbd "s-<XF86AudioPlay>") #'rc/ignore-media-key)

(global-set-key (kbd "C-s") #'rc/isearch-forward-use-region)
(global-set-key (kbd "C-r") #'rc/isearch-backward-use-region)

(global-set-key (kbd "C-M-f") #'windmove-right)
(global-set-key (kbd "C-M-b") #'windmove-left)
(global-set-key (kbd "C-M-n") #'windmove-down)
(global-set-key (kbd "C-M-p") #'windmove-up)
(global-set-key (kbd "C-=") #'rc/window-resize-grow)
(global-set-key (kbd "C--") #'rc/window-resize-shrink)

(global-set-key (kbd "C-c c") #'compile)
(global-set-key (kbd "C-c r") #'recompile)
(global-set-key (kbd "C-c s") #'shell-command)
(global-set-key (kbd "M-!") #'shell)

(global-set-key (kbd "C-c a s") #'rc/gptel-send-command)
(global-set-key (kbd "C-c a m") #'rc/gptel-menu-command)
(global-set-key (kbd "C-c a r") #'rc/gptel-rewrite-command)
(global-set-key (kbd "C-c a c") #'rc/gptel-complete-code)
(global-set-key (kbd "C-c a q") #'rc/gptel-ask-question)
(global-set-key (kbd "C-c a l") #'rc/gptel-session-list)
(global-set-key (kbd "C-c a t") #'rc/gptel-toggle-complete-auto-trigger)
(global-set-key (kbd "C-c a i") #'rc/gptel-describe-action-state)
(global-set-key (kbd "C-c a o") #'rc/gptel-action-panel)
(global-set-key (kbd "C-c a p") #'rc/gptel-set-complete-profile)
(global-set-key (kbd "C-c a j") #'rc/gptel-go-to-next-location)

(global-set-key (kbd "C-c m s") #'magit-status)
(global-set-key (kbd "C-c m l") #'magit-log)
(global-set-key (kbd "C-c m f") #'magit-log-buffer-file)
(global-set-key (kbd "C-c m b") #'magit-blame)

(global-set-key (kbd "C-c h g l") #'helm-ls-git-ls)
(global-set-key (kbd "C-c h g g") #'rc/helm-git-grep)

(global-set-key (kbd "C-S-c C-S-c") #'mc/edit-lines)
(global-set-key (kbd "C->") #'mc/mark-next-like-this)
(global-set-key (kbd "C-<") #'mc/mark-previous-like-this)
(global-set-key (kbd "M-p") #'move-text-up)
(global-set-key (kbd "M-n") #'move-text-down)

(with-eval-after-load 'lsp-mode
  (define-key lsp-mode-map (kbd "C-c l d") #'lsp-find-definition)
  (define-key lsp-mode-map (kbd "C-c l r") #'lsp-find-references)
  (define-key lsp-mode-map (kbd "C-c l n") #'lsp-rename))

(provide 'keys-rc)
;;; keys-rc.el ends here
