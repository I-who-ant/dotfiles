;;; dired-rc.el --- Dired behavior  -*- lexical-binding: t; -*-

;;; Code:

(require 'dired-x)

(setq dired-omit-files
      (concat dired-omit-files "\\|^\\..+$")
      dired-listing-switches "-alh")

(setq-default dired-dwim-target t)

(add-hook 'dired-mode-hook
          (lambda ()
            (auto-revert-mode 1)
            (setq auto-revert-interval 1)
            (local-set-key (kbd "r") #'revert-buffer)
            ;; Dired 默认把 C-M-n / C-M-p 用于子目录导航，会遮住全局 windmove。
            ;; 这里统一成窗口移动，保持和其它 buffer 的按键语义一致。
            (local-set-key (kbd "C-M-f") #'windmove-right)
            (local-set-key (kbd "C-M-b") #'windmove-left)
            (local-set-key (kbd "C-M-n") #'windmove-down)
            (local-set-key (kbd "C-M-p") #'windmove-up)))

(provide 'dired-rc)
;;; dired-rc.el ends here
