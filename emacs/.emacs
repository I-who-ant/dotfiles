;;; .emacs --- Emacs 启动骨架

;;; Commentary:
;; 主入口只负责初始化和加载模块，不再承载具体业务配置。

;;; Code:

(setq custom-file "~/.emacs.custom.el")

(require 'package)
(setq package-archives '(("gnu"   . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

(when (file-exists-p custom-file)
  (load custom-file))

(add-to-list 'load-path "~/.emacs.rc/")
(add-to-list 'load-path "~/.emacs.local/")
(add-to-list 'load-path "/home/seeback/myCode/Emacs/plugin/gptel")
(add-to-list 'load-path "/home/seeback/myCode/Emacs/plugin/gptel-autocomplete")

(dolist (module '("~/.emacs.rc/rc.el"
                  "~/.emacs.rc/core-rc.el"
                  "~/.emacs.rc/ui-rc.el"
                  "~/.emacs.rc/editing-rc.el"
                  "~/.emacs.rc/search-rc.el"
                  "~/.emacs.rc/window-rc.el"
                  "~/.emacs.rc/dired-rc.el"
                  "~/.emacs.rc/compile-rc.el"
                  "~/.emacs.rc/langs-rc.el"
                  "~/.emacs.rc/treesit-rc.el"
                  "~/.emacs.rc/git-rc.el"
                  "~/.emacs.rc/lsp-rc.el"
                  "~/.emacs.rc/ai-rc.el"
                  "~/.emacs.rc/eaf-rc.el"
                  "~/.emacs.rc/org-mode-rc.el"
                  "~/.emacs.rc/keys-rc.el"))
  (when (file-exists-p module)
    (load module)))

(load "~/.emacs.shadow/shadow-rc.el" t)

;;; .emacs ends here
