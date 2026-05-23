;;; ai-complete-profile-rc.el --- Prompt and behavior profiles -*- lexical-binding: t; -*-

;;; Code:

(require 'subr-x)

(defvar rc/gptel-complete-current-profile 'balanced
  "Current inline completion profile.")

(defvar rc/gptel-complete-profiles
  '((balanced
     :label "Balanced"
     :temperature 0.1
     :candidate-count 1
     :retry-once t
     :extra "Prefer compact, reliable completions.")
    (conservative
     :label "Conservative"
     :temperature 0.0
     :candidate-count 1
     :retry-once t
     :extra "Prefer very short, high-confidence completions. Avoid speculative changes.")
    (next-step
     :label "Next Step"
     :temperature 0.15
     :candidate-count 1
     :retry-once t
     :extra "Prefer a slightly more proactive continuation when the current code obviously leads to a next step.")
    (alternatives
     :label "Alternatives"
     :temperature 0.2
     :candidate-count 3
     :retry-once t
     :extra "Return multiple compact completion alternatives ordered by confidence."))
  "Inline completion behavior profiles.")

(defun rc/gptel-complete-profile-rule (&optional profile)
  "Return plist for PROFILE or current inline profile."
  (alist-get (or profile rc/gptel-complete-current-profile)
             rc/gptel-complete-profiles))

(defun rc/gptel-complete-profile-extra ()
  "Return profile-specific prompt extra."
  (plist-get (rc/gptel-complete-profile-rule) :extra))

(defun rc/gptel-complete-profile-candidate-count ()
  "Return candidate count requested by current profile."
  (or (plist-get (rc/gptel-complete-profile-rule) :candidate-count) 1))

(defun rc/gptel-complete-profile-temperature ()
  "Return temperature for current profile."
  (or (plist-get (rc/gptel-complete-profile-rule) :temperature) 0.1))

(defun rc/gptel-complete-profile-retry-once-p ()
  "Return non-nil when current profile enables one retry."
  (plist-get (rc/gptel-complete-profile-rule) :retry-once))

(defun rc/gptel-set-complete-profile (profile)
  "Set inline completion PROFILE interactively."
  (interactive
   (list
    (intern
     (completing-read
      "Complete profile: "
      (mapcar (lambda (entry) (symbol-name (car entry)))
              rc/gptel-complete-profiles)
      nil t nil nil
      (symbol-name rc/gptel-complete-current-profile)))))
  (setq rc/gptel-complete-current-profile profile)
  (message "AI 补全 profile: %s" profile))

(provide 'ai-complete-profile-rc)
;;; ai-complete-profile-rc.el ends here
