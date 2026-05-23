;;; editing-rc.el --- Editing behavior and helpers  -*- lexical-binding: t; -*-

;;; Code:

(autoload 'move-text-up "move-text" nil t)
(autoload 'move-text-down "move-text" nil t)
(autoload 'mc/edit-lines "mc-edit-lines" nil t)
(autoload 'mc/mark-next-like-this "mc-mark-more" nil t)
(autoload 'mc/mark-previous-like-this "mc-mark-more" nil t)

(setq scroll-conservatively 101
      make-backup-files nil
      auto-save-default nil
      default-input-method "russian-computer"
      visible-bell (equal system-type 'windows-nt))

(defconst rc/default-indent-width 4
  "Default indentation width shared by text/programming buffers.")

(defconst rc/default-tab-width 4
  "Default visual width for literal tab characters.")

(setq-default indent-tabs-mode nil
              tab-width rc/default-tab-width
              standard-indent rc/default-indent-width
              c-default-style '((java-mode . "java")
                                (awk-mode . "awk")
                                (other . "bsd")))

(electric-pair-mode 1)
(delete-selection-mode 1)

(defun rc/buffer-file-name ()
  "Return buffer file name or current Dired directory."
  (if (equal major-mode 'dired-mode)
      default-directory
    (buffer-file-name)))

(defun rc/parent-directory (path)
  "Return parent directory of PATH."
  (file-name-directory (directory-file-name path)))

(defun rc/root-anchor (path anchor)
  "Find nearest parent of PATH containing ANCHOR."
  (cond
   ((string= anchor "") nil)
   ((file-exists-p (concat (file-name-as-directory path) anchor)) path)
   ((string-equal path "/") nil)
   (t (rc/root-anchor (rc/parent-directory path) anchor))))

(defun rc/clipboard-org-mode-file-link (anchor)
  "Copy an Org file link relative to ANCHOR."
  (interactive "sRoot anchor: ")
  (let* ((root-dir (rc/root-anchor default-directory anchor))
         (org-mode-file-link
          (format "file:%s::%d"
                  (if root-dir
                      (file-relative-name (rc/buffer-file-name) root-dir)
                    (rc/buffer-file-name))
                  (line-number-at-pos))))
    (kill-new org-mode-file-link)
    (message org-mode-file-link)))

(defun rc/put-file-name-on-clipboard ()
  "Put the current file name on the clipboard."
  (interactive)
  (let ((filename (rc/buffer-file-name)))
    (when filename
      (kill-new filename)
      (message filename))))

(defun rc/put-buffer-name-on-clipboard ()
  "Put the current buffer name on the clipboard."
  (interactive)
  (kill-new (buffer-name))
  (message (buffer-name)))

(defun rc/kill-autoloads-buffers ()
  "Kill lingering autoloads buffers."
  (interactive)
  (dolist (buffer (buffer-list))
    (let ((name (buffer-name buffer)))
      (when (string-match-p "-autoloads.el" name)
        (kill-buffer buffer)
        (message "Killed autoloads buffer %s" name)))))

(defun bf-pretty-print-xml-region (begin end)
  "Pretty format XML markup in region from BEGIN to END."
  (interactive "r")
  (save-excursion
    (nxml-mode)
    (goto-char begin)
    (while (search-forward-regexp "\>[ \t]*\<" nil t)
      (backward-char)
      (insert "\n"))
    (indent-region begin end))
  (message "Ah, much better!"))

(defun rc/unfill-paragraph ()
  "Replace newline chars in current paragraph by single spaces."
  (interactive)
  (let ((fill-column 90002000))
    (fill-paragraph nil)))

(defun rc/load-path-here ()
  "Add current directory to `load-path'."
  (interactive)
  (add-to-list 'load-path default-directory))

(defun rc/duplicate-line ()
  "Duplicate current line."
  (interactive)
  (let ((column (- (point) (point-at-bol)))
        (line (let ((s (thing-at-point 'line t)))
                (if s (string-remove-suffix "\n" s) ""))))
    (move-end-of-line 1)
    (newline)
    (insert line)
    (move-beginning-of-line 1)
    (forward-char column)))

(defun rc/insert-timestamp ()
  "Insert a compact timestamp."
  (interactive)
  (insert (format-time-string "(%Y%m%d-%H%M%S)")))

(defun rc/open-config ()
  "Open the main Emacs config file."
  (interactive)
  (find-file user-init-file))

(defun rc/open-custom-file ()
  "Open the Customize output file."
  (interactive)
  (find-file custom-file))

(defun ldd-at-point ()
  "Run ldd on the file at point."
  (interactive)
  (let ((file (thing-at-point 'filename t)))
    (if (and file (file-exists-p file))
        (shell-command (concat "ldd " file))
      (message "No file at point"))))

(defun rc/set-up-whitespace-handling ()
  "Enable whitespace visualization and trim trailing spaces on save."
  (interactive)
  (whitespace-mode 1)
  (add-to-list 'write-file-functions #'delete-trailing-whitespace))

(dolist (hook '(c-mode-hook
                c++-mode-hook
                python-mode-hook
                emacs-lisp-mode-hook
                rust-mode-hook
                go-mode-hook
                java-mode-hook
                lua-mode-hook
                haskell-mode-hook
                markdown-mode-hook))
  (add-hook hook #'rc/set-up-whitespace-handling))

(rc/require 'multiple-cursors 'move-text)

(with-eval-after-load 'move-text
  (message "✓ Move-text 已加载"))

(with-eval-after-load 'multiple-cursors
  (message "✓ Multiple Cursors 已加载"))

(provide 'editing-rc)
;;; editing-rc.el ends here
