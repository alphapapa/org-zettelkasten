(require 'org-quickselect-effort)

(setq org-task-list-format
      (vector
       '("Tag" 8 t)
       '("P" 1 t)
       '("Project" 20 t)
       '("Title" 40 t)
       '("Effort" 6 t)
       '("Tags" 20 t)))

(defun org-task-list--sort-todo-keyword (kw)
  (cond
   ((string= kw "NEXT") 6)
   ((string= kw "TODO") 5)
   ((string= kw "WAITING") 4)
   ((string= kw "DONE") 3)
   ((string= kw "DELEGATED") 2)
   ((string= kw "CANCELLED") 1)
   (t 0)))

(defun org-task-list--sort-priority (prio)
  (cond
   ((eql prio ?A) 3)
   ((eql prio nil) 2)
   ((eql prio ?B) 2)
   ((eql prio ?C) 1)
   (t 0)))

(defvar org-task-list--sort-predicates
  (list
   (list (lambda (e) (org-task-list--sort-todo-keyword (oref e todo-keyword))) #'> #'<)
   (list (lambda (e) (org-task-list--sort-priority (oref e priority))) #'> #'<)
   (list (lambda (e) (org-cache-get-keyword (oref e parent) "TITLE")) #'string> #'string<)
   (list (lambda (e) (oref e title)) #'string> #'string<)))

;; Keyword
;; Prio
;; Title
(cl-defun org-task-list--sort-predicate (a b &optional (predicates org-task-list--sort-predicates))
  (message "sorting")
  (if (null predicates)
      nil
    (destructuring-bind (transformer pred1 pred2) (car predicates)
      (let ((va (funcall transformer a))
            (vb (funcall transformer b)))
        (cond
         ((funcall pred1 va vb) t)
         ((funcall pred2 va vb) nil)
         (t (org-task-list--sort-predicate a b (cdr predicates))))))))

(defun org-task-list--sort (headlines)
  (sort headlines #'org-task-list--sort-predicate))

(defun org-task-list-tabulate (headlines)
  (mapcar
   (lambda (headline)
     (list
      headline
      (vector
       (substring-no-properties (oref headline todo-keyword))
       (format "%c" (or (oref headline priority) ?B))
       (org-cache-get-keyword (oref headline parent) "TITLE")
       (oref headline title)
       (or (oref headline effort) "")
       (mapconcat #'substring-no-properties
                  (oref headline tags)
                  ":"))))
   headlines))

(defun org-task-list-buffer ()
  (get-buffer-create "Org Tasks"))

(defun org-task-list-show (headlines)
  (message "Headlines %d" (length headlines))
  (setq headlines (org-task-list--sort headlines))
  (message "Headlines 2 %d" (length headlines))
  (with-current-buffer (org-task-list-buffer)
    (org-task-list-mode)
    (setq tabulated-list-format org-task-list-format)
    (tabulated-list-init-header)
    (setq tabulated-list-entries (org-task-list-tabulate headlines))
    (setq tabulated-list-sort-key nil)
    (tabulated-list-print)
    (switch-to-buffer (current-buffer))))


(define-derived-mode org-task-list-mode tabulated-list-mode "Org Tasks"
  "Major mode for listing org tasks"
  (hl-line-mode))

(setq org-task-list-mode-map
      (let ((map (make-sparse-keymap)))
        (set-keymap-parent map tabulated-list-mode-map)
        (define-key map (kbd "RET") 'org-task-list-open)
        (define-key map (kbd "e") 'org-task-list-set-effort)
        (define-key map (kbd "t") 'org-task-list-set-todo)
        (define-key map (kbd "p") 'org-task-list-set-priority)
        map))

(defun org-task-list-open ()
  (interactive)
  (let* ((headline (tabulated-list-get-id))
         (parent (oref headline parent))
         (path (oref parent path)))
    (find-file path)
    (goto-char (oref headline begin))))

(defun org-task-list-set-effort ()
  (interactive)
  (let* ((headline (tabulated-list-get-id))
         (parent (oref headline parent))
         (path (oref parent path))
         (cur (oref headline effort))
         (allowed (org-property-get-allowed-values nil org-effort-property))
         (effort (org-quickselect-effort-prompt cur allowed)))
    (tabulated-list-set-col "Effort" effort)
    (with-current-buffer (find-file-noselect path)
      (goto-char (oref headline begin))
      (org-set-effort effort)
      (save-buffer))
    ;; FIXME, Hacky re-rendering of the updated list
    (let ((p (point)))
      (org-next-tasks)
      (goto-char p))))

(defun org-task-list-set-todo ()
  (interactive)
  (let* ((headline (tabulated-list-get-id))
         (parent (oref headline parent))
         (path (oref parent path)))
    (with-current-buffer (find-file-noselect path)
      (goto-char (oref headline begin))
      (org-todo)
      (save-buffer))
    ;; FIXME, Hacky re-rendering of the updated list
    (let ((p (point)))
      (org-next-tasks)
      (goto-char p))))

(defun org-task-list-set-priority ()
  (interactive)
  (let* ((headline (tabulated-list-get-id))
         (parent (oref headline parent))
         (path (oref parent path)))
    (with-current-buffer (find-file-noselect path)
      (goto-char (oref headline begin))
      (org-priority 'set)
      (save-buffer))
    ;; FIXME, Hacky re-rendering of the updated list
    (let ((p (point)))
      (org-next-tasks)
      (goto-char p))))

(defun org-next-tasks ()
  (interactive)
  (org-task-list-show (org-cache-headline-query
                       '(keyword "GTD_STATE" "active")
                       '(or (todo "NEXT")))))

(provide 'org-task-list)
