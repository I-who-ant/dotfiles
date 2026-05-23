;;; compile-rc.el --- Compilation workflow  -*- lexical-binding: t; -*-

;;; Code:

(require 'ansi-color)

(setq-default compilation-scroll-output t)
(setq compile-command "")

(defun rc/colorize-compilation-buffer ()
  "Apply ANSI colors to compilation output."
  (read-only-mode 'toggle)
  (ansi-color-apply-on-region compilation-filter-start (point))
  (read-only-mode 'toggle))

(add-hook 'compilation-filter-hook #'rc/colorize-compilation-buffer)

(provide 'compile-rc)
;;; compile-rc.el ends here
