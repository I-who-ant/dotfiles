;;; langs-rc.el --- Language modes and language-specific hooks  -*- lexical-binding: t; -*-

;;; Code:

(rc/require 'rust-mode
            'go-mode
            'haskell-mode
            'lua-mode
            'yaml-mode
            'toml-mode
            'markdown-mode)

(autoload 'jai-mode "jai-mode" nil t)
(autoload 'umka-mode "umka-mode" nil t)

(when (file-exists-p "~/.emacs.local/jai-mode.el")
  (add-to-list 'auto-mode-alist '("\\.jai\\'" . jai-mode)))

(when (file-exists-p "~/.emacs.local/umka-mode.el")
  (add-to-list 'auto-mode-alist '("\\.um\\'" . umka-mode)))

(with-eval-after-load 'jai-mode
  (message "✓ 已加载: jai-mode"))

(with-eval-after-load 'umka-mode
  (message "✓ 已加载: umka-mode"))

;; 缩进配置说明：
;;
;; 1. 全局默认值在 `editing-rc.el`：
;;    - `rc/default-indent-width`
;;    - `rc/default-tab-width`
;;    - `indent-tabs-mode`
;;    它们负责“默认步长 / Tab 显示宽度 / 默认是否插入真 Tab”。
;;
;; 2. 语言级覆盖统一放这里：
;;    - C/C++      -> `c-basic-offset`
;;    - Python     -> `python-indent-offset`
;;    - JS         -> `js-indent-level`
;;    - TypeScript -> `typescript-indent-level`
;;    - Shell      -> `sh-basic-offset` / `sh-indentation`
;;    - CSS        -> `css-indent-offset`
;;    - HTML/XML   -> `sgml-basic-offset`
;;
;; 3. 后面你要改单个语言时，照着下面加一个函数 + hook 就行。
;;    最常见模板：
;;
;;    (defun rc/set-foo-indentation ()
;;      (setq-local indent-tabs-mode nil)      ; nil=空格, t=真 Tab
;;      (setq-local tab-width 4)               ; 真 Tab 显示为几列
;;      (setq-local foo-indent-offset 4))      ; 该语言一层缩进多少列
;;
;;    (add-hook 'foo-mode-hook #'rc/set-foo-indentation)
;;
;; 4. C/C++ 这种 c-mode 家族要优先改 `c-basic-offset`；
;;    想让它真的插入 Tab，还要同时设 `indent-tabs-mode t`。
;;
(defun rc/set-common-prog-indentation ()
  "Apply the shared indentation baseline for most programming buffers."
  (setq-local tab-width rc/default-tab-width)
  (setq-local indent-tabs-mode nil))

(defun rc/set-python-indentation ()
  "Keep Python aligned with the shared 4-space baseline."
  (setq-local python-indent-offset rc/default-indent-width))

(defun rc/set-c-like-indentation ()
  "Use real tabs for C-family indentation with a 4-column display width."
  (setq-local tab-width rc/default-tab-width)
  (setq-local indent-tabs-mode t)
  (setq-local c-basic-offset rc/default-indent-width))

(defun rc/set-js-indentation ()
  "Keep JavaScript indentation explicit and easy to override later."
  (setq-local js-indent-level rc/default-indent-width))

(defun rc/set-typescript-indentation ()
  "Keep TypeScript indentation explicit and easy to override later."
  (when (boundp 'typescript-indent-level)
    (setq-local typescript-indent-level rc/default-indent-width)))

(defun rc/set-shell-indentation ()
  "Keep shell indentation explicit and easy to override later."
  (setq-local sh-basic-offset rc/default-indent-width)
  (setq-local sh-indentation rc/default-indent-width))

(defun rc/set-css-indentation ()
  "Keep CSS indentation explicit and easy to override later."
  (setq-local css-indent-offset rc/default-indent-width))

(defun rc/set-markup-indentation ()
  "Keep SGML/HTML/XML indentation explicit and easy to override later."
  (setq-local sgml-basic-offset rc/default-indent-width))

(dolist (hook '(prog-mode-hook
                conf-mode-hook))
  (add-hook hook #'rc/set-common-prog-indentation))

(add-hook 'python-mode-hook #'rc/set-python-indentation)
(add-hook 'c-mode-common-hook #'rc/set-c-like-indentation)
(add-hook 'js-mode-hook #'rc/set-js-indentation)
(add-hook 'js-ts-mode-hook #'rc/set-js-indentation)
(add-hook 'typescript-mode-hook #'rc/set-typescript-indentation)
(add-hook 'typescript-ts-mode-hook #'rc/set-typescript-indentation)
(add-hook 'sh-mode-hook #'rc/set-shell-indentation)
(add-hook 'css-mode-hook #'rc/set-css-indentation)
(add-hook 'sgml-mode-hook #'rc/set-markup-indentation)
(add-hook 'nxml-mode-hook #'rc/set-markup-indentation)

(add-hook 'emacs-lisp-mode-hook
          (lambda ()
            (local-set-key (kbd "C-c C-j") #'eval-print-last-sexp)))

(defun rc/typescript-mode-best-effort ()
  "Open TypeScript-like files with the best available major mode.
Prefer `typescript-ts-mode' when the grammar exists, then classic
`typescript-mode', and finally fall back to `js-mode' so `.ts' files
still count as `prog-mode' for editor features like inline completion."
  (interactive)
  (cond
   ((and (fboundp 'typescript-ts-mode)
         (fboundp 'treesit-language-available-p)
         (treesit-language-available-p 'typescript))
    (typescript-ts-mode))
   ((fboundp 'typescript-mode)
    (typescript-mode))
   ((fboundp 'js-mode)
    (js-mode))
   (t
    (fundamental-mode))))

(add-to-list 'auto-mode-alist '("\\.ts\\'" . rc/typescript-mode-best-effort))
(add-to-list 'auto-mode-alist '("\\.tsx\\'" . rc/typescript-mode-best-effort))

(provide 'langs-rc)
;;; langs-rc.el ends here
