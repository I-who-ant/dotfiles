;;; eaf-rc.el --- EAF integration  -*- lexical-binding: t; -*-

;;; Code:

(defconst rc/eaf-dir "/home/seeback/myCode/Emacs/plugin/emacs-application-framework"
  "Local checkout directory for EAF.")

(when (file-directory-p rc/eaf-dir)
  (add-to-list 'load-path rc/eaf-dir)
  ;; EAF app entry files live under app/<name>/.
  ;; Emacs does not search subdirectories automatically, so every app you want
  ;; to load from Lisp must have its directory added here explicitly.
  (dolist (app-dir '("app/browser"
                     "app/pdf-viewer"
                     "app/markdown-previewer"))
    (add-to-list 'load-path (expand-file-name app-dir rc/eaf-dir)))

  ;; Keep startup light: only autoload EAF core entry commands here.
  ;; App-specific files often reference variables defined in eaf.el, so loading
  ;; app files before EAF core may trigger void-variable errors.
  (autoload 'eaf-open "eaf" nil t)
  (autoload 'eaf-stop-process "eaf" nil t)

  ;; Opt in manually later if you want all browse-url calls to stay inside EAF.
  ;; (setq browse-url-browser-function #'eaf-open-browser)

  (defun rc/eaf--require-app (feature)
    "Load EAF core first, then FEATURE."
    (require 'eaf)
    (require feature nil t))

  (defun rc/eaf-open-browser ()
    "Load EAF browser on demand and open it interactively."
    (interactive)
    (when (rc/eaf--require-app 'eaf-browser)
      (call-interactively #'eaf-open-browser)))

  (defun rc/eaf-open-pdf-viewer ()
    "Load EAF pdf viewer on demand and open current file."
    (interactive)
    (when (rc/eaf--require-app 'eaf-pdf-viewer)
      (if buffer-file-name
          (eaf-open buffer-file-name "pdf-viewer")
        (user-error "[EAF] Current buffer is not visiting a file"))))

  (defun rc/eaf-open-markdown-previewer ()
    "Load EAF markdown previewer on demand and preview current file."
    (interactive)
    (when (rc/eaf--require-app 'eaf-markdown-previewer)
      (if buffer-file-name
          (eaf-open buffer-file-name "markdown-previewer")
        (user-error "[EAF] Current buffer is not visiting a file"))))

  (defun rc/eaf-describe-bindings ()
    "Show EAF key help for the current EAF buffer."
    (interactive)
    (require 'eaf)
    (if (derived-mode-p 'eaf-mode)
        (call-interactively #'eaf-describe-bindings)
      (user-error "[EAF] Current buffer is not an EAF buffer; open one first")))

  (defun rc/eaf-stop-process ()
    "Stop the shared EAF backend process."
    (interactive)
    (require 'eaf)
    (call-interactively #'eaf-stop-process))

  (defvar rc/eaf-prefix-map
    (let ((map (make-sparse-keymap)))
      (define-key map (kbd "b") #'rc/eaf-open-browser)
      (define-key map (kbd "m") #'rc/eaf-open-markdown-previewer)
      (define-key map (kbd "p") #'rc/eaf-open-pdf-viewer)
      (define-key map (kbd "h") #'rc/eaf-describe-bindings)
      (define-key map (kbd "q") #'rc/eaf-stop-process)
      map)
    "Prefix keymap for EAF entry points.")

  (define-key global-map (kbd "C-c e") rc/eaf-prefix-map)

  ;; How to install a new EAF app:
  ;;
  ;; 1. Install or update the app from the EAF repo root, for example:
  ;;      ./install-eaf.py -i image-viewer
  ;;      ./install-eaf.py -i rss-reader
  ;;      ./install-eaf.py -i markdown-previewer
  ;;
  ;; 2. Add the app directory below with:
  ;;      (add-to-list 'load-path (expand-file-name "app/<name>" rc/eaf-dir))
  ;;
  ;; 3. Define a small wrapper that loads EAF core first, then the app feature.
  ;;
  ;; 4. Bind a key only if you will use the app often.
  ;;    This config keeps all EAF entry points under `C-c e':
  ;;      C-c e b  browser
  ;;      C-c e m  markdown previewer for current file
  ;;      C-c e p  pdf viewer for current file
  ;;      C-c e h  show help for current EAF buffer
  ;;      C-c e q  stop the shared EAF backend process
  ;;
  ;; Template for future EAF apps:
  ;;
  ;; Example for image-viewer:
  ;; (add-to-list 'load-path (expand-file-name "app/image-viewer" rc/eaf-dir))
  ;; (defun rc/eaf-open-image-viewer ()
  ;;   (interactive)
  ;;   (when (rc/eaf--require-app 'eaf-image-viewer)
  ;;     (if buffer-file-name
  ;;         (eaf-open buffer-file-name "image-viewer")
  ;;       (user-error "[EAF] Current buffer is not visiting a file"))))
  ;; (define-key rc/eaf-prefix-map (kbd "i") #'rc/eaf-open-image-viewer)
  )

(provide 'eaf-rc)
;;; eaf-rc.el ends here
