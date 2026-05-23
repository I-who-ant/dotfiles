;;; core-rc.el --- Core runtime behavior  -*- lexical-binding: t; -*-

;;; Code:

(setq inhibit-startup-message t
      ring-bell-function 'ignore
      x-alt-keysym 'meta
      confirm-kill-emacs 'y-or-n-p
      server-client-instructions nil
      gc-cons-threshold (* 50 1000 1000))

(set-language-environment "UTF-8")
(set-default-coding-systems 'utf-8)
(prefer-coding-system 'utf-8)

(global-auto-revert-mode 1)
(setq global-auto-revert-non-file-buffers t
      auto-revert-verbose nil)

(add-hook 'emacs-lisp-mode-hook #'eldoc-mode)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 2 1000 1000))
            (message "✓ Emacs 启动完成! 加载时间: %s"
                     (emacs-init-time))))

(provide 'core-rc)
;;; core-rc.el ends here
