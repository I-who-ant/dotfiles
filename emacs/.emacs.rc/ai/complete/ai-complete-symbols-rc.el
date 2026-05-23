;;; ai-complete-symbols-rc.el --- Structured same-file symbol context -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'imenu)
(require 'subr-x)

(defvar rc/gptel-complete-symbol-context-limit 3
  "Maximum number of related same-file symbol snippets to include.")

(defun rc/gptel-complete--flatten-imenu (items)
  "Flatten imenu ITEMS into a simple list of (NAME . POS)."
  (cl-labels
      ((walk (xs)
         (cl-mapcan
          (lambda (item)
            (cond
             ((imenu--subalist-p item)
              (walk (cdr item)))
             ((consp item)
              (list item))
             (t nil)))
          xs)))
    (walk items)))

(defun rc/gptel-complete-current-symbol ()
  "Return symbol at point as string, else nil."
  (thing-at-point 'symbol t))

(defun rc/gptel-complete-imenu-symbol-hints ()
  "Return same-file symbol hints derived from imenu."
  (let ((symbol (rc/gptel-complete-current-symbol)))
    (when (and symbol
               (not (string-empty-p symbol)))
      (save-excursion
        (let* ((index (ignore-errors (imenu--make-index-alist t)))
               (flat (and index (rc/gptel-complete--flatten-imenu index)))
               (matches nil))
          (dolist (item flat)
            (let ((name (car item))
                  (pos (cdr item)))
              (when (and (stringp name)
                         (number-or-marker-p pos)
                         (string-match-p (regexp-quote symbol) name))
                (goto-char pos)
                (let ((line-text (string-trim
                                  (buffer-substring-no-properties
                                   (line-beginning-position)
                                   (line-end-position)))))
                  (unless (string-empty-p line-text)
                    (push (format "imenu:%s => %s" name line-text) matches))))))
          (when matches
            (string-join
             (seq-take (nreverse matches) rc/gptel-complete-symbol-context-limit)
             "\n")))))))

(defun rc/gptel-complete-same-file-context ()
  "Return structured same-file context string for inline completion."
  (let ((imenu-hints (rc/gptel-complete-imenu-symbol-hints)))
    (when imenu-hints
      (concat "Structured same-file symbol hints:\n" imenu-hints))))

(provide 'ai-complete-symbols-rc)
;;; ai-complete-symbols-rc.el ends here
