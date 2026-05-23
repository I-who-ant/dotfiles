;;; git-rc.el --- Git workflow integration  -*- lexical-binding: t; -*-

;;; Code:

(autoload 'magit-status "magit" nil t)
(autoload 'magit-log "magit" nil t)
(autoload 'magit-log-buffer-file "magit" nil t)
(autoload 'magit-blame "magit" nil t)
(autoload 'helm-ls-git-ls "helm-ls-git" nil t)
(autoload 'helm-do-grep-ag "helm-grep" nil t)

(defun rc/helm-git-grep ()
  "Search current Git repository with Helm."
  (interactive)
  (let ((git-root (vc-root-dir)))
    (if git-root
        (helm-do-grep-ag git-root)
      (message "不在 Git 仓库中"))))

(rc/require 'magit 'helm 'helm-ls-git)

(setq magit-auto-revert-mode nil
      magit-diff-refine-hunk t
      magit-commit-show-diff t)

(with-eval-after-load 'magit
  (message "✓ Magit 已加载"))

(with-eval-after-load 'helm-ls-git
  (message "✓ Helm Git 工具已加载"))

(provide 'git-rc)
;;; git-rc.el ends here
