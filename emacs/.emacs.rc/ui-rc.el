;;; ui-rc.el --- UI and display settings  -*- lexical-binding: t; -*-

;;; Code:

(defun rc/get-default-font ()
  "根据操作系统返回默认字体。"
  (cond
   ((eq system-type 'windows-nt) "Consolas-13")
   ((eq system-type 'gnu/linux) "Fira Code-12")
   ((eq system-type 'darwin) "Monaco-14")))

(add-to-list 'default-frame-alist `(font . ,(rc/get-default-font)))
(add-to-list 'default-frame-alist '(fullscreen . maximized))

(tool-bar-mode 0)
(menu-bar-mode 0)
(scroll-bar-mode 0)

(column-number-mode 1)
(show-paren-mode 1)
(global-hl-line-mode 1)
(global-display-line-numbers-mode 1)
(fido-vertical-mode 1)

(provide 'ui-rc)
;;; ui-rc.el ends here
