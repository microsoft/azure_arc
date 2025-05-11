# Arc Jumpstart Code GitHub Repository Policies

This document outlines the automated policies for managing Pull Requests (PRs) and Issues in the Arc Jumpstart code repository. These policies are designed to ensure a high-quality, collaborative, and efficient workflow for contributors and maintainers.

---

## Pull Request Management

| Policy                        | What Happens                                                                                  | Why?                                                      | Contributor Experience                                   |
|-------------------------------|----------------------------------------------------------------------------------------------|-----------------------------------------------------------|---------------------------------------------------------|
| **Empty PR Detection**        | PRs with no file changes are automatically closed.                                           | Prevents clutter from empty PRs.                          | PR is closed with a comment explaining why.             |
| **Welcome Message**           | New PRs (except empty PRs and those targeting `main`) receive a welcome message with guidelines. | Sets expectations and provides guidance.                  | PR author receives a message with contribution info.    |

---

## Issue Management

| Policy                        | What Happens                                                                                  | Why?                                                      | Contributor Experience                                   |
|-------------------------------|----------------------------------------------------------------------------------------------|-----------------------------------------------------------|---------------------------------------------------------|
| **New Issue Triage**          | New issues are labeled for triage and categorized by keywords in the title.                  | Improves visibility and routing.                          | Issues with "bug" or "feature" get a tailored reply.    |
| **Issue Lifecycle Management**| Labels are updated when issues are closed, reopened, or marked as duplicates. Authors can comment `/unresolve` to reopen. | Keeps issue status and labels accurate.                   | Clear communication and ability to reopen issues.       |
| **Assignment Handling**       | Labels are managed automatically when issues are assigned or unassigned.                     | Ensures issues needing attention are visible.             | Maintainers and contributors see up-to-date labels.     |
| **Duplicate Issue Handling**  | Issues/PRs identified as duplicates (via comments) are closed and labeled.                   | Prevents duplicate tracking and consolidates discussion.  | PR/issue is closed with a comment and label.            |
| **Issue Milestone Check**     | Assigned or closed issues without a milestone are given the "Missing-Milestone" label. Maintainers are expected to add a milestone to any assigned or closed issue with this label. Once a milestone is set, the label is automatically removed. | Ensures all assigned and closed issues are tracked with milestones. | Maintainers are prompted to add a milestone to any assigned or closed issue with the "Missing-Milestone" label, and the label is cleared once a milestone is set. |
| **Stale Issue Management**    | Issues needing author feedback and inactive for 7 days are labeled "No-Recent-Activity". If still inactive after another 7 days, the issue is closed. Resolved issues are auto-closed after 7 days of inactivity. | Keeps the issue tracker clean and focused.                | Reminders and auto-closure with clear communication.    |

---

## Error Handling

- **On Failure/Success:**  
  Hooks are available for future notification or logging, but are not currently configured.

---

_These policies are designed to foster a welcoming, organized, and productive open-source community. Thank you for your collaboration!_
